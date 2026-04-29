#!/usr/bin/env python3
"""Tag catalog items with attributes derived from their front image.

Reads a categorized taxonomy JSON (`{axis: [allowed_values, ...]}`), calls a
vision-capable OpenAI-compatible chat model with each item's image, and writes
the returned tags back to catalog_items columns. Tags are constrained at the
API level via OpenAI structured outputs (`response_format=json_schema`,
`strict=true`) AND re-validated client-side. Unknown values are dropped.

Default scope: rows where style_tags is NULL or empty (resumable).

Examples:
    # dry-run, mango only, 5 items
    python scripts/tag_catalog_items.py --brand mango --limit 5 --dry-run

    # actual run with concurrency
    python scripts/tag_catalog_items.py --brand mango --concurrency 4

Configuration (set later, when proxy is provisioned):
    STYLE_TAGGING_PROXY_URL  OpenAI-compatible base URL (e.g. https://my-proxy/v1)
    STYLE_TAGGING_API_KEY    Bearer token
    STYLE_TAGGING_MODEL      Vision-capable model name (default: gpt-4o-mini)
"""
from __future__ import annotations

import argparse
import asyncio
import base64
import json
import logging
import os
import sys
from pathlib import Path
from urllib.parse import urlparse

PROJECT_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ROOT = PROJECT_ROOT / "backend"
DEFAULT_TAGS_JSON = PROJECT_ROOT / "style_tags.json"


# Mapping: which JSON axis updates which dedicated DB column.
# Axes not listed here land in style_tags as "axis:value" pairs (preserves
# axis context without requiring a schema migration for material / occasion /
# season / etc.).
COLUMN_AXIS_MAPPING: dict[str, dict] = {
    "color":    {"column": "color",    "multi": True,  "skip_if_present": False},
    "pattern":  {"column": "pattern",  "multi": False, "skip_if_present": False},
    "fit":      {"column": "fit",      "multi": False, "skip_if_present": True},
    "category": {"column": "category", "multi": False, "skip_if_present": True},
    "subtype":  {"column": "subtype",  "multi": False, "skip_if_present": True},
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--tags-json", type=Path, default=DEFAULT_TAGS_JSON,
        help=f"Path to taxonomy JSON. Default: {DEFAULT_TAGS_JSON}",
    )
    parser.add_argument(
        "--proxy-url", default=os.getenv("STYLE_TAGGING_PROXY_URL"),
        help="OpenAI-compatible base URL. Env: STYLE_TAGGING_PROXY_URL",
    )
    parser.add_argument(
        "--api-key", default=os.getenv("STYLE_TAGGING_API_KEY"),
        help="Bearer API key. Env: STYLE_TAGGING_API_KEY",
    )
    parser.add_argument(
        "--model", default=os.getenv("STYLE_TAGGING_MODEL", "gpt-4o-mini"),
        help="Vision-capable model name. Default: gpt-4o-mini",
    )
    parser.add_argument(
        "--brand", action="append", default=None,
        help="Restrict to brand(s). Repeatable. Default: all brands.",
    )
    parser.add_argument("--limit", type=int, default=0, help="Process at most N rows.")
    parser.add_argument("--concurrency", type=int, default=4)
    parser.add_argument("--commit-every", type=int, default=50)
    parser.add_argument("--max-per-axis", type=int, default=2)
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print intended changes without writing to the DB.",
    )
    parser.add_argument("--http-timeout", type=float, default=60.0)
    return parser.parse_args()


def load_taxonomy(path: Path) -> dict[str, list[str]]:
    if not path.exists() or path.stat().st_size == 0:
        raise SystemExit(f"Taxonomy file is empty or missing: {path}")
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise SystemExit("Taxonomy JSON must be an object: {axis: [values]}")
    cleaned: dict[str, list[str]] = {}
    for axis, values in data.items():
        if not isinstance(values, list) or not all(isinstance(v, str) for v in values):
            raise SystemExit(f"Taxonomy axis {axis!r} must be a list of strings.")
        if not values:
            raise SystemExit(f"Taxonomy axis {axis!r} has zero allowed values.")
        cleaned[axis] = values
    return cleaned


