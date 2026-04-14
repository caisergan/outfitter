#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import mimetypes
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
from urllib.parse import parse_qs, urlparse


PROJECT_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ROOT = PROJECT_ROOT / "backend"


CANONICAL_CATEGORY_MAP = {
    "sweaters-and-cardigans": "top",
    "jackets": "outerwear",
    "pants": "bottom",
    "jeans": "bottom",
    "blazers": "outerwear",
    "shirts": "top",
    "coats": "outerwear",
    "sweatshirts": "top",
    "overshirts": "top",
    "t-shirts": "top",
    "trench-coats": "outerwear",
    "polos": "top",
    "swimwear": "swimwear",
    "underwear": "underwear",
    "pajamas": "underwear",
    "linen": "top",
    "dresses-and-jumpsuits": "dress",
    "shirts---blouses": "top",
    "skirts": "bottom",
    "tops": "top",
    "trench-coats-and-parkas": "outerwear",
    "leather": "outerwear",
    "vests": "outerwear",
    "bikinis-and-swimsuits": "swimwear",
}

FIT_PATTERNS = [
    re.compile(r"\b(regular fit)\b", re.IGNORECASE),
    re.compile(r"\b(slim fit)\b", re.IGNORECASE),
    re.compile(r"\b(relaxed fit)\b", re.IGNORECASE),
    re.compile(r"\b(oversized)\b", re.IGNORECASE),
    re.compile(r"\b(straight design)\b", re.IGNORECASE),
    re.compile(r"\b(straight fit)\b", re.IGNORECASE),
    re.compile(r"\b(wide[- ]leg)\b", re.IGNORECASE),
    re.compile(r"\b(flared)\b", re.IGNORECASE),
    re.compile(r"\b(skinny fit)\b", re.IGNORECASE),
]


@dataclass(frozen=True)
class RawMangoRecord:
    gender: str
    source_category: str
    product_url: str
    ref_code: str
    color: str | None
    description: str | None
    images: list[str]


@dataclass(frozen=True)
class PreparedCatalogRow:
    ref_code: str
    original_ref_code: str
    gender: str
    source_category: str
    category: str
    subtype: str | None
    name: str
    color: list[str] | None
    fit: str | None
    image_path: Path
    product_url: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Upload the local Mango catalog export to AWS S3 and upsert it into catalog_items.",
    )
    parser.add_argument(
        "--json",
        type=Path,
        default=PROJECT_ROOT / "output/mango/mango_products.json",
        help="Path to mango_products.json",
    )
    parser.add_argument(
        "--images-root",
        type=Path,
        default=PROJECT_ROOT / "output/mango/images",
        help="Root directory containing the local Mango product images",
    )
    parser.add_argument(
        "--brand",
        default="mango",
        help="Brand slug/value to persist in catalog_items.brand",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Only process the first N prepared rows",
    )
    parser.add_argument(
        "--commit-every",
        type=int,
        default=100,
        help="Commit database work every N rows",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview the prepared rows without touching S3 or the database",
    )
    parser.add_argument(
        "--backfill-gender-only",
        action="store_true",
        help="Skip S3 uploads and only update existing catalog_items.gender values for matching Mango rows",
    )
    return parser.parse_args()


def clean_product_url(url: str) -> str:
    return url.rstrip("\\").strip()


def extract_color_code(product_url: str) -> str:
    query = parse_qs(urlparse(product_url).query)
    return query.get("c", [""])[0].strip()


def slug_to_words(slug: str) -> str:
    cleaned = slug.replace("_", "-")
    parts = [part for part in cleaned.split("-") if part]
    return " ".join(parts)


def titleize(text: str) -> str:
    return " ".join(word.capitalize() for word in text.split())


def derive_name(record: RawMangoRecord) -> str:
    parsed = urlparse(record.product_url)
    last_segment = parsed.path.rstrip("/").split("/")[-1]
    name_slug = last_segment.rsplit("_", 1)[0]
    return titleize(slug_to_words(name_slug))


def derive_subtype(record: RawMangoRecord) -> str | None:
    path_parts = [part for part in urlparse(record.product_url).path.split("/") if part]
    if len(path_parts) >= 2:
        subtype = titleize(slug_to_words(path_parts[-2]))
        return subtype or None
    subtype = titleize(slug_to_words(record.source_category))
    return subtype or None


def derive_fit(description: str | None) -> str | None:
    if not description:
        return None
    for pattern in FIT_PATTERNS:
        match = pattern.search(description)
        if match:
            return match.group(1).lower().replace("-", " ")
    return None


