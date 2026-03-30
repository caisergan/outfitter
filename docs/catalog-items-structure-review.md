# Catalog Items Structure Review

Date: 2026-03-30

## Scope

This note reviews the backend structure around `catalog_items` and how it behaves with the rest of the system. It is a static architecture and integration review only. No tests were run against PostgreSQL, and no database changes were made.

Relevant areas reviewed:

- `backend/app/models/catalog.py`
- `backend/app/schemas/catalog.py`
- `backend/app/routers/catalog.py`
- `backend/alembic/versions/312b1e8cffdf_convert_to_uuid_and_add_redis.py`
- `backend/alembic/versions/0003_hnsw_vector_indexes.py`
- `backend/app/routers/outfits.py`
- `backend/app/routers/tryon.py`
- `mobile/lib/core/models/catalog_item.dart`
- `mobile/lib/features/discover/data/catalog_repository.dart`
- `admin/src/lib/api.js`

## Relevant skills and rules used

Skills:

- `navigator`
- `fastapi`
- `postgres-patterns`
- `python-testing`
- `verification-loop`
- `technical-writer`

Rules:

- `.agents/rules/fastapi/SKILL.md`
- `.agents/rules/postgres-patterns/SKILL.md`
- `.agents/rules/python-patterns/SKILL.md`
- `.agents/rules/python-anti-patterns/SKILL.md`

## Current structure

`catalog_items` is defined as a PostgreSQL-backed SQLAlchemy model with:

- UUID primary key
- descriptive item attributes such as `brand`, `category`, `subtype`, `name`, `pattern`, and `fit`
- array fields for `color` and `style_tags`
- `image_url` and optional `product_url`
- optional `clip_embedding VECTOR(512)` for semantic similarity
- shared timestamp columns through `TimestampMixin`

The table is also reflected in Alembic migrations, including an HNSW index on `clip_embedding` for vector search.

## What is good

- The table shape is a reasonable base for a fashion catalog.
- `catalog_items` and `wardrobe_items` are intentionally similar, which helps features that combine both sources.
- The vector column plus HNSW index is the right direction for semantic retrieval.
- The catalog router is compact and easy to follow.
- The admin client already consumes the current backend contract for search and similar item lookup.

## Findings

### 1. API contract drift between backend and mobile

This is the highest-risk issue.

`GET /catalog/search` returns `CatalogSearchResponse`, where each item is a full `CatalogItemResponse`. In that response, `color` and `style_tags` are nullable.

`GET /catalog/similar/{item_id}` returns a raw list of `SimilarItemResponse`, not a response envelope with `items`.

The Flutter client expects:

- `search()` to return `response.data['items']`
- `similar()` to also return `response.data['items']`
- each item to deserialize into the full `CatalogItem` model
- `color` and `styleTags` to always be present and non-null

That means the mobile side does not currently match the backend contract for similar items, and it may also break on search responses whenever `color` or `style_tags` is `NULL`.

References:

- `backend/app/schemas/catalog.py`
- `backend/app/routers/catalog.py`
- `mobile/lib/core/models/catalog_item.dart`
- `mobile/lib/features/discover/data/catalog_repository.dart`

### 2. Mixed item references are too loosely typed

`catalog_items` is used together with `wardrobe_items` in outfit generation and try-on flows, but the system passes those selections around as plain `dict` payloads instead of typed references.

This shows up in:

- `OutfitSuggestion.slots`
- `SaveOutfitRequest.slots`
- `TryOnSubmitRequest.slots`

Because those payloads are untyped, the system relies on raw item IDs without an explicit `source` discriminator. The try-on resolver then looks up `catalog_items` first and `wardrobe_items` second.

This is a weak integration boundary. It works only as long as every caller and every saved payload preserves the intended source implicitly.

References:

- `backend/app/schemas/outfit.py`
- `backend/app/schemas/tryon.py`
- `backend/app/routers/tryon.py`

### 3. Authorization boundary is weak in try-on item resolution

`catalog_items` is global and can reasonably be fetched without ownership checks. `wardrobe_items` is user-owned and should be resolved in a user-scoped way.

In `_resolve_image_urls()`, wardrobe items are fetched by ID alone and are not filtered by `current_user.id`.

Even though this is not a `catalog_items` table flaw, it matters because the catalog and wardrobe systems are merged at this boundary. The combined system currently trusts bare IDs too much.

Reference:

- `backend/app/routers/tryon.py`

### 4. Indexing does not fully support real query behavior

The migration creates indexes for:

- `brand`
- `category`
- `clip_embedding` through HNSW

But `search_catalog()` also filters on:

- `fit`
- `color.overlap(...)`
- `style_tags.contains(...)`

On PostgreSQL, the array predicates are the expensive part and usually want GIN indexes. If `fit` is a real filter dimension, it likely wants a B-tree index as well.

So the table schema is acceptable, but the index strategy is incomplete relative to the router behavior.

References:

- `backend/app/routers/catalog.py`
- `backend/alembic/versions/312b1e8cffdf_convert_to_uuid_and_add_redis.py`
- `backend/alembic/versions/0003_hnsw_vector_indexes.py`

### 5. Response serialization uses ORM mutation

`CatalogItemResponse.model_validate()` mutates the ORM object by rewriting `obj.id` from UUID to string before validation.

That is a poor boundary pattern. Response serialization should not modify ORM instances in place. It can create subtle issues in SQLAlchemy sessions and makes the schema layer responsible for object mutation.

Reference:

- `backend/app/schemas/catalog.py`

### 6. Category taxonomy is implied, not enforced

The system treats categories as a controlled taxonomy:

- search filters by exact category
- outfit slots are fixed to known fashion slots
- try-on assumes slot-based composition

But the database stores `category` as a free-form string with no check constraint or enum. That means data quality depends on ingestion discipline rather than schema guarantees.

This is manageable early on, but weak for a catalog that drives downstream recommendation and composition flows.

References:

- `backend/app/models/catalog.py`
- `backend/alembic/versions/312b1e8cffdf_convert_to_uuid_and_add_redis.py`
- `backend/app/schemas/outfit.py`

## Overall assessment

The `catalog_items` table itself is a solid starting point. The biggest problems are not the columns. The problems are around the table:

- inconsistent API contracts across consumers
- weakly typed cross-system payloads
- incomplete indexing for real PostgreSQL query patterns
- missing schema-level enforcement for category quality

In short:

- as a standalone table, `catalog_items` is reasonable
- as a shared system contract, it is not yet stable enough

## Recommended next steps

These are documentation-level recommendations only. They were not applied.

1. Unify the catalog API contract across backend, mobile, and admin.
2. Decide whether nullable arrays should stay nullable or be normalized to empty arrays.
3. Introduce typed item references for mixed `catalog` and `wardrobe` flows.
4. User-scope wardrobe lookups wherever catalog and wardrobe IDs are resolved together.
5. Add PostgreSQL indexes that match actual filter operators.
6. Replace free-form category handling with a constrained taxonomy or a validated mapping layer.
7. Remove ORM mutation from response serialization.

## Safety note

If PostgreSQL-backed validation is done later, it should be treated as read-only unless explicit approval is given first. This repository is not currently set up with an isolated disposable Postgres test database.
