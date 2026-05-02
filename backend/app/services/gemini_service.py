"""Wardrobe item tagging via Gemini.

Called by ``POST /wardrobe/tag``. Sends a background-removed garment image
plus the controlled vocabularies for the new taxonomy
(slot/category/subcategory/pattern/fit/style_tags/occasion_tags) and returns
structured JSON validated by Gemini's ``response_schema`` mode.

The vocabularies and the catalog-side tagging script
(``backend/scripts/tag_catalog_styles.py``) MUST agree — both ultimately get
fed to ``app.schemas.catalog`` Literals at the API boundary.
"""

import json
import logging
from typing import Any

from google import genai
from google.genai import types

from app.config import settings
from app.schemas.catalog import (
    CATALOG_CATEGORY,
    CATALOG_FIT,
    CATALOG_OCCASION_TAG,
    CATALOG_PATTERN,
    CATALOG_SLOT,
    CATALOG_STYLE_TAG,
)

logger = logging.getLogger(__name__)

DEFAULT_MODEL = "gemini-2.5-flash-lite"
MAX_OUTPUT_TOKENS = 400


def _vocab_list(literal_type) -> list[str]:
    return list(literal_type.__args__)


def _build_prompt() -> str:
    """Compact prompt — vocabulary terms are enforced via response_schema, not the prompt."""
    return (
        "You are a fashion classification AI. Look at this clothing item and return "
        "structured tags from the controlled vocabularies in the response schema.\n\n"
        "Rules:\n"
        "- `slot` is REQUIRED — it is the wardrobe slot (top/bottom/dress/...).\n"
        "- `category` is the garment kind (jeans/blazer/t-shirt/...). Pick one if a clean match exists, else omit.\n"
        "- `subcategory` is a free-text finer grain ONLY when meaningful (oxford, midi, bomber). Most items: omit.\n"
        "- `color`: list dominant colors as lowercase strings (e.g. ['black', 'white']).\n"
        "- `pattern`, `fit`, `style_tags`, `occasion_tags`: only return values from the schema enums.\n"
        "- Empty arrays are valid for `pattern`/`style_tags`/`occasion_tags` when nothing fits.\n"
        "- `confidence`: float 0.0-1.0 reflecting how sure you are about the slot+category."
    )


def _build_response_schema() -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "slot": {"type": "string", "enum": _vocab_list(CATALOG_SLOT)},
            "category": {"type": "string", "enum": _vocab_list(CATALOG_CATEGORY)},
            "subcategory": {"type": "string"},
            "color": {"type": "array", "items": {"type": "string"}},
            "pattern": {
                "type": "array",
                "items": {"type": "string", "enum": _vocab_list(CATALOG_PATTERN)},
            },
            "fit": {"type": "string", "enum": _vocab_list(CATALOG_FIT)},
            "style_tags": {
                "type": "array",
                "items": {"type": "string", "enum": _vocab_list(CATALOG_STYLE_TAG)},
            },
            "occasion_tags": {
                "type": "array",
                "items": {"type": "string", "enum": _vocab_list(CATALOG_OCCASION_TAG)},
            },
            "confidence": {"type": "number"},
        },
        "required": ["slot", "confidence"],
    }


def _coerce_to_vocab(value: Any, vocab: list[str]) -> str | None:
    """Defense-in-depth — schema should already constrain, but validate."""
    if not value:
        return None
    return value if value in vocab else None


def _coerce_list_to_vocab(values: Any, vocab: list[str]) -> list[str]:
    if not values:
        return []
    return [v for v in values if v in vocab]


async def tag_wardrobe_item_with_gemini(
    image_bytes: bytes,
    mime_type: str = "image/png",
) -> dict[str, Any]:
    """Send the cleaned garment image to Gemini and return validated tags.

    Returns a dict with the WardrobeTagResponse fields populated. On failure,
    returns a minimal payload with confidence=0.0 and an error key, so the
    caller can decide whether to surface the error.
    """
    api_key = settings.GEMINI_API_KEY
    if not api_key:
        logger.error("GEMINI_API_KEY is not configured")
        return {"slot": "top", "confidence": 0.0, "error": "missing_api_key"}

    client = genai.Client(api_key=api_key)
    prompt = _build_prompt()
    schema = _build_response_schema()

    try:
        response = await client.aio.models.generate_content(
            model=DEFAULT_MODEL,
            contents=[
                types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                prompt,
            ],
            config=types.GenerateContentConfig(
                max_output_tokens=MAX_OUTPUT_TOKENS,
                response_mime_type="application/json",
                response_schema=schema,
            ),
        )
    except Exception as exc:
        logger.error("Gemini wardrobe tagging failed: %s: %s", type(exc).__name__, exc)
        return {"slot": "top", "confidence": 0.0, "error": str(exc)}

    text = getattr(response, "text", None)
    if not text:
        logger.error("Gemini returned empty response")
        return {"slot": "top", "confidence": 0.0, "error": "empty_response"}

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        logger.error("Gemini returned non-JSON: %s", text[:300])
        return {"slot": "top", "confidence": 0.0, "error": "json_parse_error"}

    # Defense-in-depth: re-validate every field against the controlled vocab.
    return {
        "slot": parsed.get("slot") or "top",
        "category": _coerce_to_vocab(parsed.get("category"), _vocab_list(CATALOG_CATEGORY)),
        "subcategory": parsed.get("subcategory") or None,
        "color": parsed.get("color") or [],
        "pattern": _coerce_list_to_vocab(parsed.get("pattern"), _vocab_list(CATALOG_PATTERN)),
        "fit": _coerce_to_vocab(parsed.get("fit"), _vocab_list(CATALOG_FIT)),
        "style_tags": _coerce_list_to_vocab(parsed.get("style_tags"), _vocab_list(CATALOG_STYLE_TAG)),
        "occasion_tags": _coerce_list_to_vocab(parsed.get("occasion_tags"), _vocab_list(CATALOG_OCCASION_TAG)),
        "confidence": float(parsed.get("confidence", 0.0)),
    }
