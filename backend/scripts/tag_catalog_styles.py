"""Auto-tag catalog items with style_tags and occasion_tags using Gemini 3 Flash.

For each catalog item, fetches the product image, sends it plus the controlled
vocabularies to Gemini 3 Flash, and writes the returned tags back to the
database. Uses Gemini's JSON mode with a `response_schema` so the model can
only return values from the allowlists.

REQUIRES the schema migration that adds the `occasion_tags` column on
`catalog_items` to be applied first. The script will fail with a clear error
at startup if the column is missing.

Dependencies:
    pip install google-genai httpx sqlalchemy asyncpg

Auth:
    Set GEMINI_API_KEY (preferred) or GOOGLE_API_KEY. The script auto-loads
    `backend/.env` at startup, so adding `GEMINI_API_KEY=...` to that file
    is the simplest path. A real env var (e.g. `export GEMINI_API_KEY=...`)
    takes precedence over the `.env` file.

Usage:
    python -m scripts.tag_catalog_styles --sample 50 --dry-run     # preview run
    python -m scripts.tag_catalog_styles --brand mango --limit 200 # batch
    python -m scripts.tag_catalog_styles                           # full corpus
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import sys
import time
from pathlib import Path
from typing import Any

import httpx
from dotenv import load_dotenv
from google import genai
from google.genai import types
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

# Resolve repo paths and load backend/.env before importing app modules
# so settings (and our own os.environ reads) see the values.
_BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_BACKEND_DIR))
load_dotenv(_BACKEND_DIR / ".env")

from app.models.catalog import CatalogItem  # noqa: E402


# ---------------------------------------------------------------------------
# Controlled vocabularies. Keep in lockstep with the validation layer in the
# catalog API and the migration that introduces occasion_tags.
# ---------------------------------------------------------------------------

STYLE_TAGS: dict[str, str] = {
    "minimal":     "Clean lines, neutral palette, no graphics, simple silhouettes.",
    "classic":     "Timeless pieces — trench, white shirt, LBD, oxford shirt, loafers.",
    "old-money":   "Quiet luxury — monochrome neutrals, cashmere, loafers, polo + chinos, understated.",
    "clean-girl":  "Slick polished casual — white tank, slim jeans, gold hoops, neat, no-makeup makeup vibe.",
    "preppy":      "Collegiate codes — polos, blazers, pleated skirts, argyle, breton.",
    "streetwear":  "Urban, oversized fits, hoodies, graphic tees, sneaker-driven.",
    "bohemian":    "Flowy, earth tones, prints, fringe, crochet, layered.",
    "romantic":    "Feminine — lace, ruffles, ribbons, pastels, florals on light fabrics.",
    "edgy":        "Black palette, bold cuts, leather, hardware, asymmetry.",
    "grunge":      "Distressed, plaid flannel, ripped denim, slouchy, 90s influence.",
    "vintage":     "Retro silhouettes — 70s/80s/90s reference, period detailing.",
    "y2k":         "Early-2000s codes — low-rise, baby tees, rhinestones, butterflies, metallics.",
    "sporty":      "Athletic-inspired — tracksuits, performance fabrics, racing stripes.",
    "athleisure":  "Sport-meets-casual — leggings, crop tops, technical fabrics worn off-court.",
    "utility":     "Military/workwear codes — cargo pockets, field jackets, drawstrings, khaki/olive.",
    "glam":        "Evening-dressy — sequins, satin, bodycon, statement.",
    "parisian":    "Effortless French codes — breton stripes, slim trousers, trench, ballet flats.",
}

OCCASION_TAGS: dict[str, str] = {
    "office":        "Professional setting — tailored, structured, conservative palette.",
    "interview":     "Job interviews — conservative, polished, low-risk, minimal pattern, neutrals.",
    "formal":        "Black-tie, galas — gowns, suits, evening dresses.",
    "wedding-guest": "Formal but not overshadowing the bride — elegant, midi/maxi, refined.",
    "smart-casual":  "Between casual and formal — blazer + jeans, polished casual.",
    "casual":        "Everyday wear — t-shirts, jeans, sweaters, no occasion-specific cues.",
    "date-night":    "Elevated casual — slightly dressy but not formal.",
    "party":         "Nightlife/clubbing — short, sparkly, attention-getting.",
    "festival":      "Music festivals — bold, expressive, layered, prints, accessories.",
    "travel":        "Airport/road — comfort + style, soft tailoring, easy layers.",
    "beach":         "Resort/vacation/swim — swimwear, cover-ups, linen, light fabrics.",
    "athletic":      "Gym/running/sports — performance gear, sneakers, sports bras.",
    "loungewear":    "At-home comfort — sweats, soft knits, slippers, robes.",
}

DEFAULT_MODEL = "gemini-3-flash"
DEFAULT_CONCURRENCY = 10
PROGRESS_REPORT_EVERY = 50
MAX_OUTPUT_TOKENS = 200
IMAGE_FETCH_TIMEOUT_S = 30.0
SUPPORTED_IMAGE_MIMES = {"image/jpeg", "image/png", "image/webp", "image/gif"}

# Gemini 3 Flash pricing (per 1M tokens). Verify against current Google AI
# pricing before relying on the cost report — these are placeholders.
INPUT_PRICE_PER_M = 0.15
OUTPUT_PRICE_PER_M = 0.60

logger = logging.getLogger("tag_catalog_styles")


# ---------------------------------------------------------------------------
# Prompt + schema
# ---------------------------------------------------------------------------

def build_system_instruction() -> str:
    style_lines = "\n".join(f"- **{n}**: {d}" for n, d in STYLE_TAGS.items())
    occasion_lines = "\n".join(f"- **{n}**: {d}" for n, d in OCCASION_TAGS.items())
    return (
        "You are a fashion classification AI. Look at a product image and assign "
        "style and occasion tags from controlled vocabularies.\n\n"
        "Rules:\n"
        "- Only return tags from the lists below. Do not invent tags or return synonyms.\n"
        "- An item may have multiple tags or zero tags in either list.\n"
        "- Empty arrays are valid.\n"
        "- Be conservative — if unsure, omit the tag.\n\n"
        f"Style tags (aesthetic / vibe):\n{style_lines}\n\n"
        f"Occasion tags (where/when worn):\n{occasion_lines}"
    )


OUTPUT_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "style_tags": {
            "type": "array",
            "items": {"type": "string", "enum": list(STYLE_TAGS.keys())},
        },
        "occasion_tags": {
            "type": "array",
            "items": {"type": "string", "enum": list(OCCASION_TAGS.keys())},
        },
    },
    "required": ["style_tags", "occasion_tags"],
}


def build_user_text(item: CatalogItem) -> str:
    parts = []
    if item.category:
        parts.append(f"category: {item.category}")
    if item.name:
        parts.append(f"name: {item.name}")
    return "Tag this item." if not parts else "Tag this item. Context: " + ", ".join(parts)


# ---------------------------------------------------------------------------
# Image fetching
# ---------------------------------------------------------------------------

async def fetch_image(http: httpx.AsyncClient, url: str) -> tuple[bytes, str]:
    """Download an image and return (bytes, mime_type)."""
    resp = await http.get(url, timeout=IMAGE_FETCH_TIMEOUT_S)
    resp.raise_for_status()
    mime = resp.headers.get("content-type", "image/jpeg").split(";")[0].strip().lower()
    if mime not in SUPPORTED_IMAGE_MIMES:
        # Fall back to JPEG; Gemini accepts mismatched headers for common formats.
        mime = "image/jpeg"
    return resp.content, mime


# ---------------------------------------------------------------------------
# Tagging worker
# ---------------------------------------------------------------------------

async def tag_one(
    gemini: genai.Client,
    http: httpx.AsyncClient,
    item: CatalogItem,
    system_instruction: str,
    model: str,
    semaphore: asyncio.Semaphore,
) -> tuple[CatalogItem, dict[str, Any] | None, str | None]:
    """Returns (item, result_or_none, error_or_none)."""
    async with semaphore:
        try:
            image_bytes, mime = await fetch_image(http, item.image_front_url)
        except Exception as exc:
            return item, None, f"image_fetch: {exc}"

        try:
            response = await gemini.aio.models.generate_content(
                model=model,
                contents=[
                    types.Part.from_bytes(data=image_bytes, mime_type=mime),
                    build_user_text(item),
                ],
                config=types.GenerateContentConfig(
                    system_instruction=system_instruction,
                    max_output_tokens=MAX_OUTPUT_TOKENS,
                    response_mime_type="application/json",
                    response_schema=OUTPUT_SCHEMA,
                ),
            )
        except Exception as exc:
            return item, None, f"api_error: {exc}"

        # Gemini's JSON mode returns the parsed object on `response.text`.
        text = getattr(response, "text", None)
        if not text:
            return item, None, "empty_response"
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError as exc:
            return item, None, f"json_parse: {exc}"

        # Defense-in-depth — schema enforces the allowlist, but validate anyway.
        style = [t for t in parsed.get("style_tags", []) if t in STYLE_TAGS]
        occasion = [t for t in parsed.get("occasion_tags", []) if t in OCCASION_TAGS]

        usage = getattr(response, "usage_metadata", None)
        return item, {
            "style_tags": style,
            "occasion_tags": occasion,
            "input_tokens": getattr(usage, "prompt_token_count", 0) or 0,
            "output_tokens": getattr(usage, "candidates_token_count", 0) or 0,
        }, None


# ---------------------------------------------------------------------------
# DB layer
# ---------------------------------------------------------------------------

def _ensure_occasion_tags_column() -> None:
    """Fail fast if the migration that adds occasion_tags hasn't run."""
    if not hasattr(CatalogItem, "occasion_tags"):
        raise SystemExit(
            "CatalogItem.occasion_tags is not defined on the model. "
            "Run the schema migration that adds the occasion_tags column "
            "before invoking this script."
        )


