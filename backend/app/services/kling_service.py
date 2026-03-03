import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

KLING_BASE_URL = "https://api.klingai.com/v1"


async def submit_tryon(outfit_image_urls: dict, model_photo_url: str) -> str:
    """Submit a virtual try-on job to Kling and return the job_id."""
    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.post(
            f"{KLING_BASE_URL}/tryon/submit",
            headers={"Authorization": f"Bearer {settings.KLING_API_KEY}"},
            json={
                "garment_images": outfit_image_urls,
                "model_image": model_photo_url,
            },
        )
        response.raise_for_status()
        return response.json()["job_id"]


async def poll_tryon_status(job_id: str) -> dict:
    """Poll Kling for the status of a try-on job."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(
            f"{KLING_BASE_URL}/tryon/status/{job_id}",
            headers={"Authorization": f"Bearer {settings.KLING_API_KEY}"},
        )
        response.raise_for_status()
        data = response.json()

    status = data.get("status", "processing")

    if status == "failed":
        raise RuntimeError(f"Kling job {job_id} failed: {data.get('error', 'unknown')}")

    return data
