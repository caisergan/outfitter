# Catalog Taxonomy Refactor — Execution Status

**Companion to:** `docs/plans/2026-05-01-catalog-taxonomy-refactor.md` (the plan)
**Last updated:** 2026-05-02
**Branch:** `refactor/backend-catalog-items-improvements`

This is the live progress + handoff doc. The plan is the design; this file is what's actually been built and what's still pending.

---

## Status at a Glance

| Phase | What | Status | Where |
|---|---|---|---|
| 1 | Schema migration (additive, allow NULL, both tables) | ✅ written, ❌ not applied | `backend/alembic/versions/0013_catalog_and_wardrobe_taxonomy_split.py` |
| 2 | Data backfill (category from JSON, subcategory cleanup, pattern_array, fit normalize) | ✅ written, ❌ not run | `backend/scripts/backfill_catalog_taxonomy.py` + `backend/scripts/taxonomy_maps.py` |
| 3 | Backend code refactor (model, schemas, router, services, tests) | ✅ written + ✅ all 102 tests pass | see §Phase 3 Files below |
| 4 | Vision-AI tagging (style_tags + occasion_tags via Gemini 3 Flash) | ✅ written, ❌ not run | `backend/scripts/tag_catalog_styles.py` |
| 5 | Admin frontend (Next.js) refactor | ❌ NOT WRITTEN | `admin/src/app/{catalog,tryon,wardrobe}/page.js` + `admin/src/lib/api.js` |
| 6 | Mobile frontend (Flutter) refactor | ❌ NOT WRITTEN | `mobile/lib/...` (~10 files; see plan Appendix D) |
| 7 | Finalization migration (`0014`) — NOT NULL, CHECK constraints, drop scalar `pattern`, rename `pattern_array → pattern`, GIN indexes | ❌ NOT WRITTEN | `backend/alembic/versions/0014_catalog_taxonomy_finalize.py` |
| 8 | Cross-project verification + cleanup (Postman, docs) | ❌ NOT DONE | various |

---

## Phase 3 Files (completed)

All files in `backend/`. Every modification verified by `pytest -q` → 102 passed.

### Models
- `app/models/catalog.py` — `slot` (renamed from category), `category` (NEW, garment-type), `subcategory` (renamed from subtype), `pattern: list[str]` mapped to DB column `pattern_array`, `occasion_tags`
- `app/models/wardrobe.py` — same shape

### Schemas
- `app/schemas/catalog.py` — 6 controlled `Literal` types (`CATALOG_SLOT`, `CATALOG_CATEGORY`, `CATALOG_PATTERN`, `CATALOG_FIT`, `CATALOG_STYLE_TAG`, `CATALOG_OCCASION_TAG`); import-time sync check vs `scripts.taxonomy_maps`; legacy alias `CATALOG_CATEGORIES = CATALOG_SLOT` retained until Phase 7
- `app/schemas/wardrobe.py` — imports the catalog Literals; `WardrobeTagResponse` matches the AI tagger payload

### Routers
- `app/routers/catalog.py` — `/catalog/search` accepts `slot`, `category`, `subcategory`, `pattern`, `occasion`, `style`, `color`, `gender`, `brand`, `fit`, `q`; `/catalog/filter-options` returns `slots`, `categories`, `subcategories`, `patterns`, `occasion_tags`, `categories_by_slot`, `subcategories_by_category`
- `app/routers/wardrobe.py` — list filter has `slot` AND `category` (split); create wires all new fields including `occasion_tags`
- `app/routers/outfits.py` — `items_json` builder for `claude_suggest` emits `slot`, `category`, `subcategory`, `pattern`, `occasion_tags`

### AI services
- `app/services/gemini_service.py` — wardrobe tagger uses `response_schema` with the 6 enum vocabularies; defense-in-depth post-validation; falls back gracefully on errors
- `app/services/claude_service.py` — `TAGGING_PROMPT` + `SUGGEST_PROMPT` reference new field names; `tag_wardrobe_item()` is legacy/fallback

### Import scripts
- `scripts/import_mango_catalog.py` — `SLUG_TO_SLOT_MAP` (renamed from `CANONICAL_CATEGORY_MAP`), `derive_category()` via `taxonomy_maps.resolve_category` (with gender-keyed blouse rule + name-keyword pass for jumpsuit/skirt), `derive_fit()` normalizes against vocab, `_normalize_for_fit` from taxonomy_maps; idempotent upserts that don't clobber existing `category` values
- `scripts/import_bershka_catalog.py` — same patterns

