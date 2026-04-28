import asyncio
import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

_DOWNLOAD_TIMEOUT = httpx.Timeout(10.0)
_PROXY_TIMEOUT = httpx.Timeout(90.0, connect=10.0)


class CodexProxyError(RuntimeError):
    """Proxy returned a non-2xx response."""


class CodexProxyTimeout(RuntimeError):
    """Proxy did not respond within the timeout."""


class ReferenceImageError(RuntimeError):
    """Failed to fetch a reference image (S3/CDN)."""


async def _download(url: str, client: httpx.AsyncClient) -> bytes:
    response = await client.get(url, timeout=_DOWNLOAD_TIMEOUT)
    response.raise_for_status()
    return response.content


async def generate_outfit_image(
    reference_urls: list[str],
    prompt: str,
    size: str,
    quality: str,
    n: int,
) -> list[str]:
    """Send reference images + prompt to the proxy's /images/edits endpoint.

    Returns a list of ``data:image/png;base64,...`` strings.
    """
    async with httpx.AsyncClient() as client:
        image_bytes = await asyncio.gather(
            *(_download(url, client) for url in reference_urls)
        )

        files = [("image[]", (f"ref-{i}.png", b, "image/png")) for i, b in enumerate(image_bytes)]
        data = {
            "model": "gpt-image-2",
            "prompt": prompt,
            "size": size,
            "quality": quality,
            "n": str(n),
        }

        response = await client.post(
            f"{settings.CODEX_PROXY_URL}/images/edits",
            headers={"Authorization": f"Bearer {settings.CODEX_PROXY_API_KEY}"},
            files=files,
            data=data,
            timeout=_PROXY_TIMEOUT,
        )
        response.raise_for_status()
        body = response.json()

    return [f"data:image/png;base64,{item['b64_json']}" for item in body.get("data", [])]
