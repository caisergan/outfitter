import asyncio
import io
import logging

import httpx
from PIL import Image, UnidentifiedImageError

from app.config import settings

logger = logging.getLogger(__name__)

_DOWNLOAD_TIMEOUT = httpx.Timeout(10.0)
_PROXY_TIMEOUT = httpx.Timeout(300.0, connect=10.0)


class CodexProxyError(RuntimeError):
    """Proxy returned a non-2xx response."""


class CodexProxyTimeout(RuntimeError):
    """Proxy did not respond within the timeout."""


class ReferenceImageError(RuntimeError):
    """Failed to fetch a reference image (S3/CDN)."""


_SUPPORTED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/gif", "image/webp"}
_EXT_BY_TYPE = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/gif": "gif",
    "image/webp": "webp",
}


def _sniff_content_type(image_bytes: bytes) -> str | None:
    """Detect content type from magic bytes. Returns None for formats we don't recognise."""
    if image_bytes.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if image_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if image_bytes.startswith(b"GIF87a") or image_bytes.startswith(b"GIF89a"):
        return "image/gif"
    if image_bytes[:4] == b"RIFF" and image_bytes[8:12] == b"WEBP":
        return "image/webp"
    return None


def _transcode_to_png(image_bytes: bytes, source_url: str) -> bytes:
    """Decode any Pillow-supported image and re-encode as PNG.

    Used when S3 returns a format the upstream image API rejects (e.g. AVIF
    served with a stale image/jpeg content-type).
    """
    try:
        with Image.open(io.BytesIO(image_bytes)) as img:
            img.load()
            if img.mode not in ("RGB", "RGBA"):
                img = img.convert("RGBA" if "A" in img.mode else "RGB")
            out = io.BytesIO()
            img.save(out, format="PNG")
            return out.getvalue()
    except (UnidentifiedImageError, OSError) as exc:
        raise ReferenceImageError(
            f"Could not decode image at {source_url}: {exc}"
        ) from exc


async def _download(url: str, client: httpx.AsyncClient) -> tuple[bytes, str]:
    """Fetch URL and return (bytes, content_type) in a format the image API accepts.

    S3 sometimes returns AVIF mislabeled as image/jpeg, so trust the magic-byte
    sniff over the declared content-type. If the actual format isn't supported
    upstream, transcode to PNG via Pillow.
    """
    response = await client.get(url, timeout=_DOWNLOAD_TIMEOUT)
    response.raise_for_status()
    body = response.content

    sniffed = _sniff_content_type(body)
    if sniffed:
        return body, sniffed

    # Either the server didn't tell us, magic bytes are unrecognised, or the
    # bytes are a non-jpeg/png/gif/webp container (AVIF, HEIC, BMP, TIFF, ...).
    # Try Pillow — if it decodes, re-encode as PNG so upstream accepts it.
    return _transcode_to_png(body, url), "image/png"


async def generate_outfit_image(
    reference_urls: list[str],
    prompt: str,
    size: str,
    quality: str,
    n: int,
) -> list[str]:
    async with httpx.AsyncClient() as client:
        try:
            downloads = await asyncio.gather(
                *(_download(url, client) for url in reference_urls)
            )
        except httpx.HTTPError as exc:
            logger.exception("Reference image download failed")
            raise ReferenceImageError(str(exc)) from exc

        files = [
            ("image", (f"ref-{i}.{_EXT_BY_TYPE[ct]}", b, ct))
            for i, (b, ct) in enumerate(downloads)
        ]
        data = {
            "model": "gpt-image-2",
            "prompt": prompt,
            "size": size,
            "quality": quality,
            "n": str(n),
        }

        try:
            response = await client.post(
                f"{settings.CODEX_PROXY_URL}/images/edits",
                headers={"Authorization": f"Bearer {settings.CODEX_PROXY_API_KEY}"},
                files=files,
                data=data,
                timeout=_PROXY_TIMEOUT,
            )
            response.raise_for_status()
        except (httpx.TimeoutException, httpx.ReadTimeout) as exc:
            raise CodexProxyTimeout(str(exc)) from exc
        except httpx.HTTPStatusError as exc:
            detail = exc.response.text[:500] if exc.response is not None else str(exc)
            raise CodexProxyError(f"{exc.response.status_code}: {detail}") from exc
        except httpx.HTTPError as exc:
            raise CodexProxyError(str(exc)) from exc

        body = response.json()

    return [f"data:image/png;base64,{item['b64_json']}" for item in body.get("data", [])]
