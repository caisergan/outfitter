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

    # Storage (Cloudflare R2 / AWS S3)
    R2_ENDPOINT_URL: str | None = None  # None = use AWS default endpoint resolution
    R2_ACCESS_KEY_ID: str
    R2_SECRET_ACCESS_KEY: str
    R2_BUCKET: str
    STORAGE_REGION: str = "auto"  # "auto" for R2; use e.g. "us-east-1" for real AWS S3
    STORAGE_PUBLIC_BASE_URL: str = ""  # e.g. https://cdn.example.com or https://<bucket>.s3.<region>.amazonaws.com

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
