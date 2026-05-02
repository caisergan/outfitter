"""Phase 2 of the catalog taxonomy refactor — backfill the new columns.

Run AFTER alembic migration 0013 (which adds slot/category/subcategory/
occasion_tags/pattern_array columns) and BEFORE migration 0014 (which adds
NOT NULL + CHECK constraints).

The script never touches the old scalar `pattern` column or the old `style_tags`
column — those are handled by 0014 and the vision-AI tagger respectively.
It is idempotent: each subcommand only updates rows that still need work.

Sub-commands (all support ``--dry-run``):

    category        Backfill `category` from source JSON via slug→category
                    map and the Stradivarius name-keyword rules. CATALOG ONLY.
                    `--report-unmapped` prints distinct (brand, gender, slug)
                    not in the map and exits non-zero so CI can flag drift.

    subcategory     Re-classify the post-rename `subcategory` column (which
                    inherits the old polluted `subtype` data). Routes values
                    to fit/pattern/category/keep/drop via taxonomy_maps.
                    Both tables (`--table both` default).

    pattern         Wrap the existing scalar `pattern` value into the new
                    `pattern_array` array column. Both tables.

    fit             Normalize existing `fit` values against the controlled
                    FITS vocab (lowercase, drop "fit" suffix, dehyphen).
                    Out-of-vocab values are reported but not modified.

    all             Run category → subcategory → pattern → fit in order.

Usage:

    python -m scripts.backfill_catalog_taxonomy category --dry-run --report-unmapped
    python -m scripts.backfill_catalog_taxonomy subcategory --dry-run
    python -m scripts.backfill_catalog_taxonomy all
    python -m scripts.backfill_catalog_taxonomy fit --table wardrobe

Requires the same env as `tag_catalog_styles.py` (DATABASE_URL via
``backend/.env``, loaded automatically).
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable

from dotenv import load_dotenv
from sqlalchemy import bindparam, text
from sqlalchemy.ext.asyncio import AsyncConnection, create_async_engine

# Resolve repo paths and load backend/.env before importing app modules.
_BACKEND_DIR = Path(__file__).resolve().parent.parent
_REPO_ROOT = _BACKEND_DIR.parent
sys.path.insert(0, str(_BACKEND_DIR))
load_dotenv(_BACKEND_DIR / ".env")

from scripts.taxonomy_maps import (  # noqa: E402
    AMBIGUOUS_SLUG_RULES,
    CATEGORIES,
    FITS,
    PATTERNS,
    SLUG_TO_CATEGORY,
    classify_subtype,
    resolve_category,
    stradivarius_category_from_name,
    _normalize_for_fit,
)

logger = logging.getLogger("backfill_catalog_taxonomy")

DEFAULT_BATCH_SIZE = 500

MANGO_PRODUCTS_JSON = _REPO_ROOT / "output" / "mango" / "mango_products.json"
BERSHKA_PRODUCTS_JSON = _REPO_ROOT / "output" / "bershka" / "bershka_products.json"
STRADIVARIUS_PRODUCTS_JSON = _REPO_ROOT / "output" / "stradivarius" / "stradivarius_products.json"


# ---------------------------------------------------------------------------
# Engine helpers
# ---------------------------------------------------------------------------

def _async_database_url() -> str:
    from app.config import settings  # imported lazily so import works in dry-run contexts
    url = settings.DATABASE_URL
    if url.startswith("postgresql://"):
        url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
    return url


def _table_filter(table_arg: str) -> list[str]:
    if table_arg == "catalog":
        return ["catalog_items"]
    if table_arg == "wardrobe":
        return ["wardrobe_items"]
    return ["catalog_items", "wardrobe_items"]


# ---------------------------------------------------------------------------
# Sub-command 1: backfill `category` from source JSON  (catalog only)
# ---------------------------------------------------------------------------

def _bershka_lookup_ref(source_ref: str) -> str:
    """Bershka stores ref_code with `/` -> `-`. Used in WHERE matching."""
    return source_ref.replace("/", "-")


def _iter_mango_products() -> Iterable[tuple[str, str, str, str]]:
    """Yields (gender, slug, source_ref, name) for every Mango product.

    `source_ref` is the bare reference; Mango stored ref_codes are
    `<source_ref>` or `<source_ref>-COLOR` or `<source_ref>-COLOR-DIGEST`.
    """
    if not MANGO_PRODUCTS_JSON.exists():
        logger.warning("Mango source JSON not found at %s", MANGO_PRODUCTS_JSON)
        return
    with MANGO_PRODUCTS_JSON.open() as f:
        data = json.load(f)
    for gender, slug_dict in data.items():
        for slug, products in slug_dict.items():
            for product in products:
                ref = product.get("ref_code")
                if not ref:
                    continue
                name = product.get("name") or product.get("description") or ""
                yield (gender, slug, str(ref).strip(), name)


def _iter_bershka_products() -> Iterable[tuple[str, str, str, str]]:
    """Yields (gender, slug, lookup_ref, name) for every Bershka product.

    `lookup_ref` is already in stored form (slashes converted to dashes).
    """
    if not BERSHKA_PRODUCTS_JSON.exists():
        logger.warning("Bershka source JSON not found at %s", BERSHKA_PRODUCTS_JSON)
        return
    with BERSHKA_PRODUCTS_JSON.open() as f:
        data = json.load(f)
    for gender, slug_dict in data.items():
        for slug, products in slug_dict.items():
            for product in products:
                ref = product.get("ref_code")
                if not ref:
                    continue
                name = product.get("name") or ""
                yield (gender, slug, _bershka_lookup_ref(str(ref).strip()), name)


def _iter_stradivarius_products() -> Iterable[tuple[str, str]]:
    """Yields (lookup_ref, name) for every Stradivarius product.

    Stradivarius is a flat list. Stored ref_code uses the same `/` -> `-`
    transform as Bershka.
    """
    if not STRADIVARIUS_PRODUCTS_JSON.exists():
        logger.warning("Stradivarius source JSON not found at %s", STRADIVARIUS_PRODUCTS_JSON)
        return
    with STRADIVARIUS_PRODUCTS_JSON.open() as f:
        data = json.load(f)
    for product in data:
        ref = product.get("ref_code")
        if not ref:
            continue
        name = product.get("name") or ""
        yield (_bershka_lookup_ref(str(ref).strip()), name)


async def _update_category_for_ref(
    conn: AsyncConnection,
    *,
    brand: str,
    lookup_ref: str,
    category: str,
    dry_run: bool,
) -> int:
    """UPDATE catalog_items SET category=:cat where idempotent and ref matches.

    Matches both the bare ref_code and any `ref_code LIKE 'lookup_ref-%'`
    so Mango's color-suffixed variants are caught.
    """
    if dry_run:
        # Count rows that WOULD be updated; don't write.
        result = await conn.execute(
            text(
                "SELECT COUNT(*) FROM catalog_items "
                "WHERE brand = :brand AND category IS NULL "
                "AND (ref_code = :lref OR ref_code LIKE :lref || '-%')"
            ),
            {"brand": brand, "lref": lookup_ref},
        )
        return int(result.scalar() or 0)

    result = await conn.execute(
        text(
            "UPDATE catalog_items "
            "SET category = :cat "
            "WHERE brand = :brand AND category IS NULL "
            "AND (ref_code = :lref OR ref_code LIKE :lref || '-%')"
        ),
        {"cat": category, "brand": brand, "lref": lookup_ref},
    )
    return result.rowcount or 0


async def cmd_category(args: argparse.Namespace) -> int:
    if "wardrobe" in _table_filter(args.table) and len(_table_filter(args.table)) == 1:
        logger.info("category backfill is catalog-only (wardrobe items have no source slug); nothing to do")
        return 0

    engine = create_async_engine(_async_database_url(), pool_pre_ping=True)
    unmapped: Counter[tuple[str, str, str]] = Counter()
    matched_total = 0
    updated_total = 0

    async with engine.begin() as conn:
        # Mango + Bershka: lookup via slug map, with ambiguous-slug fallback.
        # Brand strings match the lowercased values stored in catalog_items.brand.
        for brand, iterator in (("mango", _iter_mango_products()), ("bershka", _iter_bershka_products())):
            for gender, slug, lookup_ref, name in iterator:
                category = resolve_category(slug=slug, gender=gender, name=name)
                if category is None:
                    unmapped[(brand, gender, slug)] += 1
                    continue
                rows = await _update_category_for_ref(
                    conn, brand=brand, lookup_ref=lookup_ref,
                    category=category, dry_run=args.dry_run,
                )
                matched_total += 1
                updated_total += rows

        # Stradivarius: name-keyword inference. We don't track gender on this brand.
        for lookup_ref, name in _iter_stradivarius_products():
            category = stradivarius_category_from_name(name)
            if category is None:
                unmapped[("Stradivarius", "unknown", "(name-keyword miss)")] += 1
                continue
            rows = await _update_category_for_ref(
                conn, brand="stradivarius", lookup_ref=lookup_ref,
                category=category, dry_run=args.dry_run,
            )
            matched_total += 1
            updated_total += rows

    await engine.dispose()

    verb = "would update" if args.dry_run else "updated"
    logger.info("category backfill: %d source items mapped, %s %d DB rows", matched_total, verb, updated_total)

    if unmapped:
        # Sort by count desc for human scanning.
        ordered = sorted(unmapped.items(), key=lambda kv: -kv[1])
        if args.report_unmapped:
            logger.warning("UNMAPPED slugs (brand, gender, slug, count):")
            for (brand_, gender, slug), count in ordered:
                logger.warning("  %s %s %s %d", brand_, gender, slug, count)
            return 2  # non-zero so CI can detect map drift
        else:
            logger.info("(%d distinct unmapped slug groups; pass --report-unmapped to see them)", len(ordered))
    return 0


# ---------------------------------------------------------------------------
# Sub-command 2: cleanup `subcategory`  (both tables)
# ---------------------------------------------------------------------------

async def cmd_subcategory(args: argparse.Namespace) -> int:
    engine = create_async_engine(_async_database_url(), pool_pre_ping=True)
    summary: dict[str, Counter[str]] = {tbl: Counter() for tbl in _table_filter(args.table)}

    async with engine.begin() as conn:
        for table in _table_filter(args.table):
            # Pull every row with a non-null subcategory; classify in Python.
            rows = await conn.execute(
                text(f"SELECT id, subcategory, fit, category FROM {table} WHERE subcategory IS NOT NULL")
            )
            for row in rows.mappings():
                target_col, target_value = classify_subtype(row["subcategory"])
                summary[table][target_col] += 1

                if args.dry_run:
                    continue

                if target_col == "subcategory":
                    # Normalize-in-place if the canonical form differs.
                    if target_value != row["subcategory"]:
                        await conn.execute(
                            text(f"UPDATE {table} SET subcategory = :v WHERE id = :id"),
                            {"v": target_value, "id": row["id"]},
                        )
                elif target_col == "fit":
                    # Only fill fit if currently NULL — never clobber a pre-existing fit.
                    if row["fit"] is None:
                        await conn.execute(
                            text(f"UPDATE {table} SET fit = :v, subcategory = NULL WHERE id = :id"),
                            {"v": target_value, "id": row["id"]},
                        )
                    else:
                        # Already had a fit — just clear the polluted subcategory.
                        await conn.execute(
                            text(f"UPDATE {table} SET subcategory = NULL WHERE id = :id"),
                            {"id": row["id"]},
                        )
                elif target_col == "pattern":
                    # Append to pattern_array (idempotent — skip if already present).
                    await conn.execute(
                        text(
                            f"UPDATE {table} "
                            f"SET pattern_array = COALESCE(pattern_array, ARRAY[]::text[]) || ARRAY[:v]::text[], "
                            f"    subcategory = NULL "
                            f"WHERE id = :id "
                            f"  AND (pattern_array IS NULL OR NOT (:v = ANY(pattern_array)))"
                        ),
                        {"v": target_value, "id": row["id"]},
                    )
                    # If the array already contained the value, still clear subcategory.
                    await conn.execute(
                        text(f"UPDATE {table} SET subcategory = NULL WHERE id = :id"),
                        {"id": row["id"]},
                    )
                elif target_col == "category":
                    # Promote to category column only if currently NULL — don't override
                    # a value that source-JSON backfill already set.
                    if row["category"] is None:
                        await conn.execute(
                            text(f"UPDATE {table} SET category = :v, subcategory = NULL WHERE id = :id"),
                            {"v": target_value, "id": row["id"]},
                        )
                    else:
                        await conn.execute(
                            text(f"UPDATE {table} SET subcategory = NULL WHERE id = :id"),
                            {"id": row["id"]},
                        )
                else:  # drop
                    await conn.execute(
                        text(f"UPDATE {table} SET subcategory = NULL WHERE id = :id"),
                        {"id": row["id"]},
                    )

    await engine.dispose()

    verb = "would route" if args.dry_run else "routed"
    for table, counter in summary.items():
        total = sum(counter.values())
        logger.info(
            "subcategory cleanup [%s]: %s %d non-null rows  "
            "(keep=%d, fit=%d, pattern=%d, category=%d, drop=%d)",
            table, verb, total,
            counter.get("subcategory", 0),
            counter.get("fit", 0),
            counter.get("pattern", 0),
            counter.get("category", 0),
            counter.get("drop", 0),
        )
    return 0


# ---------------------------------------------------------------------------
# Sub-command 3: backfill `pattern_array` from scalar `pattern`  (both tables)
# ---------------------------------------------------------------------------

async def cmd_pattern(args: argparse.Namespace) -> int:
    engine = create_async_engine(_async_database_url(), pool_pre_ping=True)
    totals: dict[str, int] = {}

    async with engine.begin() as conn:
        for table in _table_filter(args.table):
            # Idempotent: only rows where the array is empty/null AND the
            # scalar has a value, AND the value is in the controlled vocab.
            select_stmt = text(
                f"SELECT id, pattern FROM {table} "
                f"WHERE pattern IS NOT NULL "
                f"  AND (pattern_array IS NULL OR cardinality(pattern_array) = 0)"
            )
            rows = await conn.execute(select_stmt)
            count = 0
            unrecognized: Counter[str] = Counter()
            for row in rows.mappings():
                normalized = (row["pattern"] or "").strip().lower()
                if normalized not in PATTERNS:
                    unrecognized[normalized] += 1
                    continue
                count += 1
                if args.dry_run:
                    continue
                await conn.execute(
                    text(f"UPDATE {table} SET pattern_array = ARRAY[:p]::text[] WHERE id = :id"),
                    {"p": normalized, "id": row["id"]},
                )
            totals[table] = count
            if unrecognized:
                logger.warning(
                    "[%s] %d rows had pattern values outside controlled vocab; left untouched. "
                    "Top examples: %s",
                    table, sum(unrecognized.values()),
                    ", ".join(f"{v!r}={n}" for v, n in unrecognized.most_common(5)),
                )

    await engine.dispose()
    verb = "would copy" if args.dry_run else "copied"
    for table, count in totals.items():
        logger.info("pattern backfill [%s]: %s %d scalar values into pattern_array", table, verb, count)
    return 0


# ---------------------------------------------------------------------------
# Sub-command 4: normalize `fit`  (both tables)
# ---------------------------------------------------------------------------

async def cmd_fit(args: argparse.Namespace) -> int:
    engine = create_async_engine(_async_database_url(), pool_pre_ping=True)
    totals: dict[str, dict[str, int]] = {}

    async with engine.begin() as conn:
        for table in _table_filter(args.table):
            rows = await conn.execute(text(f"SELECT id, fit FROM {table} WHERE fit IS NOT NULL"))
            normalized_count = 0
            already_canonical = 0
            outside_vocab: Counter[str] = Counter()
            for row in rows.mappings():
                original = row["fit"]
                norm = _normalize_for_fit(original)
                if norm not in FITS:
                    outside_vocab[original] += 1
                    continue
                if norm == original:
                    already_canonical += 1
                    continue
                normalized_count += 1
                if args.dry_run:
                    continue
                await conn.execute(
                    text(f"UPDATE {table} SET fit = :v WHERE id = :id"),
                    {"v": norm, "id": row["id"]},
                )
            totals[table] = {
                "normalized": normalized_count,
                "canonical": already_canonical,
                "outside_vocab": sum(outside_vocab.values()),
            }
            if outside_vocab:
                logger.warning(
                    "[%s] %d rows have fit values outside controlled vocab (left untouched). "
                    "Top examples: %s",
                    table, sum(outside_vocab.values()),
                    ", ".join(f"{v!r}={n}" for v, n in outside_vocab.most_common(5)),
                )

    await engine.dispose()
    verb = "would normalize" if args.dry_run else "normalized"
    for table, c in totals.items():
        logger.info(
            "fit normalize [%s]: %s %d rows (%d already canonical, %d outside vocab)",
            table, verb, c["normalized"], c["canonical"], c["outside_vocab"],
        )
    return 0


# ---------------------------------------------------------------------------
# `all` — run the four sub-commands in dependency order.
# ---------------------------------------------------------------------------

async def cmd_all(args: argparse.Namespace) -> int:
    rc = await cmd_category(args)
    if rc not in (0, 2):  # 2 == map drift; tolerated for `all`
        return rc
    if await cmd_subcategory(args) != 0:
        return 1
    if await cmd_pattern(args) != 0:
        return 1
    if await cmd_fit(args) != 0:
        return 1
    return 0


# ---------------------------------------------------------------------------
# CLI plumbing
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--verbose", "-v", action="count", default=0)
    sub = parser.add_subparsers(dest="step", required=True)

    def _add_common(p: argparse.ArgumentParser, *, support_table: bool = True) -> None:
        p.add_argument("--dry-run", action="store_true", help="Read-only; print what would change")
        if support_table:
            p.add_argument(
                "--table", choices=["catalog", "wardrobe", "both"], default="both",
                help="Which table to operate on (default: both)",
            )

    p_cat = sub.add_parser("category", help="Backfill category from source JSON (catalog only)")
    _add_common(p_cat, support_table=False)
    p_cat.add_argument(
        "--report-unmapped", action="store_true",
        help="Print distinct (brand, gender, slug) not in the map and exit non-zero",
    )

    p_sub = sub.add_parser("subcategory", help="Cleanup subcategory column")
    _add_common(p_sub)

    p_pat = sub.add_parser("pattern", help="Backfill pattern_array from scalar pattern")
    _add_common(p_pat)

    p_fit = sub.add_parser("fit", help="Normalize fit values against controlled vocab")
    _add_common(p_fit)

    p_all = sub.add_parser("all", help="Run category → subcategory → pattern → fit in order")
    _add_common(p_all)
    p_all.add_argument(
        "--report-unmapped", action="store_true",
        help="(forwarded to category step)",
    )

    return parser.parse_args()


def main() -> None:
    args = parse_args()
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%H:%M:%S",
    )

    # Default `--table` for the `category` subcommand (which doesn't accept it).
    if args.step == "category" and not hasattr(args, "table"):
        args.table = "catalog"

    handlers = {
        "category": cmd_category,
        "subcategory": cmd_subcategory,
        "pattern": cmd_pattern,
        "fit": cmd_fit,
        "all": cmd_all,
    }
    rc = asyncio.run(handlers[args.step](args))
    sys.exit(rc)


if __name__ == "__main__":
    main()
