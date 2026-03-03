import base64
import json
import logging

import anthropic
from PIL import Image
import io

from app.config import settings

logger = logging.getLogger(__name__)

client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

TAGGING_PROMPT = """You are a fashion AI. Analyze this clothing item and return a JSON object with exactly these fields:
- category: one of [top, bottom, shoes, accessory, outerwear, bag]
- subtype: specific garment type (e.g. "midi skirt", "sneaker", "blazer")
- color: list of dominant colors as lowercase strings (e.g. ["black", "white"])
- pattern: one of [solid, striped, floral, plaid, graphic, other]
- fit: one of [fitted, relaxed, oversized, a-line, straight]
- style_tags: list of 2-4 style descriptors (e.g. ["casual", "minimal"])
- confidence: float between 0.0 and 1.0

Return only valid JSON. No explanation, no markdown."""

SUGGEST_PROMPT = """You are a personal fashion stylist. Given the user's parameters and available items, \
suggest {count} complete outfits. Each outfit must include at minimum: top, bottom, shoes.

Parameters:
- Occasion: {occasion}
- Season: {season}
- Color preference: {color_preference}
- Source: {source}

Available items (JSON list):
{items_json}

Return a JSON array of outfits. Each outfit must be:
{{
  "slots": {{"top": "<item_id>", "bottom": "<item_id>", "shoes": "<item_id>"}},
  "style_note": "<one sentence describing the look>"
}}

Only use item IDs from the provided list. Return only valid JSON array. No explanation."""


def _strip_faces_and_crop(image_bytes: bytes) -> bytes:
    """Crop image to lower 80% to reduce chance of capturing faces."""
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        width, height = img.size
        # Crop top 20% to remove face region in typical flat-lay/hanging shots
        top_crop = int(height * 0.20)
        cropped = img.crop((0, top_crop, width, height))
        buf = io.BytesIO()
        cropped.save(buf, format="JPEG", quality=85)
        return buf.getvalue()
    except Exception:
        return image_bytes


async def tag_wardrobe_item(image_bytes: bytes, media_type: str = "image/jpeg") -> dict:
    """Send a clothing photo to Claude and return structured tags."""
    safe_bytes = _strip_faces_and_crop(image_bytes)
    image_b64 = base64.standard_b64encode(safe_bytes).decode("utf-8")

    for attempt in range(2):
        prompt = TAGGING_PROMPT if attempt == 0 else TAGGING_PROMPT + "\nIMPORTANT: Respond with JSON only."
        try:
            response = client.messages.create(
                model="claude-opus-4-6",
                max_tokens=300,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "image",
                                "source": {
                                    "type": "base64",
                                    "media_type": media_type,
                                    "data": image_b64,
                                },
                            },
                            {"type": "text", "text": prompt},
                        ],
                    }
                ],
            )
            return json.loads(response.content[0].text)
        except json.JSONDecodeError:
            logger.warning("Claude returned non-JSON on attempt %d", attempt + 1)
            if attempt == 1:
                return {"category": "unknown", "confidence": 0.0}
    return {"category": "unknown", "confidence": 0.0}


# In-memory cache: keyed by param hash, value: (outfits, expires_at)
_suggest_cache: dict[str, tuple[list, float]] = {}


async def suggest_outfits(params: dict, available_items: list) -> list:
    """Ask Claude to suggest outfits and return a list of outfit dicts."""
    import time
    import hashlib

    cache_key = hashlib.md5(
        json.dumps(params, sort_keys=True).encode() + str(len(available_items)).encode()
    ).hexdigest()

    now = time.time()
    if cache_key in _suggest_cache:
        cached, expires_at = _suggest_cache[cache_key]
        if now < expires_at:
            logger.debug("Returning cached outfit suggestions")
            return cached

    prompt = SUGGEST_PROMPT.format(
        count=4,
        occasion=params.get("occasion", "casual"),
        season=params.get("season", "spring"),
        color_preference=params.get("color_preference", "neutral"),
        source=params.get("source", "mix"),
        items_json=json.dumps(available_items, ensure_ascii=False),
    )

    try:
        response = client.messages.create(
            model="claude-opus-4-6",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}],
        )
        outfits = json.loads(response.content[0].text)
        if not isinstance(outfits, list):
            outfits = []
    except (json.JSONDecodeError, Exception) as exc:
        logger.error("Claude suggest_outfits failed: %s", exc)
        outfits = []

    _suggest_cache[cache_key] = (outfits, now + 86400)  # 24h TTL
    return outfits
