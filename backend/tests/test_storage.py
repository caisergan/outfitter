"""Unit tests for app.services.storage_service.

All boto3 calls are mocked — no real S3/R2 credentials required.
"""

from unittest.mock import MagicMock, patch

import pytest
from botocore.exceptions import ClientError


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def _clear_client_cache():
    """Reset the lazy-initialised S3 client between tests."""
    from app.services.storage_service import _get_client
    _get_client.cache_clear()
    yield
    _get_client.cache_clear()


@pytest.fixture()
def mock_s3():
    """Patch ``_get_client`` to return a MagicMock S3 client."""
    client = MagicMock()
    with patch("app.services.storage_service._get_client", return_value=client):
        yield client


# ---------------------------------------------------------------------------
# _get_client
# ---------------------------------------------------------------------------


class TestGetClient:
    def test_blank_endpoint_url_is_normalized_to_none_for_aws(self) -> None:
        from app.services.storage_service import _get_client

        with patch("app.services.storage_service.settings") as mock_settings:
            mock_settings.R2_ENDPOINT_URL = ""
            mock_settings.R2_ACCESS_KEY_ID = "key"
            mock_settings.R2_SECRET_ACCESS_KEY = "secret"
            mock_settings.STORAGE_REGION = "us-east-1"

            with patch("app.services.storage_service.boto3.client") as mock_boto_client:
                _get_client()

        assert mock_boto_client.call_args.kwargs["endpoint_url"] is None
        assert mock_boto_client.call_args.kwargs["region_name"] == "us-east-1"


# ---------------------------------------------------------------------------
# get_upload_url
# ---------------------------------------------------------------------------


class TestGetUploadUrl:
    def test_generates_presigned_put_url(self, mock_s3: MagicMock) -> None:
        mock_s3.generate_presigned_url.return_value = "https://r2.example.com/signed-put"

        from app.services.storage_service import get_upload_url, settings

        url = get_upload_url(user_id="u1", item_id="item42")

        assert url == "https://r2.example.com/signed-put"
        mock_s3.generate_presigned_url.assert_called_once_with(
            "put_object",
            Params={
                "Bucket": settings.R2_BUCKET,
                "Key": "wardrobe/u1/item42.jpg",
                "ContentType": "image/jpeg",
            },
            ExpiresIn=900,
        )

    def test_key_format_contains_user_and_item(self, mock_s3: MagicMock) -> None:
        mock_s3.generate_presigned_url.return_value = "https://example.com"

        from app.services.storage_service import get_upload_url

        get_upload_url(user_id="abc-123", item_id="def-456")

        call_params = mock_s3.generate_presigned_url.call_args
        assert call_params.kwargs["Params"]["Key"] == "wardrobe/abc-123/def-456.jpg"

    def test_client_error_raises_storage_error(self, mock_s3: MagicMock) -> None:
        mock_s3.generate_presigned_url.side_effect = ClientError(
            error_response={"Error": {"Code": "AccessDenied", "Message": "denied"}},
            operation_name="GeneratePresignedUrl",
        )

        from app.services.storage_service import StorageError, get_upload_url

        with pytest.raises(StorageError, match="Could not generate upload URL"):
            get_upload_url(user_id="u1", item_id="i1")


# ---------------------------------------------------------------------------
# get_signed_read_url
# ---------------------------------------------------------------------------


class TestGetSignedReadUrl:
    def test_generates_presigned_get_url(self, mock_s3: MagicMock) -> None:
        mock_s3.generate_presigned_url.return_value = "https://r2.example.com/signed-get"

        from app.services.storage_service import get_signed_read_url, settings

        url = get_signed_read_url("wardrobe/u1/item42.jpg")

        assert url == "https://r2.example.com/signed-get"
        mock_s3.generate_presigned_url.assert_called_once_with(
            "get_object",
            Params={
                "Bucket": settings.R2_BUCKET,
                "Key": "wardrobe/u1/item42.jpg",
            },
            ExpiresIn=900,
        )

    def test_custom_expiry(self, mock_s3: MagicMock) -> None:
        mock_s3.generate_presigned_url.return_value = "https://example.com"

        from app.services.storage_service import get_signed_read_url

        get_signed_read_url("some/key.jpg", expires_in=3600)

        call_params = mock_s3.generate_presigned_url.call_args
        assert call_params.kwargs["ExpiresIn"] == 3600

    def test_client_error_raises_storage_error(self, mock_s3: MagicMock) -> None:
        mock_s3.generate_presigned_url.side_effect = ClientError(
            error_response={"Error": {"Code": "NoSuchKey", "Message": "not found"}},
            operation_name="GeneratePresignedUrl",
        )

        from app.services.storage_service import StorageError, get_signed_read_url

        with pytest.raises(StorageError, match="Could not generate read URL"):
            get_signed_read_url("missing/key.jpg")


# ---------------------------------------------------------------------------
# upload_bytes
# ---------------------------------------------------------------------------