### Tests
- `tests/test_catalog.py` — rewritten with new field names; new tests `test_catalog_search_filters_by_slot`, `_by_category`, `_by_subcategory`, `_by_occasion_array_members`; vocabulary sync test `test_schema_vocab_in_sync_with_taxonomy_maps`
- `tests/test_tryon.py` — `_seed_item` fixture uses new fields

---

## How to Execute What's Already Written

```bash
# 1. Apply Phase 1 schema migration (writes new DB columns, renames old ones)
cd backend
alembic upgrade head

# 2. Phase 2 backfill — populate the new columns from existing data + source JSON
python -m scripts.backfill_catalog_taxonomy category --dry-run --report-unmapped
# review unmapped slugs, then:
python -m scripts.backfill_catalog_taxonomy all

# 3. Phase 4 vision-AI tagging — populate style_tags + occasion_tags
# Sample 50 first to spot-check tag quality:
python -m scripts.tag_catalog_styles --sample 50 --dry-run
# Then full run:
python -m scripts.tag_catalog_styles
```

**⚠️ Phase 5 (admin) and Phase 6 (mobile) MUST happen before either UI works against the new schema.** The backend is ready; clients aren't.

**⚠️ Phase 7 (`0014`) MUST happen at the end** to drop the legacy scalar `pattern` column and rename `pattern_array → pattern`, plus add CHECK constraints. Without it, the DB stays in a transitional shape.

---

## Phase 5 — Admin (Next.js) — NOT WRITTEN

**Files to modify** (all under `admin/src/`):

| File | What changes |
|---|---|
| `app/catalog/page.js` | `FILTER_FIELDS` array — add `slot`, split off `category` (garment type), rename `subtype → subcategory`, add `occasion`, `pattern`. `CatalogFilters` cascade: slot → category → subcategory. `EMPTY_FORM` and form fields: `category → slot, category`; `subtype → subcategory`. |
| `app/tryon/page.js` | Same `FILTER_FIELDS` + cascade as catalog (the file has its own copy). |
| `app/wardrobe/page.js` | Form fields: `category → slot, category`, `subtype → subcategory`. AI-tag result display + table cells: show `slot + category + subcategory`. |
| `lib/api.js` | No code changes needed — passes params through. Verify call sites send new param names. |

**Open layout question:** filter row goes from 7 fields to 10 (slot, category, subcategory, brand, gender, color, pattern, style, occasion, fit) — current `lg:grid-cols-7` no longer fits. Bump to `lg:grid-cols-5` and let it wrap, or split into two rows.

**Verification:**
```bash
cd admin && npm run build      # zero TS/lint errors
# In dev: /catalog, /tryon, /wardrobe load; cascade behaves correctly
```

---

## Phase 6 — Mobile (Flutter) — NOT WRITTEN

**Files to modify** (all under `mobile/lib/`):

| File | What changes |
|---|---|
| `core/models/catalog_item.dart` | Freezed model: `category → slot`, add `category`, `subtype → subcategory`, `pattern → List<String>?`, add `occasionTags`. Run `flutter pub run build_runner build --delete-conflicting-outputs`. |
| `core/models/catalog_filter_options.dart` | Add `slots`, `categoriesBySlot`, `subcategoriesByCategory`, `patterns`, `occasionTags`. Remove `subtypes`, `subtypesByCategory`. |
| `features/tryon/models/garment_category_filter.dart` | Rename `backendCategory → backendSlot`. Update `garmentCategoryForBackendCategory → garmentCategoryForBackendSlot`. |
| `features/tryon/ui/widgets/item_browser_sheet.dart` | All `_selectedCategory.backendCategory → backendSlot`. State `_selectedSubtype → _selectedSubcategory`. Add `_selectedCategory` (garment-type), `_selectedPatterns: List<String>`, `_selectedOccasion: String?`. Filter dropdown: rename "Subtype" label, add "Category", "Pattern" (multi-select), "Occasion". Search params updated. |
| `features/discover/data/catalog_repository.dart` | `searchPage` query keys: `category → slot`, `subtype → subcategory`, add `category`, `pattern`, `occasion`. |
| `features/tryon/providers/styling_canvas_provider.dart` | `addGarmentFromUrl`/`addWardrobeGarment` set `slot=`, `category=null`, `subcategory=null`. `_wardrobeItemName` uses `subcategory ?? category ?? slot`. |
| `core/models/wardrobe_item.dart` | Same renames; regenerate freezed. |
| `features/wardrobe/ui/widgets/{tag_confirmation_sheet,wardrobe_item_card}.dart` and `wardrobe_item_detail_screen.dart` | Update field references. |
| `features/tryon/ui/widgets/wardrobe_browser_sheet.dart` | Same. |