def _async_database_url() -> str:
    from app.config import settings  # imported lazily so script runs in dry-import contexts
    url = settings.DATABASE_URL
    return url.replace("postgresql://", "postgresql+asyncpg://", 1) if url.startswith("postgresql://") else url


def _resolve_api_key() -> str:
    key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not key:
        raise SystemExit(
            "Set GEMINI_API_KEY (or GOOGLE_API_KEY) in the environment "
            "before invoking this script."
        )
    return key


async def fetch_items(
    db: AsyncSession,
    *,
    brand: str | None,
    limit: int | None,
    sample: int | None,
    retag_all: bool,
) -> list[CatalogItem]:
    query = select(CatalogItem)
    if brand:
        query = query.where(CatalogItem.brand == brand)
    if not retag_all:
        query = query.where(
            (CatalogItem.occasion_tags.is_(None)) | (func.cardinality(CatalogItem.occasion_tags) == 0)
        )
    if sample:
        query = query.order_by(func.random()).limit(sample)
    elif limit:
        query = query.limit(limit)
    result = await db.execute(query)
    return list(result.scalars().all())


async def write_tags(db: AsyncSession, item_id: Any, style: list[str], occasion: list[str]) -> None:
    await db.execute(
        update(CatalogItem)
        .where(CatalogItem.id == item_id)
        .values(style_tags=style, occasion_tags=occasion)
    )


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

