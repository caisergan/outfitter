#!/usr/bin/env python3
"""Backfill ``clip_embedding`` for catalog rows where it is NULL.

Resumable: every run only processes rows that still lack an embedding, so it is
safe to invoke repeatedly after partial failures.

Usage:
    python scripts/backfill_catalog_embeddings.py
    python scripts/backfill_catalog_embeddings.py --brand mango --limit 100
    python scripts/backfill_catalog_embeddings.py --concurrency 8 --commit-every 50

Run from the backend root with the project venv active so the FastAPI app
modules and the CLIP weight cache are reachable.
"""
from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path
from urllib.parse import urlparse

PROJECT_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ROOT = PROJECT_ROOT / "backend"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compute and persist CLIP embeddings for catalog rows missing them.",
    )
    parser.add_argument(
        "--brand",
        default=None,
        help="Limit backfill to a single brand (default: all brands)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Process at most N rows in this run (default: unlimited)",
    )
    parser.add_argument(
        "--concurrency",
        type=int,
        default=4,
        help="Max in-flight image fetches (CLIP encode itself runs on a thread pool)",
    )
    parser.add_argument(
        "--commit-every",
        type=int,
        default=50,
        help="Commit DB updates every N processed rows",
    )
    parser.add_argument(
        "--http-timeout",
        type=float,
        default=10.0,
        help="HTTP timeout (seconds) when fetching public image URLs",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Count missing rows and exit without computing embeddings",
    )
    return parser.parse_args()


async def _fetch_image_bytes(image_front_url: str, http_timeout: float) -> bytes | None:
    """Pull bytes via direct R2 download when the URL maps to a project key.

    Falls back to httpx GET for arbitrary public URLs.
    """
    import httpx

    from app.services.storage_service import download_bytes

    try:
        path = urlparse(image_front_url).path.lstrip("/")
        if "catalog/" in path:
            return await asyncio.to_thread(download_bytes, path)

        async with httpx.AsyncClient(timeout=http_timeout) as client:
            response = await client.get(image_front_url)
            response.raise_for_status()
            return response.content
    except Exception as exc:  # noqa: BLE001
        print(f"  WARN fetch failed for {image_front_url}: {exc}")
        return None


async def _process_row(
    semaphore: asyncio.Semaphore,
    item_id,
    image_front_url: str,
    http_timeout: float,
) -> tuple[object, list[float] | None]:
    from app.services.clip_service import embed_image_async

    async with semaphore:
        image_bytes = await _fetch_image_bytes(image_front_url, http_timeout)
        if image_bytes is None:
            return item_id, None
        try:
            embedding = await embed_image_async(image_bytes)
        except Exception as exc:  # noqa: BLE001
            print(f"  WARN embed failed for {image_front_url}: {exc}")
            return item_id, None
        return item_id, embedding


async def run_backfill(
    brand: str | None,
    limit: int,
    concurrency: int,
    commit_every: int,
    http_timeout: float,
    dry_run: bool,
) -> None:
    os.chdir(BACKEND_ROOT)
    if str(BACKEND_ROOT) not in sys.path:
        sys.path.insert(0, str(BACKEND_ROOT))

    from sqlalchemy import func, select

    from app.database import AsyncSessionLocal
    from app.models.catalog import CatalogItem

    session = AsyncSessionLocal()
    try:
        base_query = select(CatalogItem).where(CatalogItem.clip_embedding.is_(None))
        if brand:
            base_query = base_query.where(CatalogItem.brand == brand)

        count_query = select(func.count()).select_from(base_query.subquery())
        total_missing = (await session.execute(count_query)).scalar_one()
        print(f"Rows missing clip_embedding: {total_missing}")
        if dry_run or total_missing == 0:
            return

        load_query = base_query.order_by(CatalogItem.created_at)
        if limit:
            load_query = load_query.limit(limit)

        rows = (await session.execute(load_query)).scalars().all()
        print(f"Processing {len(rows)} rows (concurrency={concurrency})")

        semaphore = asyncio.Semaphore(concurrency)
        tasks = [
            _process_row(semaphore, row.id, row.image_front_url, http_timeout)
            for row in rows
        ]

        embedded = 0
        failed = 0
        items_by_id = {row.id: row for row in rows}

        # Process in completion order so progress is visible early
        for index, coro in enumerate(asyncio.as_completed(tasks), start=1):
            item_id, embedding = await coro
            if embedding is None:
                failed += 1
            else:
                items_by_id[item_id].clip_embedding = embedding
                embedded += 1

            if index % commit_every == 0:
                await session.commit()
                print(f"Committed {index}/{len(rows)} (embedded={embedded}, failed={failed})")

        await session.commit()
        print(f"Backfill complete: embedded={embedded}, failed={failed}, total={len(rows)}")
    finally:
        await session.close()


def main() -> None:
    args = parse_args()
    asyncio.run(
        run_backfill(
            brand=args.brand,
            limit=args.limit,
            concurrency=args.concurrency,
            commit_every=args.commit_every,
            http_timeout=args.http_timeout,
            dry_run=args.dry_run,
        )
    )


if __name__ == "__main__":
    main()