def build_response_schema(taxonomy: dict[str, list[str]], max_per_axis: int) -> dict:
    properties = {
        axis: {
            "type": "array",
            "items": {"type": "string", "enum": list(values)},
            "maxItems": max_per_axis,
        }
        for axis, values in taxonomy.items()
    }
    return {
        "type": "object",
        "properties": properties,
        "required": list(taxonomy.keys()),
        "additionalProperties": False,
    }


def build_system_prompt(taxonomy: dict[str, list[str]], max_per_axis: int) -> str:
    lines = [
        "You are a fashion catalog tagger. Examine the garment image and assign tags.",
        "",
        f"Pick AT MOST {max_per_axis} tags per category — fewer is better.",
        "Use ONLY the values from the taxonomy below. Never invent, paraphrase, or",
        "translate values. If nothing in a category clearly applies, return [].",
        "Be conservative: only return a tag when you are confident.",
        "",
        "Allowed taxonomy:",
    ]
    for axis, values in taxonomy.items():
        lines.append(f"  {axis}: {', '.join(values)}")
    return "\n".join(lines)


def url_to_key(url: str) -> str:
    return urlparse(url).path.lstrip("/")


async def fetch_image_bytes(httpx_client, url: str) -> bytes:
    """Prefer direct R2 download for catalog/ keys, fallback to HTTP fetch."""
    from app.services.storage_service import StorageError, download_bytes

    if "/catalog/" in url:
        try:
            return await asyncio.to_thread(download_bytes, url_to_key(url))
        except StorageError:
            pass  # fall through to HTTP
    response = await httpx_client.get(url)
    response.raise_for_status()
    return response.content


def validate_response(response: dict, taxonomy: dict[str, list[str]]) -> dict[str, list[str]]:
    """Drop values not in the allowed enum (defense in depth on top of strict mode)."""
    cleaned: dict[str, list[str]] = {}
    for axis, allowed in taxonomy.items():
        raw = response.get(axis, []) or []
        if not isinstance(raw, list):
            raw = []
        allowed_set = set(allowed)
        cleaned[axis] = [v for v in raw if isinstance(v, str) and v in allowed_set]
    return cleaned


async def call_vision_api(
    httpx_client,
    proxy_url: str,
    api_key: str,
    model: str,
    system_prompt: str,
    image_bytes: bytes,
    response_schema: dict,
) -> dict:
    image_b64 = base64.b64encode(image_bytes).decode()
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "Tag this garment per the taxonomy."},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/png;base64,{image_b64}"},
                    },
                ],
            },
        ],
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "garment_tags",
                "strict": True,
                "schema": response_schema,
            },
        },
        "temperature": 0.1,
    }
    url = proxy_url.rstrip("/") + "/chat/completions"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    response = await httpx_client.post(url, json=payload, headers=headers)
    response.raise_for_status()
    body = response.json()
    return json.loads(body["choices"][0]["message"]["content"])


def apply_tags_to_item(item, validated: dict[str, list[str]]) -> dict[str, object]:
    """Mutate the row with validated tags. Return a {column: new_value} diff for logging."""
    changes: dict[str, object] = {}
    flat_extras: list[str] = []

    for axis, values in validated.items():
        if not values:
            continue
        mapping = COLUMN_AXIS_MAPPING.get(axis)
        if mapping is None:
            flat_extras.extend(f"{axis}:{v}" for v in values)
            continue
        column = mapping["column"]
        if mapping.get("skip_if_present") and getattr(item, column):
            continue
        if mapping["multi"]:
            new_value: object = list(values)
        else:
            new_value = values[0]
        setattr(item, column, new_value)
        changes[column] = new_value

    if flat_extras:
        existing = list(getattr(item, "style_tags") or [])
        merged = sorted({*existing, *flat_extras})
        item.style_tags = merged
        changes["style_tags"] = merged

    return changes


