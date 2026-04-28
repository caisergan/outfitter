import base64

import httpx
import pytest

from app.services import codex_image_service


@pytest.mark.asyncio
async def test_generate_outfit_image_happy_path(httpx_mock):
    # Mock the two reference image GETs and the proxy POST.
    httpx_mock.add_response(
        url="https://cdn.example.com/a.jpg",
        method="GET",
        content=b"\x89PNG\r\n\x1a\nfake-a",
    )
    httpx_mock.add_response(
        url="https://cdn.example.com/b.jpg",
        method="GET",
        content=b"\x89PNG\r\n\x1a\nfake-b",
    )
    payload_b64 = base64.b64encode(b"generated-image-bytes").decode()
    httpx_mock.add_response(
        url=f"{codex_image_service.settings.CODEX_PROXY_URL}/images/edits",
        method="POST",
        json={"data": [{"b64_json": payload_b64}]},
    )

    images = await codex_image_service.generate_outfit_image(
        reference_urls=["https://cdn.example.com/a.jpg", "https://cdn.example.com/b.jpg"],
        prompt="render these on a runway model",
        size="1024x1536",
        quality="high",
        n=1,
    )

    assert images == [f"data:image/png;base64,{payload_b64}"]

    # Confirm the proxy request shape: model, multiple image parts, prompt, size, quality, n.
    proxy_req = next(
        r for r in httpx_mock.get_requests()
        if r.url == httpx.URL(f"{codex_image_service.settings.CODEX_PROXY_URL}/images/edits")
    )
    body = proxy_req.content.decode("latin-1")
    assert proxy_req.headers["authorization"].startswith("Bearer ")
    assert 'name="model"' in body and "gpt-image-2" in body
    assert body.count('name="image"') == 2
    assert 'name="prompt"' in body and "render these on a runway model" in body
    assert 'name="size"' in body and "1024x1536" in body
    assert 'name="quality"' in body and "high" in body
    assert 'name="n"' in body


@pytest.mark.asyncio
async def test_generate_outfit_image_reference_download_fails(httpx_mock):
    httpx_mock.add_response(
        url="https://cdn.example.com/missing.jpg",
        method="GET",
        status_code=404,
    )

    with pytest.raises(codex_image_service.ReferenceImageError):
        await codex_image_service.generate_outfit_image(
            reference_urls=["https://cdn.example.com/missing.jpg"],
            prompt="x",
            size="1024x1024",
            quality="high",
            n=1,
        )


@pytest.mark.asyncio
async def test_generate_outfit_image_proxy_returns_500(httpx_mock):
    httpx_mock.add_response(
        url="https://cdn.example.com/a.jpg",
        method="GET",
        content=b"\xff\xd8\xff\xe0fake-jpeg",
        headers={"content-type": "image/jpeg"},
    )
    httpx_mock.add_response(
        url=f"{codex_image_service.settings.CODEX_PROXY_URL}/images/edits",
        method="POST",
        status_code=500,
        json={"error": {"message": "boom"}},
    )

    with pytest.raises(codex_image_service.CodexProxyError):
        await codex_image_service.generate_outfit_image(
            reference_urls=["https://cdn.example.com/a.jpg"],
            prompt="x",
            size="1024x1024",
            quality="high",
            n=1,
        )


@pytest.mark.asyncio
async def test_generate_outfit_image_proxy_timeout(httpx_mock):
    httpx_mock.add_response(
        url="https://cdn.example.com/a.jpg",
        method="GET",
        content=b"\xff\xd8\xff\xe0fake-jpeg",
        headers={"content-type": "image/jpeg"},
    )
    httpx_mock.add_exception(
        httpx.ReadTimeout("timed out"),
        url=f"{codex_image_service.settings.CODEX_PROXY_URL}/images/edits",
        method="POST",
    )

    with pytest.raises(codex_image_service.CodexProxyTimeout):
        await codex_image_service.generate_outfit_image(
            reference_urls=["https://cdn.example.com/a.jpg"],
            prompt="x",
            size="1024x1024",
            quality="high",
            n=1,
        )


@pytest.mark.asyncio
async def test_generate_outfit_image_jpeg_content_type_propagates(httpx_mock):
    """Catalog images are usually JPEGs; the multipart entry must declare image/jpeg."""
    httpx_mock.add_response(
        url="https://cdn.example.com/photo.jpg",
        method="GET",
        content=b"\xff\xd8\xff\xe0fake-jpeg-bytes",
        headers={"content-type": "image/jpeg"},
    )
    payload_b64 = base64.b64encode(b"generated").decode()
    httpx_mock.add_response(
        url=f"{codex_image_service.settings.CODEX_PROXY_URL}/images/edits",
        method="POST",
        json={"data": [{"b64_json": payload_b64}]},
    )

    await codex_image_service.generate_outfit_image(
        reference_urls=["https://cdn.example.com/photo.jpg"],
        prompt="x",
        size="1024x1024",
        quality="high",
        n=1,
    )

    proxy_url = httpx.URL(f"{codex_image_service.settings.CODEX_PROXY_URL}/images/edits")
    proxy_req = next(r for r in httpx_mock.get_requests() if r.url == proxy_url)
    body = proxy_req.content.decode("latin-1")
    assert "Content-Type: image/jpeg" in body
    assert 'filename="ref-0.jpg"' in body


@pytest.mark.asyncio
async def test_generate_outfit_image_undecodable_bytes(httpx_mock):
    """Bytes that aren't a known image and Pillow can't decode → reject."""
    httpx_mock.add_response(
        url="https://cdn.example.com/weird.bin",
        method="GET",
        content=b"not-an-image-at-all",
        headers={"content-type": "application/octet-stream"},
    )

    with pytest.raises(codex_image_service.ReferenceImageError):
        await codex_image_service.generate_outfit_image(
            reference_urls=["https://cdn.example.com/weird.bin"],
            prompt="x",
            size="1024x1024",
            quality="high",
            n=1,
        )


@pytest.mark.asyncio
async def test_generate_outfit_image_transcodes_unsupported_format(httpx_mock):
    """An image in an unsupported format (e.g. BMP) gets transcoded to PNG."""
    import io
    from PIL import Image

    # Build a real BMP — Pillow can decode BMP but the proxy doesn't accept it.
    buf = io.BytesIO()
    Image.new("RGB", (32, 32), (10, 20, 30)).save(buf, format="BMP")
    bmp_bytes = buf.getvalue()
    assert bmp_bytes[:2] == b"BM"  # BMP magic

    httpx_mock.add_response(
        url="https://cdn.example.com/weird.bmp",
        method="GET",
        content=bmp_bytes,
        headers={"content-type": "image/bmp"},
    )
    payload_b64 = base64.b64encode(b"generated").decode()
    httpx_mock.add_response(
        url=f"{codex_image_service.settings.CODEX_PROXY_URL}/images/edits",
        method="POST",
        json={"data": [{"b64_json": payload_b64}]},
    )

    await codex_image_service.generate_outfit_image(
        reference_urls=["https://cdn.example.com/weird.bmp"],
        prompt="x",
        size="1024x1024",
        quality="high",
        n=1,
    )

    proxy_url = httpx.URL(f"{codex_image_service.settings.CODEX_PROXY_URL}/images/edits")
    proxy_req = next(r for r in httpx_mock.get_requests() if r.url == proxy_url)
    body = proxy_req.content.decode("latin-1")
    # The transcoded part should be PNG, not BMP.
    assert "Content-Type: image/png" in body
    assert 'filename="ref-0.png"' in body
    assert "Content-Type: image/bmp" not in body
