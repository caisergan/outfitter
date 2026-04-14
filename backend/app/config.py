from functools import lru_cache
from pydantic_settings import SettingsConfigDict
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str
    DOCKER_DATABASE_URL: str | None = None
    USE_EXTERNAL_DB: bool = False
    REDIS_URL: str = "redis://redis:6379/0"

    # Auth
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_DAYS: int = 7

    # AI APIs
    ANTHROPIC_API_KEY: str
    KLING_API_KEY: str

    # Storage (AWS S3 or S3-compatible endpoint such as Cloudflare R2)
    #
    # AWS S3:
    #   R2_ENDPOINT_URL   — legacy env name; leave blank for AWS S3 so boto3
    #                       resolves the endpoint from bucket + region
    #   R2_ACCESS_KEY_ID  — IAM access key with s3:PutObject + s3:GetObject on the bucket
    #   R2_SECRET_ACCESS_KEY
    #   R2_BUCKET         — target bucket name
    #   STORAGE_REGION    — AWS region, e.g. "us-east-1" (required for correct URL signing)
    #   STORAGE_PUBLIC_BASE_URL — public delivery base URL, e.g.
    #                             https://d1234abcd.cloudfront.net  (CloudFront)
    #                             https://<bucket>.s3.<region>.amazonaws.com  (direct S3)
    #
    # Cloudflare R2 (S3-compatible):
    #   R2_ENDPOINT_URL   — https://<account_id>.r2.cloudflarestorage.com
    #   STORAGE_REGION    — "auto"
    #   STORAGE_PUBLIC_BASE_URL — your R2 public bucket URL or custom domain
    R2_ENDPOINT_URL: str | None = None
    R2_ACCESS_KEY_ID: str
    R2_SECRET_ACCESS_KEY: str
    R2_BUCKET: str
    STORAGE_REGION: str = "auto"
    STORAGE_PUBLIC_BASE_URL: str = ""

    # App
    ENV: str = "development"
    LOG_LEVEL: str = "info"
    ALLOW_ORIGINS: list[str] = ["*"]

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
    )


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