async def process_row(
    row,
    semaphore: asyncio.Semaphore,
    httpx_client,
    proxy_url: str,
    api_key: str,
    model: str,
    system_prompt: str,
    response_schema: dict,
    taxonomy: dict[str, list[str]],
    log: logging.Logger,
) -> dict[str, list[str]] | None:
    async with semaphore:
        try:
            image_bytes = await fetch_image_bytes(httpx_client, row.image_front_url)
        except Exception as exc:  # noqa: BLE001
            log.warning("FETCH_FAIL %s %s: %s", row.brand, row.ref_code, exc)
            return None
        try:
            ai_response = await call_vision_api(
                httpx_client,
                proxy_url,
                api_key,
                model,
                system_prompt,
                image_bytes,
                response_schema,
            )
        except Exception as exc:  # noqa: BLE001
            log.warning("API_FAIL %s %s: %s", row.brand, row.ref_code, exc)
            return None
        return validate_response(ai_response, taxonomy)


async def run() -> None:
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    log = logging.getLogger("tag_catalog")

    if not args.proxy_url:
        raise SystemExit("Missing proxy URL. Pass --proxy-url or set STYLE_TAGGING_PROXY_URL.")
    if not args.api_key:
        raise SystemExit("Missing API key. Pass --api-key or set STYLE_TAGGING_API_KEY.")

    taxonomy = load_taxonomy(args.tags_json)
    response_schema = build_response_schema(taxonomy, args.max_per_axis)
    system_prompt = build_system_prompt(taxonomy, args.max_per_axis)
    log.info(
        "taxonomy: %d axes, %d total values",
        len(taxonomy),
        sum(len(v) for v in taxonomy.values()),
    )

    os.chdir(BACKEND_ROOT)
    if str(BACKEND_ROOT) not in sys.path:
        sys.path.insert(0, str(BACKEND_ROOT))

    import httpx
    from sqlalchemy import func, or_, select

    from app.database import AsyncSessionLocal
    from app.models.catalog import CatalogItem

    semaphore = asyncio.Semaphore(args.concurrency)
    session = AsyncSessionLocal()
    httpx_client = httpx.AsyncClient(timeout=args.http_timeout)
    try:
        query = select(CatalogItem).where(
            or_(
                CatalogItem.style_tags.is_(None),
                func.cardinality(CatalogItem.style_tags) == 0,
            )
        )
        if args.brand:
            query = query.where(CatalogItem.brand.in_(args.brand))
        if args.limit:
            query = query.limit(args.limit)

        rows = (await session.execute(query)).scalars().all()
        log.info("rows to process: %d", len(rows))

        async def task(row):
            validated = await process_row(
                row,
                semaphore,
                httpx_client,
                args.proxy_url,
                args.api_key,
                args.model,
                system_prompt,
                response_schema,
                taxonomy,
                log,
            )
            return row, validated

        tagged = 0
        failed = 0
        for index, future in enumerate(asyncio.as_completed([task(r) for r in rows]), start=1):
            row, validated = await future
            if validated is None:
                failed += 1
                continue
            changes = apply_tags_to_item(row, validated)
            if changes:
                tagged += 1
                if args.dry_run:
                    log.info(
                        "DRY %s/%s validated=%s changes=%s",
                        row.brand, row.ref_code, validated, changes,
                    )
            if not args.dry_run and index % args.commit_every == 0:
                await session.commit()
                log.info(
                    "commit %d/%d (tagged=%d, failed=%d)",
                    index, len(rows), tagged, failed,
                )

        if args.dry_run:
            await session.rollback()
        else:
            await session.commit()
        log.info("done: tagged=%d failed=%d total=%d", tagged, failed, len(rows))
    finally:
        await httpx_client.aclose()
        await session.close()


if __name__ == "__main__":
    asyncio.run(run())
