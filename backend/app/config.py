from functools import lru_cache
from pydantic_settings import SettingsConfigDict, BaseSettings

class Settings(BaseSettings):
    # Database
    DATABASE_URL: str
    DOCKER_DATABASE_URL: str | None = None
    USE_EXTERNAL_DB: bool = False
    REDIS_URL: str = "redis://redis:6379/0"

    # Auth
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_DAYS: int = 7
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # AI APIs
    ANTHROPIC_API_KEY: str
    GEMINI_API_KEY: str

    # OpenAI-compatible proxy for gpt-image-2 try-on generation.
    CODEX_PROXY_URL: str = "http://localhost:8317/v1"
    CODEX_PROXY_API_KEY: str = "dummy"

    # Try-on generation.
    TRYON_DAILY_CAP: int = 5
    TRYON_FAILED_RUNS_COUNT_TOWARD_CAP: bool = True

    # Storage (AWS S3 or S3-compatible endpoint such as Cloudflare R2)
    R2_ENDPOINT_URL: str | None = None
    R2_ACCESS_KEY_ID: str
    R2_SECRET_ACCESS_KEY: str
    R2_BUCKET: str
    STORAGE_REGION: str = "eu-north-1"
    STORAGE_PUBLIC_BASE_URL: str | None = None

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
