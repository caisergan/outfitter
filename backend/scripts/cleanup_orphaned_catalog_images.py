#!/usr/bin/env python3
"""Delete S3 objects under catalog/<brand>/ that no catalog_items row references.

Default mode is dry-run — pass --apply to actually delete. The script reads every
catalog_items.image_front_url and image_back_url, extracts the object key from each
URL, lists all keys under catalog/<brand>/ in S3, and deletes the set difference.

Examples:
    python scripts/cleanup_orphaned_catalog_images.py                # dry-run, all brands
    python scripts/cleanup_orphaned_catalog_images.py --brand mango  # dry-run, mango only
    python scripts/cleanup_orphaned_catalog_images.py --brand mango --apply  # delete
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
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--brand",
        action="append",
        default=None,
        help="Restrict to one or more brands (repeatable). Default: every brand present in catalog_items.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually delete. Default is dry-run.",
    )
    parser.add_argument(
        "--limit-print",
        type=int,
        default=20,
        help="How many sample orphan keys to print per brand (default 20).",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=1000,
        help="S3 delete_objects batch size (max 1000).",
    )
    parser.add_argument(
        "--max-deletes",
        type=int,
        default=0,
        help="Cap deletions at the first N orphan keys (0 = no cap). Useful for sanity tests.",
    )
    return parser.parse_args()


def url_to_key(url: str | None) -> str | None:
    """Extract the S3 object key from a public URL.

    Handles virtual-hosted (`<bucket>.s3.<region>.amazonaws.com/<key>`) and
    path-style (`s3.<region>.amazonaws.com/<bucket>/<key>`) URLs by returning
    everything after the first slash. The caller filters by `catalog/<brand>/`
    prefix to ignore non-matches.
    """
    if not url:
        return None
    parsed = urlparse(url)
    return parsed.path.lstrip("/") or None


async def collect_referenced_keys() -> tuple[set[str], list[str]]:
    """Read every catalog_items image URL, return (referenced_keys, brands_seen)."""
    from sqlalchemy import select

    from app.database import AsyncSessionLocal
    from app.models.catalog import CatalogItem

    referenced: set[str] = set()
    brands_seen: set[str] = set()

    session = AsyncSessionLocal()
    try:
        result = await session.execute(
            select(
                CatalogItem.brand,
                CatalogItem.image_front_url,
                CatalogItem.image_back_url,
            )
        )
        for brand, front, back in result.all():
            if brand:
                brands_seen.add(brand)
            for url in (front, back):
                key = url_to_key(url)
                if key:
                    referenced.add(key)
    finally:
        await session.close()

    return referenced, sorted(brands_seen)


def list_keys_under_prefix(s3, bucket: str, prefix: str) -> set[str]:
    keys: set[str] = set()
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            keys.add(obj["Key"])
    return keys


def delete_keys_in_batches(s3, bucket: str, keys: list[str], batch_size: int) -> tuple[int, list[dict]]:
    deleted = 0
    errors: list[dict] = []
    for index in range(0, len(keys), batch_size):
        batch = keys[index : index + batch_size]
        response = s3.delete_objects(
            Bucket=bucket,
            Delete={"Objects": [{"Key": k} for k in batch], "Quiet": True},
        )
        batch_errors = response.get("Errors", []) or []
        errors.extend(batch_errors)
        deleted += len(batch) - len(batch_errors)
        progress = min(index + batch_size, len(keys))
        print(f"  Deleted {progress}/{len(keys)} (errors so far: {len(errors)})")
    return deleted, errors


async def run() -> int:
    args = parse_args()

    os.chdir(BACKEND_ROOT)
    if str(BACKEND_ROOT) not in sys.path:
        sys.path.insert(0, str(BACKEND_ROOT))

    from app.services.storage_service import _get_client, settings

    referenced, brands_seen = await collect_referenced_keys()
    target_brands = args.brand or brands_seen

    print(f"Brands in catalog_items: {brands_seen}")
    print(f"Target brands:           {target_brands}")
    print(f"Total referenced keys across all brands: {len(referenced)}")

    if not target_brands:
        print("No brands to process — aborting.")
        return 0

    s3 = _get_client()
    bucket = settings.R2_BUCKET

    grand_orphans: list[str] = []
    for brand in target_brands:
        prefix = f"catalog/{brand}/"
        listed = list_keys_under_prefix(s3, bucket, prefix)
        referenced_in_prefix = {k for k in referenced if k.startswith(prefix)}
        orphans = sorted(listed - referenced_in_prefix)
        kept = listed & referenced_in_prefix

        print()
        print(
            f"[{brand}] listed={len(listed)} "
            f"referenced={len(referenced_in_prefix)} kept={len(kept)} "
            f"orphans={len(orphans)}"
        )
        for sample in orphans[: args.limit_print]:
            print(f"  ORPHAN: {sample}")
        if len(orphans) > args.limit_print:
            print(f"  ... and {len(orphans) - args.limit_print} more")
        grand_orphans.extend(orphans)

    print()
    print(f"TOTAL ORPHAN KEYS: {len(grand_orphans)}")

    if args.max_deletes and args.max_deletes < len(grand_orphans):
        grand_orphans = grand_orphans[: args.max_deletes]
        print(f"Capped to first {len(grand_orphans)} via --max-deletes.")

    if not args.apply:
        print("DRY-RUN — pass --apply to delete.")
        return 0

    if not grand_orphans:
        print("Nothing to delete.")
        return 0

    print(f"Deleting {len(grand_orphans)} keys in batches of {args.batch_size}...")
    deleted, errors = delete_keys_in_batches(s3, bucket, grand_orphans, args.batch_size)
    print(f"Done. Deleted {deleted}/{len(grand_orphans)} objects.")
    if errors:
        print(f"Encountered {len(errors)} delete errors:")
        for err in errors[:10]:
            print(f"  {err.get('Key')}: {err.get('Code')} {err.get('Message')}")
        return 1
    return 0


def main() -> None:
    sys.exit(asyncio.run(run()))


if __name__ == "__main__":
    main()