**Verification:**
```bash
cd mobile && flutter analyze   # zero issues
flutter test
flutter run                    # smoke-test catalog browse + outfit composition
```

---

## Phase 7 — Finalization Migration (`0014`) — NOT WRITTEN

**File:** `backend/alembic/versions/0014_catalog_taxonomy_finalize.py`

**Operations** (in order, on BOTH `catalog_items` and `wardrobe_items`):
1. Verify `slot` column has no NULL values (assert from migration); add NOT NULL if not already.
2. Drop the legacy scalar `pattern` column.
3. Rename `pattern_array → pattern` via `op.alter_column(... new_column_name="pattern")`.
4. CHECK constraints (`op.create_check_constraint`):
   - `ck_<table>_slot` — slot IN (10 values)
   - `ck_<table>_category` — `category IN (31 values) OR category IS NULL`
   - `ck_<table>_fit` — `fit IN (19 values) OR fit IS NULL`
   - For arrays (`pattern`, `style_tags`, `occasion_tags`), use `<@` subset CHECK against an array literal of allowed values.
5. GIN indexes:
   - `ix_<table>_pattern_gin` (NEW, since pattern is now array)
   - `ix_<table>_occasion_tags_gin` (NEW)
   - `style_tags` already has GIN from migration `0005`
6. B-tree index on the new `category` column.

**After this lands, also remove from `app/schemas/catalog.py`:**
- The legacy aliases at the bottom (`CATALOG_CATEGORIES = CATALOG_SLOT`, `CATALOG_GENDERS = CATALOG_GENDER`)
- The `name="pattern_array"` argument from the model `pattern` field (since DB column is now actually `pattern`)

---

## Phase 8 — Verification + Cleanup — NOT DONE

- `grep -rn "subtype" backend/ admin/src/ mobile/lib/` → expect zero hits (excluding inline doc comments)
- `backend/postman/outfitter-catalog.postman_collection.json` — update saved query params and example bodies
- `docs/PRD.md`, `docs/general-technical-implementation.md`, `docs/flutter-technical.md` — update if they describe the old taxonomy
- `docs/catalog-items-structure-review.md` — note as resolved by this refactor

---

## Open Questions / Notes

- **Vision-AI sample run before full corpus:** Phase 4's tagger is set up to run Gemini 3 Flash on every item. Cost projection at placeholder pricing: ~$2-3 for 10K items. Always run `--sample 50 --dry-run` first to spot-check tag quality before the full run.
- **Pattern column type change strategy** (Q4=a in plan): the model already uses `mapped_column("pattern_array", ARRAY(String), ...)` so app code can use `item.pattern` as an array TODAY. Migration 0013 added the column, 0014 drops the scalar and renames. App code never needs to change.
- **Out-of-vocab values stay** (per Q3): `category=NULL` for un-mappable slugs (`pajamas`, `swimwear`, etc.); manual cleanup later via admin UI.
- **`backfill_catalog_embeddings.py` referenced in graphify graph** — does NOT exist on this branch (graph was stale). No action needed.
- **`tryon_generation.py` referenced in graphify graph** — actually `app/routers/tryon.py` post-merge; only references `item.image_front_url` (no taxonomy fields). No change required.

---

## Locked-in Decisions (recap from plan §0.1)

| Q | Decision | Why |
|---|---|---|
| Q1 | (b) Catalog + wardrobe in same migration | Shared AI service, parallel taxonomy |
| Q2 | (a) Gender-keyed blouse rule | women → blouse, men → shirt |
| Q3 | (b) Name-keyword pass for ambiguous slugs | dresses-and-jumpsuits, skirts-and-shorts |
| Q4 | (a) Intermediate `pattern_array` column | works on Postgres + SQLite (test env) |
| Q5 | (a) `--report-unmapped` flag | detect map drift in CI |

---

## Test Counts

- Backend (post-Phase 3): **102 passed**
- Admin: TBD after Phase 5
- Mobile: TBD after Phase 6
