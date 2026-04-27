#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import json
import mimetypes
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ROOT = PROJECT_ROOT / "backend"

CANONICAL_CATEGORY_MAP = {
    "t-shirts": "top",
    "jeans": "bottom",
    "trousers": "bottom",
    "baggy-trousers": "bottom",
    "shorts": "bottom",
    "jackets": "outerwear",
    "jackets-and-coats": "outerwear",
    "shirts": "top",
    "shirts-and-blouses": "top",
    "sweaters-and-cardigans": "top",
    "sweatshirts-and-hoodies": "top",
    "tops-and-bodies": "top",
    "dresses": "dress",
    "skirts-and-shorts": "bottom",
    "shoes": "footwear",
    "accessories": "accessory",
    "bags": "bag",
    "bikinis-and-swimsuits": "swimwear",
    "tracksuit": "activewear",
}

FIT_PATTERNS = [
    re.compile(r"\b(regular fit)\b", re.IGNORECASE),
    re.compile(r"\b(slim fit)\b", re.IGNORECASE),
    re.compile(r"\b(relaxed fit)\b", re.IGNORECASE),
    re.compile(r"\b(oversized)\b", re.IGNORECASE),
    re.compile(r"\b(super baggy)\b", re.IGNORECASE),
    re.compile(r"\b(baggy)\b", re.IGNORECASE),
    re.compile(r"\b(wide[- ]leg)\b", re.IGNORECASE),
    re.compile(r"\b(flare)\b", re.IGNORECASE),
    re.compile(r"\b(skinny)\b", re.IGNORECASE),
    re.compile(r"\b(straight)\b", re.IGNORECASE),
    re.compile(r"\b(boxy)\b", re.IGNORECASE),
    re.compile(r"\b(cropped)\b", re.IGNORECASE),
]


@dataclass(frozen=True)
class ImagePaths:
    front: Path | None = None
    back: Path | None = None


@dataclass(frozen=True)
class RawBershkaRecord:
    gender: str
    source_category: str
    product_url: str
    ref_code: str
    name: str
    color: str | None
    description: str | None


@dataclass(frozen=True)
class PreparedCatalogRow:
    ref_code: str
    gender: str
    source_category: str
    category: str
    subtype: str | None
    name: str
    color: list[str] | None
    fit: str | None
    images: ImagePaths
    product_url: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Upload the local Bershka catalog export to AWS S3 and upsert it into catalog_items.",
    )
    parser.add_argument(
        "--json",
        type=Path,
        default=PROJECT_ROOT / "output/bershka/bershka_products.json",
        help="Path to bershka_products.json",
    )
    parser.add_argument(
        "--images-root",
        type=Path,
        default=PROJECT_ROOT / "output/bershka/images",
        help="Root directory containing the local Bershka product images",
    )
    parser.add_argument(
        "--brand",
        default="bershka",
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
    return parser.parse_args()


def ref_code_to_filename_prefix(ref_code: str) -> str:
    """Convert bershka ref_code to filename prefix: '8123/152/251' → '8123-152-251'."""
    return ref_code.replace("/", "-")


def titleize(text: str) -> str:
    return " ".join(word.capitalize() for word in text.split())


def slug_to_words(slug: str) -> str:
    cleaned = slug.replace("_", "-")
    parts = [part for part in cleaned.split("-") if part]
    return " ".join(parts)


def canonical_category(source_category: str) -> str:
    mapped = CANONICAL_CATEGORY_MAP.get(source_category)
    if not mapped:
        raise ValueError(f"No canonical category mapping for source category '{source_category}'")
    return mapped


def derive_subtype(source_category: str) -> str | None:
    subtype = titleize(slug_to_words(source_category))
    return subtype or None


def derive_fit(name: str) -> str | None:
    for pattern in FIT_PATTERNS:
        match = pattern.search(name)
        if match:
            return match.group(1).lower().replace("-", " ")
    return None


def _classify_bershka_image(path: Path) -> str | None:
    """Classify a bershka image into front or back (no-bg only).

    Bershka naming: -a4o = front, -b = back, _no_bg = background removed.
    We only import no-bg variants; with-bg images are ignored.
    """
    name = path.name
    if "-a4o_no_bg." in name:
        return "front"
    if "-b_no_bg." in name:
        return "back"
    return None


def find_image_paths(record: RawBershkaRecord, images_root: Path) -> ImagePaths | None:
    prefix = ref_code_to_filename_prefix(record.ref_code)
    expected_dir = images_root / record.gender / record.source_category
    matches = list(expected_dir.glob(f"{prefix}*"))

    if not matches:
        matches = list(images_root.rglob(f"{prefix}*"))

    if not matches:
        return None

    slots: dict[str, Path] = {}
    for path in sorted(matches):
        slot = _classify_bershka_image(path)
        if slot and slot not in slots:
            slots[slot] = path

    if not slots:
        return None

    return ImagePaths(
        front=slots.get("front"),
        back=slots.get("back"),
    )


def load_raw_records(json_path: Path) -> list[RawBershkaRecord]:
    data = json.loads(json_path.read_text())
    rows: list[RawBershkaRecord] = []
    for gender, categories in data.items():
        if not isinstance(categories, dict):
            continue
        for source_category, items in categories.items():
            if not isinstance(items, list):
                continue
            for item in items:
                rows.append(
                    RawBershkaRecord(
                        gender=gender,
                        source_category=source_category,
                        product_url=item["product_url"].rstrip("\\").strip(),
                        ref_code=str(item["ref_code"]).strip(),
                        name=item.get("name", ""),
                        color=item.get("color"),
                        description=item.get("description"),
                    )
                )
    return rows


def dedupe_records(records: list[RawBershkaRecord], images_root: Path) -> list[RawBershkaRecord]:
    grouped: dict[str, list[RawBershkaRecord]] = {}
    for record in records:
        grouped.setdefault(record.product_url, []).append(record)

    chosen: list[RawBershkaRecord] = []
    for product_url, variants in grouped.items():
        best = None
        for record in variants:
            paths = find_image_paths(record, images_root)
            if paths is not None:
                best = record
                break
            if best is None:
                best = record
        if best is None:
            raise RuntimeError(f"Unexpected empty variant group for {product_url}")
        chosen.append(best)

    chosen.sort(key=lambda record: record.product_url)
    return chosen


def prepare_rows(records: list[RawBershkaRecord], images_root: Path) -> tuple[list[PreparedCatalogRow], list[str]]:
    prepared: list[PreparedCatalogRow] = []
    missing_images: list[str] = []
    seen_ref_codes: set[str] = set()

    for record in records:
        paths = find_image_paths(record, images_root)
        if paths is None:
            missing_images.append(record.product_url)
            continue

        ref_code = ref_code_to_filename_prefix(record.ref_code)
        if ref_code in seen_ref_codes:
            continue
        seen_ref_codes.add(ref_code)

        prepared.append(
            PreparedCatalogRow(
                ref_code=ref_code,
                gender=record.gender,
                source_category=record.source_category,
                category=canonical_category(record.source_category),
                subtype=derive_subtype(record.source_category),
                name=record.name,
                color=[record.color.strip()] if record.color else None,
                fit=derive_fit(record.name),
                images=paths,
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
                    "gender": row.gender,
                    "source_category": row.source_category,
                    "category": row.category,
                    "subtype": row.subtype,
                    "name": row.name,
                    "color": row.color,
                    "fit": row.fit,
                    "image_front": str(row.images.front) if row.images.front else None,
                    "image_back": str(row.images.back) if row.images.back else None,
                    "product_url": row.product_url,
                },
                ensure_ascii=True,
            )
        )
    if missing_images:
        print("Missing image examples:")
        for url in missing_images[:10]:
            print(f"  - {url}")