def canonical_category(source_category: str) -> str:
    mapped = CANONICAL_CATEGORY_MAP.get(source_category)
    if not mapped:
        raise ValueError(f"No canonical category mapping for source category '{source_category}'")
    return mapped


def pick_preferred_image(matches: Iterable[Path], color_code: str) -> Path | None:
    unique = sorted({path for path in matches})
    if color_code:
        filtered = [path for path in unique if f"_{color_code}_" in path.name]
        if filtered:
            unique = filtered
    if not unique:
        return None

    def rank(path: Path) -> tuple[int, str]:
        name = path.name
        if "_B." in name:
            return (0, name)
        if "_R." in name:
            return (1, name)
        return (2, name)

    return sorted(unique, key=rank)[0]


def find_image_path(record: RawMangoRecord, images_root: Path) -> Path | None:
    color_code = extract_color_code(record.product_url)
    expected_dir = images_root / record.gender / record.source_category
    local_matches = list(expected_dir.glob(f"{record.ref_code}*"))
    chosen = pick_preferred_image(local_matches, color_code)
    if chosen:
        return chosen

    fallback_matches = images_root.rglob(f"{record.ref_code}*")
    return pick_preferred_image(fallback_matches, color_code)


def load_raw_records(json_path: Path) -> list[RawMangoRecord]:
    data = json.loads(json_path.read_text())
    rows: list[RawMangoRecord] = []
    for gender, categories in data.items():
        if not isinstance(categories, dict):
            continue
        for source_category, items in categories.items():
            if not isinstance(items, list):
                continue
            for item in items:
                rows.append(
                    RawMangoRecord(
                        gender=gender,
                        source_category=source_category,
                        product_url=clean_product_url(item["product_url"]),
                        ref_code=str(item["ref_code"]).strip(),
                        color=item.get("color"),
                        description=item.get("description"),
                        images=list(item.get("images", [])),
                    )
                )
    return rows


def dedupe_records(records: list[RawMangoRecord], images_root: Path) -> list[RawMangoRecord]:
    grouped: dict[str, list[RawMangoRecord]] = {}
    for record in records:
        grouped.setdefault(record.product_url, []).append(record)

    chosen: list[RawMangoRecord] = []
    for product_url, variants in grouped.items():
        best = None
        for record in variants:
            image_path = find_image_path(record, images_root)
            if image_path is not None:
                best = record
                break
            if best is None:
                best = record
        if best is None:
            raise RuntimeError(f"Unexpected empty variant group for {product_url}")
        chosen.append(best)

    chosen.sort(key=lambda record: record.product_url)
    return chosen


def build_unique_ref_code(record: RawMangoRecord, seen: set[str]) -> str:
    color_code = extract_color_code(record.product_url)
    candidate = record.ref_code if not color_code else f"{record.ref_code}-{color_code}"
    if candidate not in seen:
        seen.add(candidate)
        return candidate

    digest = hashlib.sha1(record.product_url.encode("utf-8")).hexdigest()[:8]
    unique = f"{candidate}-{digest}"
    seen.add(unique)
    return unique


def prepare_rows(records: list[RawMangoRecord], images_root: Path) -> tuple[list[PreparedCatalogRow], list[str]]:
    prepared: list[PreparedCatalogRow] = []
    missing_images: list[str] = []
    seen_ref_codes: set[str] = set()

    for record in records:
        image_path = find_image_path(record, images_root)
        if image_path is None:
            missing_images.append(record.product_url)
            continue

        prepared.append(
            PreparedCatalogRow(
                ref_code=build_unique_ref_code(record, seen_ref_codes),
                original_ref_code=record.ref_code,
                gender=record.gender,
                source_category=record.source_category,
                category=canonical_category(record.source_category),
                subtype=derive_subtype(record),
                name=derive_name(record),
                color=[record.color.strip()] if record.color else None,
                fit=derive_fit(record.description),
                image_path=image_path,
                product_url=record.product_url,
            )
        )

    return prepared, missing_images


