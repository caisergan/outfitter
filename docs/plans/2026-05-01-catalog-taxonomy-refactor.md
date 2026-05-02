# Catalog Taxonomy Refactor Plan

**Created:** 2026-05-01
**Status:** **Locked — ready for phase-by-phase execution on user's go-ahead**
**Branch:** `feat/backend-catalog-items` (currently fast-forwarded to `main`)

---

## 0. Context

The `catalog_items` table currently has overlapping/polluted classification columns. After multiple design rounds, we've agreed to a 3-level taxonomy plus controlled vocabularies for every other classification column. This plan executes that refactor across backend, admin, and mobile.

### 0.1 Decisions Locked In

| # | Question | Answer |
|---|---|---|
| Scope | Backend + admin Next.js + Flutter mobile (full stack) | locked |
| Existing data | Migrate carefully — preserve existing values where possible | locked |
| Source-slug vocab gaps | Skip un-mappable slugs (leave `category` NULL for manual cleanup) | locked |
| Migration strategy | Two alembic migrations: schema (nullable adds + renames) → backfill script → finalization (NOT NULL + CHECK constraints) | locked |
| **Q1 — Wardrobe scope** | **(b) Catalog + wardrobe in one migration** — `wardrobe_items` gets the same taxonomy treatment in the same phase set | locked |
| **Q2 — Blouse rule** | **(a) Gender-keyed**: women → `blouse`, men → `shirt` for ambiguous `shirts---blouses` / `shirts-and-blouses` slugs | locked |
| **Q3 — Ambiguous compound slugs** | **(b) Name-keyword pass**: `dresses-and-jumpsuits` and `skirts-and-shorts` split via "jumpsuit"/"skirt" substring match in product name; fallback to majority | locked |
| **Q4 — Pattern type change** | **(a) Intermediate `pattern_array` column**: add new array column in Phase 1, backfill from scalar in Phase 2, drop scalar + rename in Phase 7 | locked |
| **Q5 — Unmapped-slug reporting** | **(a) Yes** — backfill script ships with `--report-unmapped` flag printing `(brand, slug, count)` for slugs not in the map | locked |

### 0.2 Target Schema

| # | Column | DB type | Nullable | Indexed | Controlled | Status vs today |
|---|---|---|---|---|---|---|
| 1 | `id` | UUID | NO | PK | — | unchanged |
| 2 | `ref_code` | String(100) | YES | unique | — | unchanged |
| 3 | `brand` | String(100) | NO | yes | — | unchanged |
| 4 | `gender` | String(16) | YES | yes | yes | unchanged |
| 5 | **`slot`** | String(20) | NO | yes | 10 values | renamed from `category` |
| 6 | **`category`** | String(50) | YES | yes | ~31 values | NEW (backfill nullable, finalize NOT NULL where mappable) |
| 7 | **`subcategory`** | String(100) | YES | — | sparse | renamed from `subtype` + cleaned |
| 8 | `name` | String(255) | NO | — | — | unchanged |
| 9 | `color` | ARRAY(String) | YES | gin | — | unchanged |
| 10 | **`pattern`** | ARRAY(String) | YES | gin | 18 values | TYPE CHANGE: scalar → array |
| 11 | `fit` | String(50) | YES | — | 19 values | scope narrowed |
| 12 | **`style_tags`** | ARRAY(String) | YES | gin | 17 values | scope narrowed (aesthetic only) |
| 13 | **`occasion_tags`** | ARRAY(String) | YES | gin | 13 values | NEW |
| 14-19 | image_*, product_url, clip_embedding, timestamps | — | — | — | — | unchanged |

### 0.3 Discovery Phase 0 — Findings to Reference

These were verified by sub-agent exploration on 2026-05-01:

**Backend conventions (verified)**
- Migration filenames: `NNNN_slug-description.py` (next free number: **`0013`**)
- Migration header: 1-line imperative + `Revision ID` / `Revises` / `Create Date` block
- Renames: `op.alter_column(table, col, new_column_name=...)`
- Bulk data updates: `op.execute(sa.text("UPDATE ..."))`
- ENUMs: **CHECK constraints, not Postgres ENUM types** — pattern from `0009_add_user_role_column.py`:
  ```python
  op.create_check_constraint("ck_<table>_<column>", "<table>", "<column> IN (...)")
  ```
- GIN indexes for arrays: `op.execute("CREATE INDEX ix_... USING gin (column)")` (pattern from `0005_catalog_filter_indexes.py`)
- Conditional/idempotent logic: `sa.inspect(op.get_bind()).get_table_names()` pattern from `0011`
- Test DB: SQLite via `aiosqlite`, with type shims (Vector→Text, ARRAY→JSON, UUID→String) in `tests/conftest.py`. **Migration tests must work on SQLite** — avoid Postgres-only operators in migrations or guard with `if op.get_bind().dialect.name == "postgresql"`.

