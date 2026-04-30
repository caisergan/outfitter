"""AWS S3 / S3-compatible storage service.

Provides presigned PUT upload targets for client uploads, signed read URLs for
serving private images, and a helper for direct backend uploads (e.g. try-on results).

Upload target flow:
  1. Caller requests an upload target.
  2. Client PUTs image bytes directly to ``upload_url`` with the correct Content-Type.
  3. Client passes the returned ``image_url`` to a create or update endpoint that
     stores the durable public URL.

Follow-up work (out of scope for this change):
  - Object lifecycle cleanup when persisted image_url values are replaced.
  - Private-bucket read signing for deployments where the bucket is not public.
"""

import logging
import re
from dataclasses import dataclass
from functools import lru_cache
from uuid import uuid4

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

from app.config import settings

logger = logging.getLogger(__name__)

IMAGE_UPLOAD_EXPIRES_IN = 900  # 15 minutes shared image upload target expiry

ALLOWED_CATALOG_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
CONTENT_TYPE_EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


class StorageError(Exception):
    """Raised when an R2/S3 operation fails."""


@dataclass(frozen=True)
class UploadTarget:
    key: str
    upload_url: str
    image_url: str


@lru_cache(maxsize=1)
def _get_client():
    """Lazily create and cache a single boto3 S3 client.

    Supports both Cloudflare R2 (with endpoint_url) and standard AWS S3.
    """
    endpoint = settings.R2_ENDPOINT_URL
    # Check if endpoint is a placeholder or empty
    if not endpoint or "<account_id>" in endpoint:
        endpoint = None
        region = settings.STORAGE_REGION
    else:
        region = "auto"  # Cloudflare R2 convention

    logger.info("Initializing storage client → Region: %s, Endpoint: %s", region, endpoint)
    
    return boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=settings.R2_ACCESS_KEY_ID,
        aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
        region_name=region,
        config=Config(signature_version="s3v4"),
    )


def _slugify(text: str) -> str:
    """Convert brand or folder name to URL-safe lowercase slug."""
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def _build_public_url(key: str) -> str:
    """Construct a stable public URL for an object key."""
    base = (settings.STORAGE_PUBLIC_BASE_URL or "").rstrip("/")
    if base:
        return f"{base}/{key}" if key else base
    # Fallback: synthesise an S3-style URL from bucket + region
    bucket = settings.R2_BUCKET
    region = settings.STORAGE_REGION
    base = f"https://{bucket}.s3.{region}.amazonaws.com"
    return f"{base}/{key}" if key else base


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def _generate_presigned_put(key: str, content_type: str, expires_in: int = 900) -> str:
    """Generate a presigned PUT URL for any object key and content type."""
    try:
        url: str = _get_client().generate_presigned_url(
            "put_object",
            Params={
                "Bucket": settings.R2_BUCKET,
                "Key": key,
                "ContentType": content_type,
            },
            ExpiresIn=expires_in,
        )
        logger.debug("Generated presigned PUT URL for key=%s", key)
        return url
    except (ClientError, BotoCoreError) as exc:
        logger.error("Failed to generate presigned PUT URL for key=%s: %s", key, exc)
        raise StorageError(f"Could not generate upload URL: {exc}") from exc


def get_upload_url(user_id: str, item_id: str) -> str:
    """Return a 15-min pre-signed PUT URL for uploading a wardrobe JPEG.

    The object key follows the convention ``wardrobe/{user_id}/{item_id}.jpg``.
    """
    key = f"wardrobe/{user_id}/{item_id}.jpg"
    return _generate_presigned_put(key, "image/jpeg")


def get_catalog_upload_target(brand: str, filename: str, content_type: str) -> UploadTarget:
    """Return a presigned PUT URL plus stable public image URL for a catalog image.

    The object key follows ``catalog/{brand-slug}/{uuid}{ext}`` so URLs are
    stable after upload and can be stored directly in ``catalog_items.image_url``.

    Args:
        brand: The catalog item brand name (used as folder slug).
        filename: Original filename from the client (used to infer extension fallback).
        content_type: MIME type of the image (must be jpeg, png, or webp).

    Raises:
        StorageError: if the presigned URL cannot be generated.
    """
    extension = CONTENT_TYPE_EXTENSIONS.get(content_type)
    if not extension:
        # Fall back to file extension from the original filename
        dot_index = filename.rfind(".")
        extension = ("." + filename[dot_index + 1:].lower()) if dot_index != -1 else ""

    key = f"catalog/{_slugify(brand)}/{uuid4()}{extension}"
    upload_url = _generate_presigned_put(key, content_type, expires_in=IMAGE_UPLOAD_EXPIRES_IN)
    image_url = _build_public_url(key)
    return UploadTarget(key=key, upload_url=upload_url, image_url=image_url)


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

    Typical usage: persisting try-on generation result images to
    ``tryon/{user_id}/{run_id}/{idx}.png``.

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


def download_bytes(key: str) -> bytes:
    """Download raw bytes from R2 using the object key."""
    try:
        response = _get_client().get_object(Bucket=settings.R2_BUCKET, Key=key)
        return response["Body"].read()
    except (ClientError, BotoCoreError) as exc:
        logger.error("Failed to download bytes from key=%s: %s", key, exc)
        raise StorageError(f"Could not download bytes: {exc}") from exc


def get_public_url(key: str) -> str:
    """Return a public URL for the given key.
    
    Uses STORAGE_PUBLIC_BASE_URL if configured, otherwise falls back to 
    standard S3 URL format or signed URL if private.
    """
    if settings.STORAGE_PUBLIC_BASE_URL:
        base_url = settings.STORAGE_PUBLIC_BASE_URL.rstrip("/")
        return f"{base_url}/{key}"
    
    # Fallback to standard S3 URL (works if bucket is public)
    if not settings.R2_ENDPOINT_URL or "<account_id>" in settings.R2_ENDPOINT_URL:
        return f"https://{settings.R2_BUCKET}.s3.{settings.STORAGE_REGION}.amazonaws.com/{key}"
    
    # For R2 or other S3 compatibles, we might need a signed URL or custom domain
    return get_signed_read_url(key, expires_in=3600 * 24 * 7)  # 7 days
