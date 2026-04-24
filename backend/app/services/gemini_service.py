import json
import logging
from google import genai
from google.genai import types

from app.config import settings

logger = logging.getLogger(__name__)

TAGGING_PROMPT = """Analyze the clothing item in this image and return ONLY a valid JSON object with these exact fields:
{
  "category": "one of: top, bottom, shoes, accessory, outerwear, bag",
  "subtype": "specific garment type e.g. t-shirt hoodie sneaker",
  "color": ["list", "of", "dominant", "colors"],
  "pattern": "one of: solid striped floral plaid graphic animal other",
  "fit": "one of: fitted relaxed oversized a-line straight",
  "style_tags": ["2", "to", "4", "style", "words"],
  "confidence": 0.95
}
Return ONLY the JSON object. No markdown, no explanation."""


async def tag_wardrobe_item_with_gemini(image_bytes: bytes, mime_type: str = "image/png") -> dict:
    """
    Sends the background-removed image to Gemini and returns structured clothing tags.
    """
    try:
        client = genai.Client(api_key=settings.GEMINI_API_KEY)

        response = client.models.generate_content(
            model="gemini-2.5-flash-lite",
            contents=[
                types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                types.Part.from_text(text=TAGGING_PROMPT),
            ],
        )

        raw_text = response.text.strip()
        logger.info(f"Gemini raw response: {raw_text[:200]}")

        # Strip markdown code fences if present
        if raw_text.startswith("```"):
            lines = raw_text.split("\n")
            if "json" in lines[0].lower():
                raw_text = "\n".join(lines[1:-1])
            else:
                raw_text = "\n".join(lines[1:-1])

        result = json.loads(raw_text)
        return result

    except json.JSONDecodeError as e:
        logger.error(f"Gemini returned non-JSON! Raw text: {raw_text}")
        return {"category": "unknown", "confidence": 0.0, "error": "json_parse_error"}
    except Exception as e:
        logger.error(f"CRITICAL: Gemini tagging failed: {type(e).__name__}: {str(e)}")
        return {"category": "unknown", "confidence": 0.0, "error": str(e)}