def print_preview(rows: list[PreparedCatalogRow], missing_images: list[str], limit: int) -> None:
    preview_rows = rows[:limit] if limit else rows[:10]
    print(f"Prepared rows: {len(rows)}")
    print(f"Missing images: {len(missing_images)}")
    for row in preview_rows:
        print(
            json.dumps(
                {
                    "ref_code": row.ref_code,
                    "original_ref_code": row.original_ref_code,
                    "gender": row.gender,
                    "source_category": row.source_category,
                    "category": row.category,
                    "subtype": row.subtype,
                    "name": row.name,
                    "color": row.color,
                    "fit": row.fit,
                    "image_path": str(row.image_path),
                    "product_url": row.product_url,
                },
                ensure_ascii=True,
            )
        )
    if missing_images:
        print("Missing image examples:")
        for url in missing_images[:10]:
            print(f"  - {url}")


async def run_import(rows: list[PreparedCatalogRow], brand: str, commit_every: int) -> None:
    os.chdir(BACKEND_ROOT)
    if str(BACKEND_ROOT) not in sys.path:
        sys.path.insert(0, str(BACKEND_ROOT))

    from sqlalchemy import select

    from app.database import AsyncSessionLocal
    from app.models.catalog import CatalogItem
    from app.services.storage_service import _build_public_url, _get_client, settings

    session = AsyncSessionLocal()
    s3 = _get_client()

    try:
        result = await session.execute(select(CatalogItem).where(CatalogItem.brand == brand))
        existing_by_ref = {item.ref_code: item for item in result.scalars() if item.ref_code}

        created = 0
        updated = 0

        for index, row in enumerate(rows, start=1):
            content_type = mimetypes.guess_type(row.image_path.name)[0] or "image/jpeg"
            key = f"catalog/{brand}/{row.ref_code}{row.image_path.suffix.lower()}"

            s3.upload_file(
                str(row.image_path),
                settings.R2_BUCKET,
                key,
                ExtraArgs={"ContentType": content_type},
            )
            image_url = _build_public_url(key)

            item = existing_by_ref.get(row.ref_code)
            if item is None:
                item = CatalogItem(
                    ref_code=row.ref_code,
                    brand=brand,
                    gender=row.gender,
                    category=row.category,
                    subtype=row.subtype,
                    name=row.name,
                    color=row.color,
                    fit=row.fit,
                    image_url=image_url,
                    product_url=row.product_url,
                )
                session.add(item)
                existing_by_ref[row.ref_code] = item
                created += 1
            else:
                item.gender = row.gender
                item.category = row.category
                item.subtype = row.subtype
                item.name = row.name
                item.color = row.color
                item.fit = row.fit
                item.image_url = image_url
                item.product_url = row.product_url
                updated += 1

            if index % commit_every == 0:
                await session.commit()
                print(f"Committed {index}/{len(rows)} rows (created={created}, updated={updated})")

        await session.commit()
        print(f"Import complete: created={created}, updated={updated}, total={len(rows)}")
    finally:
        await session.close()


async def run_gender_backfill(rows: list[PreparedCatalogRow], brand: str, commit_every: int) -> None:
    os.chdir(BACKEND_ROOT)
    if str(BACKEND_ROOT) not in sys.path:
        sys.path.insert(0, str(BACKEND_ROOT))

    from sqlalchemy import select

    from app.database import AsyncSessionLocal
    from app.models.catalog import CatalogItem

    session = AsyncSessionLocal()
    try:
        result = await session.execute(select(CatalogItem).where(CatalogItem.brand == brand))
        existing_by_ref = {item.ref_code: item for item in result.scalars() if item.ref_code}

        touched = 0
        missing = 0

        for index, row in enumerate(rows, start=1):
            item = existing_by_ref.get(row.ref_code)
            if item is None:
                missing += 1
                continue
            if item.gender != row.gender:
                item.gender = row.gender
                touched += 1

            if index % commit_every == 0:
                await session.commit()
                print(
                    f"Backfill progress {index}/{len(rows)} rows "
                    f"(updated={touched}, missing={missing})"
                )

        await session.commit()
        print(f"Gender backfill complete: updated={touched}, missing={missing}, total={len(rows)}")
    finally:
        await session.close()


def main() -> None:
    args = parse_args()
    raw_rows = load_raw_records(args.json)
    deduped_rows = dedupe_records(raw_rows, args.images_root)
    prepared_rows, missing_images = prepare_rows(deduped_rows, args.images_root)

    if args.limit:
        prepared_rows = prepared_rows[: args.limit]

    print_preview(prepared_rows, missing_images, args.limit)

    if args.dry_run:
        return

    if args.backfill_gender_only:
        asyncio.run(run_gender_backfill(prepared_rows, args.brand, args.commit_every))
        return

    asyncio.run(run_import(prepared_rows, args.brand, args.commit_every))


if __name__ == "__main__":
    main()
