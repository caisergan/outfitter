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
        url="http://localhost:8317/v1/images/edits",
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
        if r.url == httpx.URL("http://localhost:8317/v1/images/edits")
    )
    body = proxy_req.content.decode("latin-1")
    assert proxy_req.headers["authorization"] == "Bearer dummy"
    assert 'name="model"' in body and "gpt-image-2" in body
    assert body.count('name="image[]"') == 2
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
        content=b"fake",
    )
    httpx_mock.add_response(
        url="http://localhost:8317/v1/images/edits",
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
        content=b"fake",
    )
    httpx_mock.add_exception(
        httpx.ReadTimeout("timed out"),
        url="http://localhost:8317/v1/images/edits",
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
