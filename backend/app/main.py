import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import auth, catalog, wardrobe, outfits, tryon

logging.basicConfig(level=settings.LOG_LEVEL.upper())
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Outfitter API — env=%s", settings.ENV)
    yield
    logger.info("Shutting down Outfitter API")


app = FastAPI(
    title="Outfitter API",
    version="1.0.0",
    description="Fashion app backend: catalog, wardrobe, AI outfit suggestions, and try-on.",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOW_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth)
app.include_router(catalog)
app.include_router(wardrobe)
app.include_router(outfits)
app.include_router(tryon)


@app.get("/health", tags=["health"])
async def health() -> dict:
    return {"status": "ok", "env": settings.ENV}
