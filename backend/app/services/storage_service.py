import logging

import boto3
from botocore.config import Config

from app.config import settings

logger = logging.getLogger(__name__)

s3 = boto3.client(
    "s3",
    endpoint_url=settings.R2_ENDPOINT_URL,
    aws_access_key_id=settings.R2_ACCESS_KEY_ID,
    aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
    config=Config(signature_version="s3v4"),
)


def get_upload_url(user_id: str, item_id: str) -> str:
    """Return a 15-min pre-signed PUT URL for uploading a wardrobe image."""
    key = f"wardrobe/{user_id}/{item_id}.jpg"
    return s3.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": settings.R2_BUCKET,
            "Key": key,
            "ContentType": "image/jpeg",
        },
        ExpiresIn=900,
    )


def get_signed_read_url(key: str) -> str:
    """Return a 15-min signed GET URL for serving a private image."""
    return s3.generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.R2_BUCKET, "Key": key},
        ExpiresIn=900,
    )


def upload_bytes(key: str, data: bytes, content_type: str = "image/jpeg") -> None:
    """Upload raw bytes directly from the backend (e.g. Kling result images)."""
    s3.put_object(
        Bucket=settings.R2_BUCKET,
        Key=key,
        Body=data,
        ContentType=content_type,
    )
