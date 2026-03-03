from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str
    REDIS_URL: str = "redis://redis:6379/0"

    # Auth
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_DAYS: int = 7

    # AI APIs
    ANTHROPIC_API_KEY: str
    KLING_API_KEY: str

    # Storage (Cloudflare R2 / AWS S3)
    R2_ENDPOINT_URL: str
    R2_ACCESS_KEY_ID: str
    R2_SECRET_ACCESS_KEY: str
    R2_BUCKET: str

    # App
    ENV: str = "development"
    LOG_LEVEL: str = "info"
    ALLOW_ORIGINS: list[str] = ["*"]

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