async def run(args: argparse.Namespace) -> int:
    _ensure_occasion_tags_column()
    api_key = _resolve_api_key()

    gemini = genai.Client(api_key=api_key)
    system_instruction = build_system_instruction()
    semaphore = asyncio.Semaphore(args.concurrency)

    engine = create_async_engine(_async_database_url(), pool_pre_ping=True)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as db:
        items = await fetch_items(
            db,
            brand=args.brand,
            limit=args.limit,
            sample=args.sample,
            retag_all=args.retag_all,
        )

    if not items:
        logger.info("No items to tag (already-tagged items skipped; pass --retag-all to override)")
        await engine.dispose()
        return 0

    logger.info(
        "Tagging %d items (model=%s, concurrency=%d, dry_run=%s)",
        len(items), args.model, args.concurrency, args.dry_run,
    )

    start = time.monotonic()
    successes = 0
    failures: list[tuple[str, str]] = []
    total_in = 0
    total_out = 0

    async with httpx.AsyncClient(follow_redirects=True) as http:
        tasks = [
            tag_one(gemini, http, it, system_instruction, args.model, semaphore)
            for it in items
        ]

        async with async_session() as write_db:
            completed = 0
            for done in asyncio.as_completed(tasks):
                item, result, error = await done
                completed += 1

                if error or result is None:
                    failures.append((str(item.id), error or "no_result"))
                else:
                    successes += 1
                    total_in += result["input_tokens"]
                    total_out += result["output_tokens"]
                    logger.debug(
                        "[%s] %s → style=%s occasion=%s",
                        item.id, item.name[:30], result["style_tags"], result["occasion_tags"],
                    )
                    if not args.dry_run:
                        try:
                            await write_tags(
                                write_db, item.id, result["style_tags"], result["occasion_tags"]
                            )
                            if successes % args.batch_commit == 0:
                                await write_db.commit()
                        except Exception as exc:
                            logger.exception("DB write failed for %s", item.id)
                            failures.append((str(item.id), f"db_write: {exc}"))

                if completed % PROGRESS_REPORT_EVERY == 0:
                    elapsed = time.monotonic() - start
                    rate = completed / elapsed if elapsed else 0
                    logger.info(
                        "Progress: %d/%d (%.1f items/s, %.1fs elapsed)",
                        completed, len(items), rate, elapsed,
                    )

            if not args.dry_run:
                await write_db.commit()

    elapsed = time.monotonic() - start
    cost = (
        total_in * INPUT_PRICE_PER_M / 1_000_000
        + total_out * OUTPUT_PRICE_PER_M / 1_000_000
    )

    logger.info(
        "Done in %.1fs: %d tagged, %d failed (≈$%.4f, in=%d out=%d tokens)",
        elapsed, successes, len(failures), cost, total_in, total_out,
    )
    if failures:
        logger.warning("First 10 failures:")
        for item_id, reason in failures[:10]:
            logger.warning("  %s: %s", item_id, reason)

    await engine.dispose()
    return 0 if not failures else 2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--brand", type=str, default=None, help="Filter to one brand")
    parser.add_argument("--limit", type=int, default=None, help="Max items to process")
    parser.add_argument("--sample", type=int, default=None, help="Random sample size for testing")
    parser.add_argument("--concurrency", type=int, default=DEFAULT_CONCURRENCY)
    parser.add_argument("--model", type=str, default=DEFAULT_MODEL)
    parser.add_argument("--dry-run", action="store_true", help="Don't write tags to DB")
    parser.add_argument("--retag-all", action="store_true", help="Re-tag items even if occasion_tags is non-empty")
    parser.add_argument("--batch-commit", type=int, default=20, help="Commit every N successful writes")
    parser.add_argument("--verbose", "-v", action="count", default=0)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%H:%M:%S",
    )
    sys.exit(asyncio.run(run(args)))


if __name__ == "__main__":
    main()
