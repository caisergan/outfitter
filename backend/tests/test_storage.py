"""Unit tests for app.services.storage_service.

All boto3 calls are mocked — no real R2 credentials required.
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
# get_upload_url
# ---------------------------------------------------------------------------


class TestGetUploadUrl:
    def test_generates_presigned_put_url(self, mock_s3: MagicMock) -> None:
        mock_s3.generate_presigned_url.return_value = "https://r2.example.com/signed-put"

        from app.services.storage_service import get_upload_url

        url = get_upload_url(user_id="u1", item_id="item42")

        assert url == "https://r2.example.com/signed-put"
        mock_s3.generate_presigned_url.assert_called_once_with(
            "put_object",
            Params={
                "Bucket": "outfitter-media",
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

        from app.services.storage_service import get_signed_read_url

        url = get_signed_read_url("wardrobe/u1/item42.jpg")

        assert url == "https://r2.example.com/signed-get"
        mock_s3.generate_presigned_url.assert_called_once_with(
            "get_object",
            Params={
                "Bucket": "outfitter-media",
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
        from app.services.storage_service import upload_bytes

        data = b"\xff\xd8\xff\xe0fake-jpeg"
        upload_bytes("tryon/u1/job99.jpg", data)

        mock_s3.put_object.assert_called_once_with(
            Bucket="outfitter-media",
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