def _upload_image(s3, bucket: str, image_path: Path, brand: str, ref_code: str, suffix: str) -> str:
    from app.services.storage_service import _build_public_url

    content_type = mimetypes.guess_type(image_path.name)[0] or "image/jpeg"
    key = f"catalog/{brand}/{ref_code}_{suffix}{image_path.suffix.lower()}"
    s3.upload_file(
        str(image_path),
        bucket,
        key,
        ExtraArgs={"ContentType": content_type},
    )
    return _build_public_url(key)


def _upload_all_images(
    s3, bucket: str, images: ImagePaths, brand: str, ref_code: str,
) -> dict[str, str | None]:
    urls: dict[str, str | None] = {
        "image_front_url": None,
        "image_back_url": None,
    }
    mapping = [
        ("image_front_url", images.front, "front"),
        ("image_back_url", images.back, "back"),
    ]
    for field, path, suffix in mapping:
        if path:
            urls[field] = _upload_image(s3, bucket, path, brand, ref_code, suffix)
    return urls


async def run_import(rows: list[PreparedCatalogRow], brand: str, commit_every: int) -> None:
    os.chdir(BACKEND_ROOT)
    if str(BACKEND_ROOT) not in sys.path:
        sys.path.insert(0, str(BACKEND_ROOT))

    from sqlalchemy import select

    from app.database import AsyncSessionLocal
    from app.models.catalog import CatalogItem
    from app.services.storage_service import _get_client, settings

    session = AsyncSessionLocal()
    s3 = _get_client()

    try:
        result = await session.execute(select(CatalogItem).where(CatalogItem.brand == brand))
        existing_by_ref = {item.ref_code: item for item in result.scalars() if item.ref_code}

        created = 0
        updated = 0

        for index, row in enumerate(rows, start=1):
            urls = _upload_all_images(s3, settings.R2_BUCKET, row.images, brand, row.ref_code)

            front_url = urls["image_front_url"]
            if not front_url:
                fallback = urls["image_back_url"]
                if not fallback:
                    print(f"SKIP {row.ref_code}: no images uploaded")
                    continue
                front_url = fallback

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
                    image_front_url=front_url,
                    image_back_url=urls["image_back_url"],
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
                item.image_front_url = front_url
                item.image_back_url = urls["image_back_url"]
                item.product_url = row.product_url
                updated += 1

            if index % commit_every == 0:
                await session.commit()
                print(f"Committed {index}/{len(rows)} rows (created={created}, updated={updated})")

        await session.commit()
        print(f"Import complete: created={created}, updated={updated}, total={len(rows)}")
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

    asyncio.run(run_import(prepared_rows, args.brand, args.commit_every))


if __name__ == "__main__":
    main()