**Source data shape (verified)**
- Mango/Bershka: `{gender: {category-slug: [products]}}` — products carry `ref_code`, `name`, `product_url`, `description`
- Stradivarius: flat list, no embedded category — name-keyword inference required
- 37 unique slugs across all brands (full mapping in Appendix A)
- 8 slugs are out-of-vocab (skip them — leave `category` NULL for manual cleanup, per locked-in answer #3)

**Frontend surface area (verified)**
- Admin's "playground page" is actually `admin/src/app/tryon/page.js` (NOT `playground/page.js`)
- Mobile catalog model: `mobile/lib/core/models/catalog_item.dart` (freezed, 25 lines)
- Mobile filter UI: `mobile/lib/features/tryon/ui/widgets/item_browser_sheet.dart` (898 lines, post-merge — much expanded vs prior version)
- 30+ files reference `subtype`. Full list in §6 of this plan.

---

## 1. Resolved Questions (Decision Log)

All five blocking questions resolved 2026-05-01. Rationale preserved here for future reviewers.

| # | Decision | Why |
|---|---|---|
| **Q1 — Wardrobe scope** | (b) Catalog + wardrobe in one migration | Wardrobe shares the same `category`/`subtype` columns AND the same Claude/Gemini AI tagging service (`backend/app/services/claude_service.py:15-24`). Splitting them means dual-mode AI prompts and divergent frontend code. The scope increase (~30%) is mostly mechanical: wardrobe model + schema + router + `tag_confirmation_sheet` + 1 backfill helper. |
| **Q2 — Blouse rule** | (a) Gender-keyed: women → `blouse`, men → `shirt` | The `shirts---blouses` (Mango W) and `shirts-and-blouses` (Bershka W) slugs lump both garment types. The `gender` column is reliable, and retail intent is gendered. Name-keyword fallback would be noisier. |
| **Q3 — Ambiguous compound slugs** | (b) Name-keyword pass | `dresses-and-jumpsuits` (673 items) and `skirts-and-shorts` (242 items) are too large to default-bucket. Substring match on product name (`"jumpsuit"`, `"skirt"`) splits them cleanly with fallback to the majority value. |
| **Q4 — Pattern column type change** | (a) Intermediate `pattern_array` column | Postgres `ALTER COLUMN ... TYPE TEXT[]` doesn't work on the SQLite test environment. Three-step approach (add new array column → backfill from scalar → drop scalar + rename) works on both DBs and matches alembic patterns used elsewhere. |
| **Q5 — Unmapped-slug reporting** | (a) Yes | Source slugs drift over time as scrapers update. `--report-unmapped` flag prints distinct `(brand, slug, count)` for slugs not covered by the map, so we know when to extend it. |

---

## 2. Phase Sequence

```
Phase 1: Schema migration (additive, allow NULL)
Phase 2: Backfill script (data layer)
Phase 3: Backend code refactor (model, schemas, router)
Phase 4: Vision-AI tagging (style_tags + occasion_tags)
Phase 5: Admin frontend update (catalog/page.js, tryon/page.js, wardrobe/page.js)
Phase 6: Mobile update (catalog_item.dart, filter UI, providers)
Phase 7: Finalization migration (NOT NULL, CHECK constraints, index, drop old pattern)
Phase 8: Testing + verification
```

Each phase is **self-contained**: it can run in a fresh chat with only this doc as context.

---

## Phase 1 — Schema Migration (Additive)

**Goal:** Add new columns, rename existing ones, allow NULL throughout, on **both `catalog_items` and `wardrobe_items` tables** (per Q1=b). The DB now has both old and new shapes; nothing is lost.

### Files to create
- `backend/alembic/versions/0013_catalog_and_wardrobe_taxonomy_split.py`

### Operations (in order — apply to BOTH `catalog_items` and `wardrobe_items`)
1. **Rename** `<table>.category` → `<table>.slot`. Old data ("top", "bottom", …) preserved.
2. **Rename index** `ix_<table>_category` → `ix_<table>_slot` (where it exists).
3. **Rename** `<table>.subtype` → `<table>.subcategory`. Polluted data preserved (will be cleaned in Phase 2).
4. **Add** `<table>.category String(50) NULL` (no index yet — added in Phase 7).
5. **Add** `<table>.occasion_tags ARRAY(String) NULL`.
6. **Add** `<table>.pattern_array ARRAY(String) NULL` (new column for the type change; old `pattern` scalar stays for now).

> Verify exact wardrobe column names before authoring the migration — `wardrobe_items` may not have all the same columns (e.g., it may not have a `pattern` scalar). The migration should add only what's needed per table; `op.add_column` for missing columns, skip for ones that already match.

### Doc references to copy from
- `backend/alembic/versions/0007_catalog_multi_image_columns.py:18-24` — the `op.alter_column(... new_column_name=)` pattern for rename
- `backend/alembic/versions/0006_add_gender_to_catalog_items.py:18-23` — `op.add_column` with nullable + index creation
- `backend/alembic/versions/0011_rename_playground_objects_to_tryon.py:18-37` — idempotency helpers if needed (`_has_table`, `_has_check_constraint`)

### Downgrade
- Reverse all 6 operations. The renames are bidirectional. Drop newly-added columns.

### Verification checklist
- [ ] `alembic upgrade head` runs cleanly on a fresh DB and on a DB at `0012`
- [ ] `alembic downgrade -1` reverses the migration without data loss for unaffected columns
- [ ] After upgrade, in Postgres: `\d catalog_items` shows `slot`, `subcategory`, `category`, `occasion_tags`, `pattern_array` columns
- [ ] After upgrade, run a SELECT — every row's `slot` equals the row's old `category` value (verify nothing dropped)
- [ ] Tests in `tests/test_catalog.py` still pass with the model unchanged (Phase 1 is DB-only — model in code still references old column names; that's intentional and gets fixed in Phase 3)

### Anti-pattern guards
- ❌ Do **not** add CHECK constraints in this phase — they'd reject existing polluted data. Constraints land in Phase 7.
- ❌ Do **not** drop the old scalar `pattern` column yet — both columns coexist until Phase 7.
- ❌ Do **not** make new columns NOT NULL — would fail because nothing has populated them yet.
- ❌ Do **not** reorder columns. Renames keep ordinal position; new columns append.

### Rollback
- `alembic downgrade 0012`. Brings DB back to pre-refactor state.

---

## Phase 2 — Data Backfill

**Goal:** Populate `slot` (already done by rename), backfill `category` from source JSON, clean up `subcategory`, populate `pattern_array` from old scalar `pattern`, normalize `fit` against the new vocab. **Applies to both `catalog_items` and `wardrobe_items`** (per Q1=b) — wardrobe gets the subcategory cleanup and fit normalization but NOT the source-JSON `category` backfill (wardrobe items are user-uploaded, not from scraped sources).

### Files to create
- `backend/scripts/backfill_catalog_taxonomy.py` — single script with subcommands per column. CLI flags include `--table {catalog|wardrobe|both}`, `--dry-run`, `--report-unmapped` (per Q5=a).
- `backend/scripts/taxonomy_maps.py` — module exporting `SLUG_TO_CATEGORY`, `STRADIVARIUS_KEYWORD_RULES`, `SUBTYPE_REMAP_RULES`, `AMBIGUOUS_SLUG_RULES` (single source of truth, importable by import scripts later)

### Operations (in order)

#### 2.1 Backfill `category` from source JSON (catalog only)
- Walk `output/mango/mango_products.json` and `output/bershka/bershka_products.json` as `{gender: {slug: [products]}}`. For each product, look up `(brand, ref_code)` in DB and write `category` from `SLUG_TO_CATEGORY[slug]`.
- **Ambiguous slugs (Q3=b — name-keyword pass):**
  - `dresses-and-jumpsuits`: if product name contains `"jumpsuit"` → `category="jumpsuit"`, else → `category="dress"`.
  - `skirts-and-shorts`: if product name contains `"skirt"` → `category="skirt"`, else → `category="shorts"`.
  - Implement in `AMBIGUOUS_SLUG_RULES` map: `{slug: [(name_substring, target_category), ..., default_category]}`.
- **Blouse rule (Q2=a — gender-keyed):**
  - `shirts---blouses` (Mango W) and `shirts-and-blouses` (Bershka W): if `gender="women"` → `category="blouse"`, if `gender="men"` → `category="shirt"`. Apply via wrapper around `SLUG_TO_CATEGORY` lookup.
- For Stradivarius: walk flat list, apply `STRADIVARIUS_KEYWORD_RULES` (most-specific first) against `name`. Write match or NULL.
- Use the `slug→category` mapping in **Appendix A** (37 slugs catalogued).
- **`--report-unmapped` flag (Q5=a):** print distinct `(brand, gender, slug, count)` not in the map. Exits non-zero if unmapped slugs exist (so CI can flag stale maps).

#### 2.2 Clean up `subcategory`
- For every row, apply `SUBTYPE_REMAP_RULES` (Appendix B) to the existing (renamed) `subcategory` value:
  - If value is in the "garment-type" list → leave as-is in `subcategory`
  - If value matches a `fit` value → move to `fit` column (only if `fit` is currently NULL), null out `subcategory`
  - If value matches a `pattern` value → append to `pattern_array`, null out `subcategory`
  - Else (garbage like "Slim Fit", "Striped", "Short Sleeved"): null out `subcategory`

#### 2.3 Backfill `pattern_array`
- For rows where old scalar `pattern` is non-null AND not yet in `pattern_array`: append `[pattern]` to the array column.
- Tests pre/post: row count of `pattern IS NOT NULL` == row count of `array_length(pattern_array, 1) >= 1`.

#### 2.4 Normalize `fit`
- For every row where `fit` is set, lowercase + map common variants ("relaxed fit" → "relaxed", "slim fit" → "slim") against the controlled fit vocab.
- Values not in vocab → leave as-is and report in the "unmapped" log (decide manually in next iteration).

### Doc references to copy from
- `backend/scripts/import_mango_catalog.py:148-155` — `slug_to_words` and `titleize` helpers (copy pattern)
- `backend/scripts/import_mango_catalog.py:393-463` — DB upsert/update pattern with `(brand, ref_code)` lookup
- `backend/scripts/tag_catalog_styles.py:230-245` — async DB write batching pattern

### Verification checklist
- [ ] After Phase 2.1: `SELECT COUNT(*) FROM catalog_items WHERE category IS NOT NULL` matches expected coverage (HIGH-confidence slugs alone should cover ~70%+ of items)
- [ ] After Phase 2.1: `--report-unmapped` output shows only the 8 known SKIP slugs (Appendix A) plus any newly-added scraper slugs
- [ ] After Phase 2.2: Spot-check 20 random rows. Bad subtype values ("Slim Fit", "Striped") are NULL; good values ("shirt", "t-shirt") preserved.
- [ ] After Phase 2.3: `array_length(pattern_array, 1)` equals 1 for every row that previously had a non-null `pattern`.
- [ ] After Phase 2.4: every non-NULL `fit` value is in the controlled vocab.
- [ ] Backfill script is **idempotent** — running it twice produces no diff on the second run.

### Anti-pattern guards
- ❌ Do **not** drop the old scalar `pattern` column yet — Phase 7's job.
- ❌ Do **not** delete rows where mapping fails — leave `category` NULL per locked-in answer #3.
- ❌ Do **not** hardcode the slug map inside the backfill script — put it in `taxonomy_maps.py` so the import scripts (Phase 3) can reuse it.
- ❌ Do **not** assume Postgres-only SQL works in tests — gate Postgres-specific syntax behind dialect checks.

### Rollback
- The script must support a `--dry-run` mode that prints what would change. Real backfills should be wrapped in a single transaction per batch (commit every 100 rows). On failure, partial progress is acceptable; re-run is idempotent.
- True rollback (full revert): `alembic downgrade 0012` (Phase 1 rollback) — wipes all the new columns.

---

## Phase 3 — Backend Code Refactor

**Goal:** Update SQLAlchemy model, Pydantic schemas, search router, and `/catalog/filter-options` endpoint to reflect the new schema.

### Files to modify

#### 3.1 `backend/app/models/catalog.py`
Replace the `CatalogItem` class:
- `category` (String(50), NOT NULL) → renamed to `slot` (String(20), NOT NULL)
- Add new `category: Mapped[str | None] = mapped_column(String(50), nullable=True, index=True)`
- `subtype` → renamed to `subcategory` (kept nullable)
- `pattern` (String(50)) → drop, replace with `pattern: list[str] | None = mapped_column(ARRAY(String), nullable=True)` (the column will be `pattern_array` in DB until Phase 7's rename)
- Add `occasion_tags: list[str] | None = mapped_column(ARRAY(String), nullable=True)`

⚠️ During Phase 3 (before Phase 7), the **model attribute** `pattern` maps to the **DB column** `pattern_array` via `mapped_column(ARRAY(String), name="pattern_array")`. This lets app code use `item.pattern` as an array right away.

#### 3.2 `backend/app/schemas/catalog.py`
Add new Literal types at the top of the file:
- `CATALOG_SLOTS = Literal["top", ..., "activewear"]` (10 values, copy from old `CATALOG_CATEGORIES`)
- `CATALOG_CATEGORIES = Literal["jeans", ..., "sunglasses"]` (31 values — see `tag_catalog_styles.py:43-72` for canonical names; verify against final vocab in §3 of this doc)
- `CATALOG_PATTERNS = Literal[...]` (18 values)
- `CATALOG_FITS = Literal[...]` (19 values)
- `CATALOG_STYLE_TAGS = Literal[...]` (17 values; copy keys from `tag_catalog_styles.py:STYLE_TAGS`)
- `CATALOG_OCCASION_TAGS = Literal[...]` (13 values; copy keys from `tag_catalog_styles.py:OCCASION_TAGS`)

Update `CatalogItemCreate`, `CatalogItemUpdate`, `CatalogItemResponse`:
- Add `slot: CATALOG_SLOTS`, `category: CATALOG_CATEGORIES | None`, `subcategory: str | None`
- Type `pattern` as `list[CATALOG_PATTERNS] | None`
- Type `fit` as `CATALOG_FITS | None`
- Type `style_tags` as `list[CATALOG_STYLE_TAGS] | None`
- Type `occasion_tags` as `list[CATALOG_OCCASION_TAGS] | None`
- Remove `subtype` field; remove the old `category: CATALOG_CATEGORIES` field (now `slot`).

`CatalogItemResponse` array normalization (the existing `field_validator("color", "style_tags", mode="before")` logic) should also cover `pattern`, `occasion_tags`.

#### 3.3 `backend/app/routers/catalog.py`
Update the `/catalog/search` query parameters at `routers/catalog.py:160-189`:
- Rename `category` → `slot`
- Add `category` (the new garment-type filter)
- Rename `subtype` → `subcategory`
- Add `occasion` (comma-separated, array overlap on `occasion_tags`, mirrors `style` param)
- Add `pattern` (comma-separated, array overlap on `pattern_array`)
- `q` (name search) stays as-is.

Update `/catalog/filter-options` at `routers/catalog.py:113-157`:
- Replace `subtypes` and `subtypes_by_category` with `subcategories` and `subcategories_by_category`.
- Add `slots`, `categories_by_slot` (new map from slot → list of categories observed in that slot), `occasion_tags`, `patterns`.

#### 3.4 `backend/app/models/wardrobe.py` and `backend/app/routers/wardrobe.py`
Apply the same renames/adds to the wardrobe model and wardrobe queries. Migration `0013` should cover BOTH `catalog_items` and `wardrobe_items` in the same migration to keep schema in sync. Backfill (Phase 2) handles wardrobe alongside catalog using the same `taxonomy_maps` module.

#### 3.5 `backend/scripts/import_mango_catalog.py` and `import_bershka_catalog.py`
- Replace `derive_subtype()` with `derive_category()` that returns a value from the controlled vocab using `taxonomy_maps.SLUG_TO_CATEGORY`.
- Set `slot` from the existing slug-based logic the import already performs (current behavior is already slot-correct — the column rename is the only change).
- Drop the old `subtype` field from the upsert dict; replace with `category`, `subcategory=None` (subcategory is filled only by the cleanup pass, not by source slugs).
- Update the `RawMangoRecord` and `RawBershkaRecord` dataclasses to use `category` instead of `subtype`.

#### 3.6 `backend/app/services/claude_service.py` and `gemini_service.py`
The vision tagging prompts at `claude_service.py:15-24` reference `category`/`subtype`. Rewrite the prompt to ask for `slot`/`category`/`subcategory`/`occasion_tags` against the new controlled vocabularies.
- The catalog-styles tagger (`tag_catalog_styles.py`) is already on the new vocab — use it as the reference.
- The wardrobe tagger (called from `routers/wardrobe.py:tag_wardrobe_item`) needs the same prompt update.

#### 3.7 `backend/tests/test_catalog.py`
- Replace `subtype="..."` in test fixtures with `subcategory="..."`
- Add `slot="..."` and `category="..."` to fixtures
- Add new test cases:
  - `test_catalog_search_filters_by_slot` (mirror existing category test)
  - `test_catalog_search_filters_by_category` (new)
  - `test_catalog_search_filters_by_subcategory` (rename existing subtype test)
  - `test_catalog_search_filters_by_occasion`
  - `test_catalog_search_filters_by_pattern_array`

### Doc references to copy from
- `backend/scripts/tag_catalog_styles.py:43-87` — controlled vocab dicts (copy keys for the Literal definitions)
- `backend/app/routers/catalog.py:147-189` — search endpoint pattern (the existing structure stays; only the param names change)
- `backend/tests/test_catalog.py:81-120` — test pattern for filter assertions

### Verification checklist
- [ ] `pytest tests/test_catalog.py -q` — all green
- [ ] `pytest -q` (full suite) — no regressions
- [ ] `python -c "from app.models.catalog import CatalogItem; print(CatalogItem.__table__.columns.keys())"` shows: `id, ref_code, brand, gender, slot, category, subcategory, name, color, pattern, fit, style_tags, occasion_tags, image_*, product_url, clip_embedding, created_at, updated_at`
- [ ] Manual: `curl /catalog/search?slot=top&category=t-shirt` returns expected items
- [ ] Manual: `curl /catalog/filter-options` returns the new shape (`slots`, `categories_by_slot`, `subcategories_by_category`, `patterns`, `occasion_tags`)
- [ ] grep `"subtype"` in `backend/app/` returns zero hits (catalog AND wardrobe both migrated)

### Anti-pattern guards
- ❌ Do **not** ship a "compatibility layer" that accepts old query param names (`category` for slot). Stop-the-world rename is fine for this dev project; backwards-compat in API will outlive its usefulness.
- ❌ Do **not** copy the entire model into the migration file — alembic should use raw SQL in `op.execute` for any data ops, never reference SQLAlchemy classes.
- ❌ Do **not** put the controlled vocabularies in two places — schemas Literals should literally `from app.schemas.catalog import CATALOG_*` in any other code that needs them, OR derive Literal at runtime from a single source dict.

### Rollback
- Revert these code changes in git. Run `alembic downgrade 0012`. App returns to old shape.

---

## Phase 4 — Vision-AI Tagging

**Goal:** Populate `style_tags` and `occasion_tags` for every catalog item using the existing Gemini-based tagger.

### Files (already exist)
- `backend/scripts/tag_catalog_styles.py` — already uses Gemini 3 Flash, the new 17-style / 13-occasion vocabularies, structured output schema. Already loads `backend/.env`.

### Operations
1. **Sample run:** `python -m scripts.tag_catalog_styles --sample 50 --dry-run` — visually spot-check the JSON output for 50 random items. Look for confusion: `clean-girl` vs `minimal`, `old-money` vs `classic`, `wedding-guest` vs `formal`.
2. **Adjust if needed:** if a tag is consistently mis-applied, drop it from `STYLE_TAGS`/`OCCASION_TAGS` in the script + schema Literals + DB CHECK list (Phase 7).
3. **Full run:** `python -m scripts.tag_catalog_styles` — tags all items where `occasion_tags IS NULL`.
4. **Re-run iteratively** as needed with `--retag-all` to overwrite.

### Cost gate
At Gemini 3 Flash placeholder pricing (~$0.15/M input, $0.60/M output), 10K items × ~1500 input tokens × ~50 output tokens ≈ **$2-3 total**. Dry-run sample first to confirm the pricing assumption with the actual response token usage.

### Verification checklist
- [ ] `--sample 50 --dry-run` produces JSON output that passes spot-check (no obvious mistagging)
- [ ] `SELECT COUNT(*) FROM catalog_items WHERE occasion_tags IS NULL` drops to 0 (or an explicable small number due to image-fetch failures)
- [ ] `SELECT DISTINCT unnest(style_tags) FROM catalog_items` returns only values in the 17-tag vocab
- [ ] Failures log written; manually review any items with `image_fetch:` errors

### Anti-pattern guards
- ❌ Do **not** run on the full corpus before validating sample quality. Wasted money + wasted time if the vocab needs adjustment.
- ❌ Do **not** disable the structured-output schema — defense-in-depth keeps tag pollution out.

### Rollback
- `UPDATE catalog_items SET style_tags = NULL, occasion_tags = NULL` — clears both columns. Re-run tagger when ready.

---

## Phase 5 — Admin Frontend Update

**Goal:** Update Next.js admin to use new field names and surface new filters.

### Files to modify

#### 5.1 `admin/src/app/catalog/page.js`
Lines to update:
- `FILTER_FIELDS` (lines 22-30): replace with the new shape:
  ```js
  const FILTER_FIELDS = [
      { key: "slot",         label: "Slot",        optionsKey: "slots" },
      { key: "category",     label: "Category",    optionsKey: "__categories_by_slot" },
      { key: "subcategory",  label: "Subcategory", optionsKey: "__subcategories_by_category" },
      { key: "brand",        label: "Brand",       optionsKey: "brands" },
      { key: "gender",       label: "Gender",      optionsKey: "genders" },
      { key: "color",        label: "Color",       optionsKey: "colors" },
      { key: "pattern",      label: "Pattern",     optionsKey: "patterns" },
      { key: "style",        label: "Style",       optionsKey: "style_tags" },
      { key: "occasion",     label: "Occasion",    optionsKey: "occasion_tags" },
      { key: "fit",          label: "Fit",         optionsKey: "fits" },
  ];
  ```
- `CatalogFilters` cascading logic (lines 32-84): extend `handleFilterChange` to handle slot→category→subcategory cascade (resetting `category` and `subcategory` when slot changes; resetting `subcategory` when category changes).
- Cell width: 10 filters in `grid-cols-2 md:grid-cols-3 lg:grid-cols-7` no longer fits — bump to `lg:grid-cols-5` and let it wrap.
- `EMPTY_FORM` (line 65): replace `category` → `slot, category`, replace `subtype` → `subcategory`.
- Form fields (lines 253-288): same replacements.

#### 5.2 `admin/src/app/tryon/page.js` (the actual playground page)
- Same `FILTER_FIELDS` and cascading-logic changes as 5.1.

#### 5.3 `admin/src/app/wardrobe/page.js`
- Form fields (lines 325-342): replace `category` → `slot, category`, `subtype` → `subcategory`.
- Tag-result display (lines 281-292) and table cells (lines 220-226): show `slot` + `category` + `subcategory`.

#### 5.4 `admin/src/lib/api.js`
- `searchCatalog` (lines 91-96): no code change — function passes params as-is. Just confirm callers send new param names.
- `createCatalogItem` / `updateCatalogItem`: same — they pass body as-is.

### Doc references to copy from
- `admin/src/app/catalog/page.js:32-84` — existing CatalogFilters cascading pattern (extend, don't rewrite)

### Verification checklist
- [ ] `cd admin && npm run build` (or `next build`) — no TypeScript/lint errors
- [ ] In dev: `/catalog` page loads, all 10 filter dropdowns show, picking a slot narrows category, picking a category narrows subcategory
- [ ] In dev: `/tryon` page loads with same filter behavior
- [ ] In dev: `/wardrobe` page loads with new fields and create/tag flow works
- [ ] Form submission: creating a catalog item with `slot=top, category=t-shirt` succeeds and round-trips correctly

### Anti-pattern guards
- ❌ Do **not** keep `category` field referencing the old slot semantics. Every place that currently uses `category` to mean "top/bottom/dress" must change to `slot`.
- ❌ Do **not** add a backward-compat layer in `api.js` — the API itself isn't keeping old param names per Phase 3 anti-patterns.

### Rollback
- `git revert` on the admin/ changes. Phase 1 → Phase 4 backend stays in place; admin would just have stale field references but a `git revert` brings everything back together.

---

## Phase 6 — Mobile Update

**Goal:** Update Flutter mobile to use new field names. This phase has the most surface-area files.

### Files to modify

#### 6.1 `mobile/lib/core/models/catalog_item.dart`
Replace the freezed factory:
```dart
const factory CatalogItem({
  required String id,
  required String brand,
  required String slot,
  String? category,
  String? subcategory,
  required String name,
  required List<String> color,
  @JsonKey(name: 'pattern') List<String>? pattern,
  String? fit,
  @JsonKey(name: 'style_tags') required List<String> styleTags,
  @JsonKey(name: 'occasion_tags') required List<String> occasionTags,
  @JsonKey(name: 'image_url') required String imageUrl,
  @JsonKey(name: 'product_url') String? productUrl,
}) = _CatalogItem;
```
Then run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate freezed/JSON files.

#### 6.2 `mobile/lib/core/models/catalog_filter_options.dart`
- Add fields: `slots`, `categoriesBySlot`, `subcategoriesByCategory`, `patterns`, `occasionTags`.
- Remove: `subtypes`, `subtypesByCategory`.
- Update `fromJson` accordingly.

#### 6.3 `mobile/lib/features/tryon/models/garment_category_filter.dart`
- The existing `GarmentCategoryFilter` struct currently maps mobile labels to backend `category` values like `'top'`, `'bottom'`. Rename the field `backendCategory` → `backendSlot`.
- Update `garmentCategoryForBackendCategory` → `garmentCategoryForBackendSlot`.
- Update `garmentCategoryForSlotType` to set `backendSlot` (was `backendCategory`).

#### 6.4 `mobile/lib/features/tryon/ui/widgets/item_browser_sheet.dart`
This is the big one (898 lines). Walk through:
- All references to `_selectedCategory.backendCategory` → `_selectedCategory.backendSlot`.
- All `subtype` state vars → `subcategory`. State vars: `_selectedSubtype` → `_selectedSubcategory`.
- `subtypesByCategory` → `subcategoriesByCategory`.
- `_availableSubtypeOptions` getter (lines 82-90) → `_availableSubcategoryOptions`.
- Add new state for `_selectedCategory` (the garment-type filter, distinct from the slot chips at the top), `_selectedPatterns: List<String>`, `_selectedOccasion: String?`.
- Filter dropdown (line 743-770): rename "Subtype" label to "Subcategory", add "Category" dropdown (cascades from slot), add "Pattern" multi-select, add "Occasion" dropdown.
- `searchPage` call (lines 156-167): update query parameter names to `slot`, `category`, `subcategory`, `pattern`, `occasion`.

#### 6.5 `mobile/lib/features/discover/data/catalog_repository.dart`
Lines 36, 50, 79: rename query param keys:
- `'category'` → `'slot'`
- `'subtype'` → `'subcategory'`
- Add params: `category` (the garment-type filter, as `String?`), `pattern` (`String?` comma-joined), `occasion` (`String?`).

#### 6.6 `mobile/lib/features/tryon/providers/styling_canvas_provider.dart`
Lines 119-168: the canvas constructs `CatalogItem` from a wardrobe item or URL. Update to set `slot` (was `category`), set `category=null`, `subcategory=null`. The `_wardrobeItemName` fallback (line 392) should use `subcategory ?? slot` (was `subtype ?? category`).

#### 6.7 `mobile/lib/features/wardrobe/*` and `mobile/lib/core/models/wardrobe_item.dart`
- `wardrobe_item.dart` model: same renames as `catalog_item.dart` (slot/category/subcategory/occasion_tags + freezed regen).
- `tag_confirmation_sheet.dart`, `wardrobe_item_card.dart`, `wardrobe_item_detail_screen.dart`, `wardrobe_browser_sheet.dart`: update field references.

#### 6.8 `mobile/lib/core/api/api_endpoints.dart`
No path changes needed — only query params changed (handled in 6.5).

#### 6.9 `mobile/test/features/tryon/item_browser_sheet_test.dart`
Update the test to use new field names.

### Doc references to copy from
- `backend/scripts/tag_catalog_styles.py:43-87` — controlled vocabulary keys (mobile may want to mirror these client-side for filter dropdowns IF the filter-options API endpoint isn't sufficient)
- `mobile/lib/features/tryon/ui/widgets/item_browser_sheet.dart` (post-merge state) — existing cascading filter pattern

### Verification checklist
- [ ] `cd mobile && flutter analyze` — zero issues on changed files
- [ ] `flutter pub run build_runner build --delete-conflicting-outputs` — regenerates freezed/g.dart cleanly
- [ ] `flutter test` — all tests pass
- [ ] `flutter run` on simulator: catalog browse opens, filters work, slot→category→subcategory cascade behaves correctly
- [ ] Outfit Try-On flow still works (slot-level outfit composition unchanged in semantics)
- [ ] grep `"subtype"` in `mobile/lib/` returns zero hits (catalog AND wardrobe both migrated)

### Anti-pattern guards
- ❌ Do **not** keep both `category` and `slot` aliasing the same field on mobile — pick `slot` everywhere semantically slot-level lives.
- ❌ Do **not** forget to regenerate freezed — manual edits to `catalog_item.freezed.dart` don't survive a regen.

### Rollback
- `git revert` mobile changes. Mobile and backend will mismatch (mobile expects old fields, backend returns new) — this is a tightly coupled phase; rollback only makes sense as part of a full Phase 1-7 revert.

---

## Phase 7 — Finalization Migration

**Goal:** Lock in the schema with NOT NULL, CHECK constraints, finalize the `pattern` column type change, and create the new GIN indexes.

### Files to create
- `backend/alembic/versions/0014_catalog_taxonomy_finalize.py`

### Operations (in order)
1. **NOT NULL on `slot`** (already non-null from rename in Phase 1; verify and assert).
2. **Drop old `pattern` scalar column.**
3. **Rename `pattern_array` → `pattern`** (`op.alter_column(... new_column_name="pattern")`).
4. **CHECK constraints** (use `op.create_check_constraint`):
   - `ck_catalog_items_slot` — slot IN (10 values)
   - `ck_catalog_items_category` — category IN (31 values) OR category IS NULL
   - For arrays (`pattern`, `style_tags`, `occasion_tags`), CHECK constraints don't apply directly to array elements in standard Postgres. Use a **trigger** or **CHECK with `<@` (subset)**:
     ```sql
     ALTER TABLE catalog_items ADD CONSTRAINT ck_catalog_items_pattern_vocab
       CHECK (pattern IS NULL OR pattern <@ ARRAY['plain','striped',...]::text[]);
     ```
   - Same for `style_tags <@ ARRAY[17 values]`, `occasion_tags <@ ARRAY[13 values]`.
   - `ck_catalog_items_fit` — fit IN (19 values) OR fit IS NULL.
5. **GIN indexes** for the array columns that don't already have them:
   - `ix_catalog_items_pattern_gin` (NEW since pattern is now array)
   - `ix_catalog_items_occasion_tags_gin` (NEW)
   - `style_tags` already has GIN from migration 0005
6. **Index** on the new `category` column (B-tree).

### Doc references to copy from
- `backend/alembic/versions/0009_add_user_role_column.py:37-41` — `op.create_check_constraint` pattern
- `backend/alembic/versions/0005_catalog_filter_indexes.py:27-36` — GIN index creation via `op.execute`

### Verification checklist
- [ ] `alembic upgrade head` runs cleanly
- [ ] `alembic downgrade -1` reverses the migration
- [ ] In Postgres: `\d catalog_items` shows all CHECK constraints, all GIN/B-tree indexes
- [ ] Insert test: `INSERT INTO catalog_items (slot, name, brand, image_front_url) VALUES ('not-a-slot', 'x', 'x', 'x')` raises CHECK violation
- [ ] Insert test: `INSERT INTO catalog_items (slot, name, brand, image_front_url, pattern) VALUES ('top', 'x', 'x', 'x', ARRAY['not-a-pattern'])` raises CHECK violation
- [ ] `pytest -q` — all tests still green (CHECK constraints in test SQLite are no-ops since SQLite uses different syntax — test expectations should not assume CHECK enforcement in SQLite)

### Anti-pattern guards
- ❌ Do **not** add CHECK constraints before backfill is complete (Phase 2). Existing polluted data will violate them and the migration fails.
- ❌ Do **not** use Postgres ENUM types — the codebase pattern is CHECK constraints (per migration `0009`).
- ❌ Do **not** make `category` NOT NULL — per locked-in answer #3, un-mappable items keep `category=NULL` for manual review.

### Rollback
- `alembic downgrade 0013`. Removes constraints, restores scalar `pattern`. Then `alembic downgrade 0012` (Phase 1 rollback) if a full revert is needed.

---

## Phase 8 — Verification & Cleanup

**Goal:** End-to-end verification + fix-up of stragglers.

### Operations

1. **Cross-project grep**: `grep -rn "subtype" backend/ admin/src/ mobile/lib/` should return zero — catalog AND wardrobe are both migrated.
2. **Cross-project grep** for old query param: `"category"` as a query param should now refer to garment-type, not slot. Audit `searchCatalog` callers and curl/postman collections.
3. **Postman collection** (`backend/postman/outfitter-catalog.postman_collection.json`): update saved query params and example bodies.
4. **Docs cleanup**:
   - Update `docs/PRD.md` if it references the old taxonomy.
   - Update `docs/general-technical-implementation.md` and `docs/flutter-technical.md`.
   - `docs/catalog-items-structure-review.md` may need a note pointing at this refactor as the resolution.
5. **Re-tag spot check**: pick 20 random catalog items, view in admin, confirm slot/category/subcategory all sensible.
6. **Mobile smoke**: outfit creation flow end-to-end on simulator.
7. **AI tagging service**: confirm wardrobe `/wardrobe/tag` endpoint returns the new shape with slot/category/subcategory/occasion_tags.

### Verification checklist (master)
- [ ] `pytest -q` all green
- [ ] `flutter analyze` zero issues
- [ ] `npm run build` (admin) succeeds
- [ ] Postman collection updated
- [ ] No grep hits for `subtype` in scope-relevant code
- [ ] Manual smoke: create catalog item via admin → appears in mobile catalog browse → can be picked into outfit slot
- [ ] Cost report: total Gemini API spend matches projection (within ±50%)

### Anti-pattern guards
- ❌ Do **not** declare done if any phase's verification checklist has failures.
- ❌ Do **not** push to `main` without explicit user authorization (per project CLAUDE.md).

---

## Appendix A — Slug → Category Mapping Table

(From discovery agent #2; reuse in `backend/scripts/taxonomy_maps.py`)

### High confidence (1:1)

| Source slug | category | Brand(s) |
|---|---|---|
| `t-shirts` | t-shirt | Mango M/W, Bershka M/W |
| `jeans` | jeans | Mango M/W, Bershka M/W |
| `trousers` | trousers | Bershka M/W |
| `pants` | trousers | Mango M/W (normalized) |
| `shorts` | shorts | Mango W, Bershka M/W |
| `skirts` | skirt | Mango W, Bershka W |
| `blazers` | blazer | Mango M/W |
| `coats` | coat | Mango M/W |
| `jackets` | jacket | Mango M/W, Bershka W |
| `polos` | polo | Mango M |
| `shirts` | shirt | Mango M/W, Bershka M |
| `sweaters` | sweater | Bershka W |
| `sweatshirts` | sweatshirt | Mango M |
| `dresses` | dress | Bershka W |
| `bags` | bag | Bershka W |
| `vests` | vest | Mango W |
| `cardigans` | cardigan | Bershka W |
| `bodysuits` | bodysuit | Bershka W |

### Medium confidence (heuristic)

| Source slug | category | Reasoning |
|---|---|---|
| `sweaters-and-cardigans` | sweater | Default to dominant; refine with name keywords if needed |
| `jackets-and-coats` | jacket | Default; could split via `("coat" in name → coat)` |
| `sweatshirts-and-hoodies` | hoodie | Hoodie is more specific subset |
| `overshirts` | shirt | Subtype of shirt |
| `shirts---blouses` | blouse | (Mango W) — gender-keyed: women → blouse |
| `shirts-and-blouses` | shirt | (Bershka W) — pending Q2 resolution |
| `tops` | t-shirt | Default for generic "top" container |
| `tops-and-bodies` | t-shirt | Default; bodysuit detection optional |
| `shoes` | sneakers | Broad — refine with name keywords (boots/heels/sandals) |
| `gilets` | vest | Sleeveless outerwear |
| `trench-coats` | trench-coat | Direct |
| `trench-coats-and-parkas` | trench-coat | Default; parka can map to coat |
| `baggy-trousers` | trousers | Subset |

### Ambiguous (Q3 resolution required)

| Source slug | Pending decision |
|---|---|
| `dresses-and-jumpsuits` | Default `dress` OR name-keyword split (recommend keyword) |
| `skirts-and-shorts` | Default `shorts` OR name-keyword split (recommend keyword) |

### Skip (out-of-vocab)

| Source slug | Reason |
|---|---|
| `accessories` | Too broad; spans bag/belt/cap/scarf etc. — leave NULL |
| `leather` | Material, not category |
| `linen` | Material, not category |
| `swimwear` | Out-of-vocab |
| `bikinis-and-swimsuits` | Out-of-vocab |
| `pajamas` | Out-of-vocab |
| `underwear` | Out-of-vocab |
| `tracksuit` | Specialized sportswear |

### Stradivarius name-keyword rules (most-specific first)

```
("polo shirt", "polo")
("tank top", "tank-top"), ("tank-top", "tank-top"), ("bandeau", "tank-top"), ("camisole", "tank-top")
("bodysuit", "bodysuit")
("sweatshirt", "sweatshirt")
("jumper", "sweater"), ("sweater", "sweater"), ("turtleneck", "t-shirt")
("cardigan", "cardigan")
("blouse", "blouse")
("shirt", "shirt")
("t-shirt", "t-shirt"), ("tshirt", "t-shirt")
("jeans", "jeans"), ("denim", "jeans")
("trousers", "trousers")
("shorts", "shorts")
("skirt", "skirt")
("dress", "dress"), ("jumpsuit", "jumpsuit")
("jacket", "jacket"), ("coat", "coat"), ("parka", "coat")
("trainers", "sneakers"), ("sneakers", "sneakers"), ("shoes", "sneakers")
("boots", "boots"), ("boot", "boots")
("heels", "heels"), ("sandals", "sandals")
("bag", "bag"), ("belt", "belt")
("cap", "cap"), ("hat", "cap"), ("balaclava", None)
("sunglasses", "sunglasses"), ("glasses", "sunglasses")
("scarf", "scarf")
# Last-resort fallback
("top", "t-shirt")
```

---

## Appendix B — Subtype → {subcategory, fit, pattern} Cleanup Remap

(Applied during Phase 2.2)

### Rule order
1. Lowercase + strip the source value
2. Apply the rules below in this order; first match wins

### Rules

| Source value contains | Action |
|---|---|
| Any `pattern` vocab term (`striped`, `floral`, `plaid`, `checkered`, `embroidered`, `sequined`, `polka-dot`, `tie-dye`, `paisley`, `geometric`, `animal-print`, `camouflage`, `gradient`, `graphic`, `logo`, `abstract`, `color-blocked`) | Append to `pattern_array`; clear `subcategory` |
| Any `fit` vocab term (`slim`, `skinny`, `regular`, `relaxed`, `oversized`, `loose`, `straight`, `mom`, `wide-leg`, `flare`, `bootcut`, `balloon`, `baggy`, `bodycon`, `a-line`, `shift`, `fit-and-flare`, `cropped`, `tapered`) | Set `fit` (only if currently NULL); clear `subcategory` |
| Any `category` vocab term (`shirt`, `t-shirt`, `polo`, etc.) | Move to `category` if `category` is NULL; clear `subcategory` |
| Any "garment-type" subcategory term (e.g., `oxford`, `henley`, `mini`, `midi`, `maxi`, `crew-neck`, `v-neck`, `bomber`, `denim-jacket`, `puffer`) | Keep in `subcategory` |
| Sleeve-length descriptors (`short sleeve`, `long sleeve`, `sleeveless`, `short sleeved`) | Append to `pattern` as informational? **Decision:** drop — not a pattern, not a fit. Clear `subcategory`. |
| Anything else (`tops and bodies`, `shirts blouses`, brand-promo strings, etc.) | Clear `subcategory` (set NULL) |

### Implementation note
The remap rules table belongs in `backend/scripts/taxonomy_maps.py:SUBTYPE_REMAP_RULES` so backfill and any future cleanup script reuse it.

---

## Appendix C — Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Backfill leaves many `category=NULL` rows due to vocab gaps | HIGH | MEDIUM | `--report-unmapped` mode; manual cleanup via admin UI; `category` stays nullable per Q3 |
| R2 | Vision-AI mistags items consistently for borderline aesthetics (e.g., `clean-girl` vs `minimal`) | MEDIUM | LOW | Phase 4 sample run + spot-check before full run; drop confused tags from vocab if needed |
| R3 | Postgres CHECK constraint syntax doesn't run on SQLite test DB | HIGH | LOW | Tests don't enforce CHECK in SQLite anyway; just skip CHECK assertions in test code. Migration's `op.execute` for CHECK should be wrapped in dialect guard. |
| R4 | Mobile freezed regen breaks unrelated models | LOW | MEDIUM | Run `--delete-conflicting-outputs` and review the diff; commit `*.freezed.dart` and `*.g.dart` deltas separately for review |
| R5 | Wardrobe migration changes break user-uploaded items not yet AI-tagged | LOW | MEDIUM | Backfill applies to wardrobe table same as catalog; existing rows preserved; new rows go through updated AI prompts |
| R6 | `pattern` scalar→array rename breaks any code that does `item.pattern` as a string | MEDIUM | HIGH | grep all usages; covered in Phase 3 (model) and Phase 6 (mobile). Test with explicit type checks. |
| R7 | Existing tests in `tests/test_catalog.py` use old field names; updates miss a case | MEDIUM | LOW | Run full suite; new tests added in Phase 3 explicitly cover renamed fields |
| R8 | Backfill non-idempotent — re-running corrupts `pattern_array` by re-appending | MEDIUM | MEDIUM | Phase 2 spec: idempotent. Use `WHERE NOT EXISTS` or compute final array in a subquery; never blindly append. |
| R9 | Source JSON schema changes between scrape and backfill (new slugs appear) | LOW | MEDIUM | `--report-unmapped` flags new slugs; map updated and re-run |
| R10 | Mobile build fails because old `subtype` field referenced in some untouched test/widget | MEDIUM | LOW | grep `mobile/` for `subtype` after Phase 6 changes; expect zero hits |
| R11 | Admin's `tryon` page was renamed from `playground` in main; not all team members know | LOW | LOW | Plan now references the correct path |
| R12 | Vision-AI cost overrun if catalog grows beyond expectation | LOW | LOW | Tagger is rate-limit-aware (concurrency=10); cost report at end of each run |

---

## Appendix D — Files Touched (Master List)

### Backend
- `backend/alembic/versions/0013_catalog_taxonomy_split.py` (NEW)
- `backend/alembic/versions/0014_catalog_taxonomy_finalize.py` (NEW)
- `backend/scripts/taxonomy_maps.py` (NEW — slug→category, subtype remap, fit normalization)
- `backend/scripts/backfill_catalog_taxonomy.py` (NEW)
- `backend/app/models/catalog.py` (modified)
- `backend/app/schemas/catalog.py` (modified — new Literals)
- `backend/app/routers/catalog.py` (modified — new query params)
- `backend/scripts/import_mango_catalog.py` (modified — derive_subtype → derive_category)
- `backend/scripts/import_bershka_catalog.py` (modified — same)
- `backend/scripts/tag_catalog_styles.py` (already on new vocab — no changes needed)
- `backend/app/services/claude_service.py` (modified — new prompt)
- `backend/app/services/gemini_service.py` (modified — same)
- `backend/tests/test_catalog.py` (modified — rename + add tests)
- `backend/tests/test_wardrobe.py` (modified — same patterns as catalog tests)
- `backend/app/models/wardrobe.py` (modified — same column changes as catalog)
- `backend/app/schemas/wardrobe.py` (modified — new Literals)
- `backend/app/routers/wardrobe.py` (modified — query params updated)

### Admin (Next.js)
- `admin/src/app/catalog/page.js` (modified)
- `admin/src/app/tryon/page.js` (modified — note: this is the "playground" page)
- `admin/src/app/wardrobe/page.js` (modified)
- `admin/src/lib/api.js` (no code changes; verify call sites)

### Mobile (Flutter)
- `mobile/lib/core/models/catalog_item.dart` (modified)
- `mobile/lib/core/models/catalog_item.freezed.dart` (regenerated)
- `mobile/lib/core/models/catalog_item.g.dart` (regenerated)
- `mobile/lib/core/models/catalog_filter_options.dart` (modified)
- `mobile/lib/features/tryon/models/garment_category_filter.dart` (modified)
- `mobile/lib/features/tryon/ui/widgets/item_browser_sheet.dart` (modified — large)
- `mobile/lib/features/discover/data/catalog_repository.dart` (modified)
- `mobile/lib/features/tryon/providers/styling_canvas_provider.dart` (modified)
- `mobile/test/features/tryon/item_browser_sheet_test.dart` (modified)
- `mobile/lib/core/models/wardrobe_item.dart` (modified, freezed regenerated)
- `mobile/lib/features/wardrobe/ui/widgets/tag_confirmation_sheet.dart` (modified)
- `mobile/lib/features/wardrobe/ui/widgets/wardrobe_item_card.dart` (modified)
- `mobile/lib/features/wardrobe/ui/wardrobe_item_detail_screen.dart` (modified)
- `mobile/lib/features/tryon/ui/widgets/wardrobe_browser_sheet.dart` (modified)

### Docs / Postman
- `backend/postman/outfitter-catalog.postman_collection.json` (modified)
- `docs/PRD.md` (potentially)
- `docs/general-technical-implementation.md` (potentially)
- `docs/flutter-technical.md` (potentially)
- `docs/catalog-items-structure-review.md` (mark resolved)

---

## Appendix E — Test Plan

### Unit tests (backend)
- Migration upgrade/downgrade reversibility
- `taxonomy_maps.SLUG_TO_CATEGORY` covers all known slugs
- `derive_category` returns expected value for known input slugs
- Pydantic validators reject out-of-vocab values
- `/catalog/search` filters by each new param

### Integration tests (backend)
- End-to-end: POST `/catalog/items` with new shape, GET `/catalog/items/{id}` returns same shape
- `/catalog/filter-options` returns valid new schema
- Backfill script idempotency: run twice, assert no change on second run

### Manual smoke (full stack)
- Admin: Create catalog item → search by slot → search by category → cascading dropdowns work
- Mobile: Open catalog browse → filter by slot, category, subcategory, occasion → outfit composition uses correct slot

### Cost guardrail (Phase 4)
- Sample 50 runs cost < $0.10
- Full corpus ~10K items < $5

---

## Execution Readiness

All blocking decisions resolved (see §0.1 and §1). Each phase is now ready to be executed in a fresh chat with this doc as the sole brief.

**Recommended execution order:** Phase 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8. Phases 5 and 6 (admin and mobile) can run in parallel once Phase 3 is complete since they're independent codebases. Phase 4 (vision-AI tagging) requires Phase 1+2+3 done so that the `occasion_tags` column exists and the Pydantic Literals match.