class TestUploadBytes:
    def test_puts_object_with_correct_params(self, mock_s3: MagicMock) -> None:
        from app.services.storage_service import settings, upload_bytes

        data = b"\xff\xd8\xff\xe0fake-jpeg"
        upload_bytes("tryon/u1/job99.jpg", data)

        mock_s3.put_object.assert_called_once_with(
            Bucket=settings.R2_BUCKET,
            Key="tryon/u1/job99.jpg",
            Body=data,
            ContentType="image/jpeg",
        )

    def test_returns_key(self, mock_s3: MagicMock) -> None:
        from app.services.storage_service import upload_bytes

        key = upload_bytes("tryon/u1/job99.jpg", b"data")

        assert key == "tryon/u1/job99.jpg"

    def test_custom_content_type(self, mock_s3: MagicMock) -> None:
        from app.services.storage_service import upload_bytes

        upload_bytes("catalog/brand/item.png", b"data", content_type="image/png")

        call_kwargs = mock_s3.put_object.call_args.kwargs
        assert call_kwargs["ContentType"] == "image/png"

    def test_client_error_raises_storage_error(self, mock_s3: MagicMock) -> None:
        mock_s3.put_object.side_effect = ClientError(
            error_response={"Error": {"Code": "InternalError", "Message": "boom"}},
            operation_name="PutObject",
        )

        from app.services.storage_service import StorageError, upload_bytes

        with pytest.raises(StorageError, match="Could not upload bytes"):
            upload_bytes("bad/key.jpg", b"data")


# ---------------------------------------------------------------------------
# get_catalog_upload_target
# ---------------------------------------------------------------------------


class TestGetCatalogUploadTarget:
    def test_returns_upload_target_for_jpeg(self, mock_s3: MagicMock) -> None:
        mock_s3.generate_presigned_url.return_value = "https://s3.example.com/presigned"

        from app.services.storage_service import get_catalog_upload_target

        target = get_catalog_upload_target("Nike", "photo.jpg", "image/jpeg")

        assert target.upload_url == "https://s3.example.com/presigned"
        assert target.key.startswith("catalog/nike/")
        assert target.key.endswith(".jpg")

    def test_key_namespace_uses_brand_slug(self, mock_s3: MagicMock) -> None:
        mock_s3.generate_presigned_url.return_value = "https://example.com"

        from app.services.storage_service import get_catalog_upload_target

        target = get_catalog_upload_target("Ralph Lauren & Co.", "coat.png", "image/png")

        assert target.key.startswith("catalog/ralph-lauren-co/")

    def test_image_url_reflects_object_key(self, mock_s3: MagicMock) -> None:
        mock_s3.generate_presigned_url.return_value = "https://example.com"

        from app.services.storage_service import get_catalog_upload_target

        with patch("app.services.storage_service.settings") as mock_settings:
            mock_settings.STORAGE_PUBLIC_BASE_URL = "https://cdn.example.com"
            target = get_catalog_upload_target("Nike", "photo.jpg", "image/jpeg")

        assert target.image_url == f"https://cdn.example.com/{target.key}"

    def test_upload_target_uses_shared_expiry(self, mock_s3: MagicMock) -> None:
        mock_s3.generate_presigned_url.return_value = "https://example.com"

        from app.services.storage_service import IMAGE_UPLOAD_EXPIRES_IN, get_catalog_upload_target

        get_catalog_upload_target("Nike", "photo.jpg", "image/jpeg")

        call_kwargs = mock_s3.generate_presigned_url.call_args.kwargs
        assert call_kwargs["ExpiresIn"] == IMAGE_UPLOAD_EXPIRES_IN

    def test_storage_error_raises_storage_error(self, mock_s3: MagicMock) -> None:
        mock_s3.generate_presigned_url.side_effect = ClientError(
            error_response={"Error": {"Code": "AccessDenied", "Message": "denied"}},
            operation_name="GeneratePresignedUrl",
        )

        from app.services.storage_service import StorageError, get_catalog_upload_target

        with pytest.raises(StorageError):
            get_catalog_upload_target("Nike", "photo.jpg", "image/jpeg")


# ---------------------------------------------------------------------------
# _build_public_url — public URL construction strategy
# ---------------------------------------------------------------------------


class TestBuildPublicUrl:
    def test_uses_storage_public_base_url_when_set(self) -> None:
        from app.services.storage_service import _build_public_url

        with patch("app.services.storage_service.settings") as mock_settings:
            mock_settings.STORAGE_PUBLIC_BASE_URL = "https://cdn.example.com"
            url = _build_public_url("catalog/nike/abc.jpg")

        assert url == "https://cdn.example.com/catalog/nike/abc.jpg"

    def test_strips_trailing_slash_from_base_url(self) -> None:
        from app.services.storage_service import _build_public_url

        with patch("app.services.storage_service.settings") as mock_settings:
            mock_settings.STORAGE_PUBLIC_BASE_URL = "https://cdn.example.com/"
            url = _build_public_url("catalog/nike/abc.jpg")

        assert url == "https://cdn.example.com/catalog/nike/abc.jpg"

    def test_falls_back_to_s3_url_when_base_url_empty(self) -> None:
        from app.services.storage_service import _build_public_url

        with patch("app.services.storage_service.settings") as mock_settings:
            mock_settings.STORAGE_PUBLIC_BASE_URL = ""
            mock_settings.R2_BUCKET = "my-bucket"
            mock_settings.STORAGE_REGION = "us-east-1"
            url = _build_public_url("catalog/nike/abc.jpg")

        assert url == "https://my-bucket.s3.us-east-1.amazonaws.com/catalog/nike/abc.jpg"
