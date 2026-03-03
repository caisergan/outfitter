import asyncio
import logging
from functools import lru_cache

import torch
import open_clip
from PIL import Image
import io

logger = logging.getLogger(__name__)

# Load once at startup; shared across requests
_model, _, _preprocess = open_clip.create_model_and_transforms(
    "ViT-B-32", pretrained="openai"
)
_model.eval()


def embed_image(image_bytes: bytes) -> list[float]:
    """Return a 512-dim L2-normalised CLIP embedding for the given image bytes."""
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    tensor = _preprocess(image).unsqueeze(0)

    with torch.no_grad():
        embedding = _model.encode_image(tensor)
        embedding = embedding / embedding.norm(dim=-1, keepdim=True)

    return embedding[0].tolist()


async def embed_image_async(image_bytes: bytes) -> list[float]:
    """Non-blocking wrapper around embed_image using a thread executor."""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, embed_image, image_bytes)
