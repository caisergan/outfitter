"""Cloudflare R2 / S3-compatible storage service.

Provides pre-signed URLs for client uploads, signed read URLs for serving
private images, and a helper for direct backend uploads (e.g. Kling results).
"""

import logging
from functools import lru_cache

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

from app.config import settings

logger = logging.getLogger(__name__)


class StorageError(Exception):
    """Raised when an R2/S3 operation fails."""


@lru_cache(maxsize=1)
def _get_client():
    """Lazily create and cache a single boto3 S3 client.

    Using ``lru_cache`` ensures the client is only created the first time
    a storage function is called — not at module-import time — so tests
    and other modules that never call storage functions won't crash when
    R2 env vars are absent.
    """
    logger.info("Initializing R2 storage client → %s", settings.R2_ENDPOINT_URL)
    return boto3.client(
        "s3",
        endpoint_url=settings.R2_ENDPOINT_URL,
        aws_access_key_id=settings.R2_ACCESS_KEY_ID,
        aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
        region_name="auto",
        config=Config(signature_version="s3v4"),
    )


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def get_upload_url(user_id: str, item_id: str) -> str:
    """Return a 15-min pre-signed PUT URL for uploading a wardrobe JPEG.

    The object key follows the convention ``wardrobe/{user_id}/{item_id}.jpg``.
    """
    key = f"wardrobe/{user_id}/{item_id}.jpg"
    try:
        url: str = _get_client().generate_presigned_url(
            "put_object",
            Params={
                "Bucket": settings.R2_BUCKET,
                "Key": key,
                "ContentType": "image/jpeg",
            },
            ExpiresIn=900,
        )
        logger.debug("Generated upload URL for key=%s", key)
        return url
    except (ClientError, BotoCoreError) as exc:
        logger.error("Failed to generate upload URL for key=%s: %s", key, exc)
        raise StorageError(f"Could not generate upload URL: {exc}") from exc


def get_signed_read_url(key: str, expires_in: int = 900) -> str:
    """Return a short-lived signed GET URL for serving a private image.

    Args:
        key: Full object key in the bucket (e.g. ``wardrobe/abc/xyz.jpg``).
        expires_in: URL lifetime in seconds (default 900 = 15 minutes).
    """
    try:
        url: str = _get_client().generate_presigned_url(
            "get_object",
            Params={"Bucket": settings.R2_BUCKET, "Key": key},
            ExpiresIn=expires_in,
        )
        logger.debug("Generated read URL for key=%s (expires=%ds)", key, expires_in)
        return url
    except (ClientError, BotoCoreError) as exc:
        logger.error("Failed to generate read URL for key=%s: %s", key, exc)
        raise StorageError(f"Could not generate read URL: {exc}") from exc


def upload_bytes(
    key: str,
    data: bytes,
    content_type: str = "image/jpeg",
) -> str:
    """Upload raw bytes directly from the backend.

    Typical usage: persisting Kling try-on result images to
    ``tryon/{user_id}/{job_id}.jpg``.

    Returns:
        The object key that was written, so callers can reference it easily.
    """
    try:
        _get_client().put_object(
            Bucket=settings.R2_BUCKET,
            Key=key,
            Body=data,
            ContentType=content_type,
        )
        logger.info("Uploaded %d bytes → %s (type=%s)", len(data), key, content_type)
        return key
    except (ClientError, BotoCoreError) as exc:
        logger.error("Failed to upload bytes to key=%s: %s", key, exc)
        raise StorageError(f"Could not upload bytes: {exc}") from exc
