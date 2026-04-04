# Catalog Item S3 Images Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add admin-managed catalog item image uploads via AWS S3 while keeping `catalog_items.image_url` stable for admin, mobile, outfit suggestion, and try-on consumers.

**Architecture:** Use a direct browser-to-S3 upload flow from the admin app. The backend issues a short-lived presigned `PUT` URL plus the final public image URL, the admin uploads the file to S3, and then the normal catalog create/update endpoints persist that stable `image_url`. Catalog create/update must also compute `clip_embedding` from the uploaded image so similar-item search remains functional for newly added or replaced images.

**Tech Stack:** FastAPI, SQLAlchemy, boto3/botocore, existing S3-compatible storage service, Next.js admin app, pytest, AWS S3 presigned `PUT` URLs.

---

## Decisions To Lock Before Coding

1. Treat catalog images as durable public URLs.
   Reason: `image_url` is consumed directly by admin search results, mobile catalog models, outfit suggestion payloads, and try-on slot resolution. Do not switch catalog to short-lived signed read URLs in this feature.

2. Keep the existing `image_url` contract for clients.
   Reason: this avoids touching mobile and most backend consumers. The upload feature becomes an ingestion improvement, not a system-wide schema rewrite.

3. Compute embeddings during catalog create and image-changing updates.
   Reason: `GET /catalog/similar/{item_id}` returns nothing when `clip_embedding` is `NULL`, so newly added images must not skip embedding generation.

4. Do not add object deletion in v1.
   Reason: the current schema stores only `image_url`, not a first-class storage key. Replacing or deleting old objects safely is a separate cleanup task.

5. If the bucket must remain private, stop and re-scope.
   Private catalog assets require a larger change: store object keys, sign reads in every response path, and rework try-on/outfit resolution.

## Current-State Review Summary

- `catalog_items` already has `image_url`, but catalog creation is metadata-only and does not compute embeddings.
- The admin catalog page is read-only. It can search and view similar items, but it cannot create or update catalog items.
- The storage service is S3-compatible, but its upload helper is wardrobe-specific and its client config is still biased toward R2 naming and `region_name="auto"`.
- Docs mention a catalog ingestion script that uploads to storage, but that script is not present in this repository. Treat that as an external dependency or documentation drift.

## Findings And Planned Fixes

### Findings that this image feature must fix now

1. Catalog write paths do not generate embeddings.
   Fix: update catalog create, bulk create, and image-changing patch flows to fetch the uploaded image and persist `clip_embedding` at write time. This is covered in Task 3.

2. There is no AWS S3 upload contract for catalog images.
   Fix: generalize the storage service and add a dedicated catalog upload-target endpoint that returns a presigned `PUT` URL plus the final stable `image_url`. This is covered in Tasks 1 and 2.

3. The admin catalog UI cannot create or update items.
   Fix: add a new Manage/Create flow in the admin page that performs file selection, upload-target negotiation, direct S3 upload, and final catalog item creation. This is covered in Task 4.

4. `image_url` is a shared system contract, not just a catalog field.
   Fix: keep `catalog_items.image_url` as a durable public URL and avoid introducing signed-read dependencies into search, mobile, outfit suggestion, or try-on in this feature. This is enforced by the Decisions section and verified in Task 5.

### Findings from the broader catalog review to track in the same implementation plan

1. Backend/mobile catalog contract drift still exists.
   Problem: mobile expects `response.data['items']` for similar-items and requires non-null arrays, while the backend returns a bare list for `/catalog/similar/{item_id}` and allows nullable arrays.
   Fix: after the image feature lands, normalize `/catalog/similar/{item_id}` to an envelope response and decide whether array fields should always serialize as empty arrays. This is added as Task 6.

2. Try-on item resolution still trusts bare wardrobe IDs.
   Problem: `tryon` resolves wardrobe items by ID without user scoping.
   Fix: add ownership filtering when resolving wardrobe images and verify catalog behavior remains unchanged. This is added as Task 7.

3. Query indexes still do not match actual catalog filters.
   Problem: `fit`, `color.overlap`, and `style_tags.contains` are queried without matching index support.
   Fix: add follow-up migration work for `fit` and GIN indexes on array fields. This is added as Task 7.

4. Category taxonomy is still free-form.
   Problem: downstream outfit and try-on flows treat category as controlled, but the database does not enforce that constraint.
   Fix: define a constrained taxonomy or validation layer after the image feature is stable. This is added as Task 8.

5. ORM-mutation response serialization appears already fixed in the current codebase.
   Observation: the earlier review noted a mutation issue, but the current schema/test path no longer mutates `id` in place.
   Fix: keep the existing regression test and do not spend image-feature scope on re-fixing it unless a regression reappears.

## Task 1: Generalize storage helpers for AWS S3-backed catalog uploads

**Files:**
- Modify: `backend/app/config.py`
- Modify: `backend/.env.example`
- Modify: `backend/app/services/storage_service.py`
- Test: `backend/tests/test_storage.py`

**Step 1: Write the failing tests**

Add tests that prove these behaviors:

```python
def test_generates_catalog_presigned_put_url(...):
    target = get_catalog_upload_target(
        brand="Mango",
        filename="linen-shirt.jpg",
        content_type="image/jpeg",
    )
    assert target.key.startswith("catalog/mango/")
    assert target.upload_url == "https://example.com/signed-put"
    assert target.image_url == "https://cdn.example.com/catalog/mango/...jpg"


def test_uses_configured_region_for_real_s3(...):
    _get_client()
    boto3_client.assert_called_once_with(
        "s3",
        endpoint_url=None,
        aws_access_key_id="...",
        aws_secret_access_key="...",
        region_name="us-east-1",
        config=ANY,
    )
```

**Step 2: Run test to verify it fails**

Run: `cd backend && .venv/bin/pytest tests/test_storage.py -q`
Expected: FAIL because the catalog upload helper and new config contract do not exist yet.

**Step 3: Write minimal implementation**

Implement these changes:

- Add `STORAGE_REGION` and `STORAGE_PUBLIC_BASE_URL` settings.
- Make `R2_ENDPOINT_URL` optional so real AWS S3 can rely on the default endpoint resolution path.
- Change the client builder to use `region_name=settings.STORAGE_REGION`.
- Add a small value object or tuple-return helper for catalog uploads, for example:

```python
@dataclass(frozen=True)
class UploadTarget:
    key: str
    upload_url: str
    image_url: str


def get_catalog_upload_target(brand: str, filename: str, content_type: str) -> UploadTarget:
    extension = _extension_for_content_type(content_type, filename)
    key = f"catalog/{slugify(brand)}/{uuid4()}{extension}"
    upload_url = _get_client().generate_presigned_url(...)
    image_url = build_public_url(key)
    return UploadTarget(key=key, upload_url=upload_url, image_url=image_url)
```

Keep `get_upload_url()` for wardrobe working, but refactor it to reuse the shared upload helper internals instead of duplicating logic.

**Step 4: Run test to verify it passes**

Run: `cd backend && .venv/bin/pytest tests/test_storage.py -q`
Expected: PASS.

**Step 5: Commit**

Use a Lore-format commit describing why AWS-compatible catalog uploads need a generic storage contract.

## Task 2: Add a catalog image upload endpoint and request/response schemas

**Files:**
- Modify: `backend/app/schemas/catalog.py`
- Modify: `backend/app/routers/catalog.py`
- Test: `backend/tests/test_catalog.py`

**Step 1: Write the failing tests**

Add API tests for a new endpoint such as `POST /catalog/images/upload-url`.

```python
async def test_catalog_upload_url_returns_upload_and_public_urls(client, auth_headers):
    response = await client.post(
        "/catalog/images/upload-url",
        headers=auth_headers,
        json={
            "brand": "Mango",
            "filename": "linen-shirt.jpg",
            "content_type": "image/jpeg",
            "file_size": 1048576,
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["upload_url"].startswith("https://")
    assert body["image_url"].startswith("https://")
    assert body["object_key"].startswith("catalog/mango/")


async def test_catalog_upload_url_rejects_unsupported_type(...):
    ...
```

**Step 2: Run test to verify it fails**

Run: `cd backend && .venv/bin/pytest tests/test_catalog.py -q`
Expected: FAIL because the schema and endpoint do not exist.

**Step 3: Write minimal implementation**

Add:

```python
class CatalogImageUploadRequest(BaseModel):
    brand: str
    filename: str
    content_type: str
    file_size: int


class CatalogImageUploadResponse(BaseModel):
    upload_url: str
    image_url: str
    object_key: str
    expires_in: int
```

Endpoint behavior:

- Require auth like the rest of `/catalog`.
- Allow only `image/jpeg`, `image/png`, and `image/webp`.
- Reject files over `10 * 1024 * 1024` bytes.
- Call the new storage helper and return the upload target.
- Keep the response JSON small and deterministic.

**Step 4: Run test to verify it passes**

Run: `cd backend && .venv/bin/pytest tests/test_catalog.py -q`
Expected: PASS for the new upload endpoint tests.

**Step 5: Commit**

Use a Lore-format commit describing why catalog uploads need a backend-issued S3 target instead of a raw URL text field.

## Task 3: Generate CLIP embeddings on catalog create and image-changing updates

**Files:**
- Modify: `backend/app/routers/catalog.py`
- Test: `backend/tests/test_catalog.py`

**Step 1: Write the failing tests**

Add tests for the create and update paths.

```python
async def test_create_catalog_item_generates_embedding(...):
    with patch("app.routers.catalog.embed_image_async", return_value=[0.1] * 512):
        response = await client.post("/catalog/items", ...)
    assert response.status_code == 201
    item = await db_get_catalog_item(...)
    assert item.clip_embedding is not None


async def test_patch_catalog_item_recomputes_embedding_only_when_image_changes(...):
    ...
```

Also cover the failure path:

```python
async def test_create_catalog_item_fails_when_uploaded_image_cannot_be_embedded(...):
    assert response.status_code in {422, 502}
```

**Step 2: Run test to verify it fails**

Run: `cd backend && .venv/bin/pytest tests/test_catalog.py -q`
Expected: FAIL because catalog create/update currently only copy fields into the ORM model.

**Step 3: Write minimal implementation**

Implementation outline:

```python
async def _embed_catalog_image(image_url: str) -> list[float]:
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get(image_url)
        response.raise_for_status()
    return await embed_image_async(response.content)
```

Apply it here:

- `POST /catalog/items`: always compute and persist `clip_embedding`.
- `POST /catalog/items/bulk`: compute embeddings per item; collect failures in the existing bulk error response.
- `PATCH /catalog/items/{item_id}`: recompute only if `image_url` changed.

Do not silently write catalog items with `clip_embedding=None` in this new path.

**Step 4: Run test to verify it passes**

Run: `cd backend && .venv/bin/pytest tests/test_catalog.py -q`
Expected: PASS.

**Step 5: Commit**

Use a Lore-format commit describing why new catalog images must be embedded at write time.

## Task 4: Add admin-side catalog create flow with direct S3 upload

**Files:**
- Modify: `admin/src/lib/api.js`
- Modify: `admin/src/app/catalog/page.js`

**Step 1: Add the missing API wrappers**

Add these functions:

```javascript
export async function requestCatalogImageUpload(data) {
  return apiFetch("/catalog/images/upload-url", { method: "POST", body: data });
}

export async function createCatalogItem(data) {
  return apiFetch("/catalog/items", { method: "POST", body: data });
}

export async function updateCatalogItem(itemId, data) {
  return apiFetch(`/catalog/items/${itemId}`, { method: "PATCH", body: data });
}
```

**Step 2: Add a new Manage/Create tab to the catalog page**

Build a form for:

- `ref_code`
- `brand`
- `category`
- `subtype`
- `name`
- `color`
- `pattern`
- `fit`
- `style_tags`
- `product_url`
- image file picker

Do not remove the existing Search and Similar tabs.

**Step 3: Implement the upload flow**

Client flow:

1. User selects an image file.
2. Validate type and size before any network call.
3. Request a presigned upload target from the backend.
4. Upload to S3 with `fetch(uploadUrl, { method: "PUT", headers: { "Content-Type": file.type }, body: file })`.
5. Submit `createCatalogItem()` with the returned `image_url` plus the metadata fields.
6. Reset the form and optionally refresh search results.

Keep error states separate:

- upload-target request failure
- raw S3 upload failure
- catalog create failure

**Step 4: Add a minimal image preview and upload status UI**

Include:

- local preview before upload
- uploading spinner
- uploaded image URL readout for debugging
- explicit toast on each failure stage

**Step 5: Verify the admin app builds**

Run: `cd admin && npm run build`
Expected: PASS.

**Step 6: Commit**

Use a Lore-format commit describing why catalog management needs direct-to-S3 image upload instead of free-text URLs.

## Task 5: Manual verification and API artifacts

**Files:**
- Modify: `backend/postman/outfitter-catalog.postman_collection.json`
- Modify: `backend/.env.example`
- Optional note: `docs/catalog-items-structure-review.md`

**Step 1: Add API examples for the new upload flow**

Document this sequence in Postman:

1. `POST /catalog/images/upload-url`
2. `PUT <upload_url>` to S3
3. `POST /catalog/items`
4. `GET /catalog/search`
5. `GET /catalog/similar/{item_id}`

**Step 2: Run backend verification**

Run: `cd backend && .venv/bin/pytest tests/test_storage.py tests/test_catalog.py -q`
Expected: PASS.

**Step 3: Run admin verification**

Run: `cd admin && npm run build`
Expected: PASS.

**Step 4: Manual smoke test**

Manual checklist:

1. Log into the admin app.
2. Open `/catalog`.
3. Upload a JPEG, PNG, or WebP smaller than 10 MB.
4. Create a catalog item with the returned `image_url`.
5. Search for the new item and confirm the thumbnail renders.
6. Call similar-items for the new item and confirm it does not return an empty array because of missing embedding.
7. Use the item in outfit suggestion / try-on and confirm the same `image_url` is passed through successfully.

**Step 5: Commit**

Use a Lore-format commit describing why the new upload flow needed end-to-end verification artifacts.

## Task 6: Normalize catalog API contracts after the image flow is stable

**Files:**
- Modify: `backend/app/schemas/catalog.py`
- Modify: `backend/app/routers/catalog.py`
- Modify: `mobile/lib/core/models/catalog_item.dart`
- Modify: `mobile/lib/features/discover/data/catalog_repository.dart`
- Test: `backend/tests/test_catalog.py`

**Step 1: Write the failing tests**

Add tests that lock the intended contract:

- `/catalog/search` returns `items` and `total`
- `/catalog/similar/{item_id}` also returns an envelope with `items`
- `color` and `style_tags` serialize deterministically according to the final decision: always `[]` or explicitly nullable on every consumer

**Step 2: Run test to verify it fails**

Run: `cd backend && .venv/bin/pytest tests/test_catalog.py -q`
Expected: FAIL until the similar-items contract is normalized.

**Step 3: Write minimal implementation**

- Introduce a shared response envelope for search and similar-items.
- Either normalize null arrays to `[]` at the backend boundary or relax the Flutter model to nullable lists. Prefer one decision across every catalog response.
- Update the mobile repository to consume the final response shape consistently.

**Step 4: Run verification**

Run:

- `cd backend && .venv/bin/pytest tests/test_catalog.py -q`
- `cd admin && npm run build`

Expected: PASS.

**Step 5: Commit**

Use a Lore-format commit describing why the catalog contract must stay consistent across backend, mobile, and admin.

## Task 7: Harden catalog-adjacent try-on and search infrastructure

**Files:**
- Modify: `backend/app/routers/tryon.py`
- Add: `backend/alembic/versions/<new_revision>_catalog_filter_indexes.py`
- Test: `backend/tests/test_catalog.py`
- Test: `backend/tests/<new_tryon_test_file>.py`

**Step 1: Write the failing tests**

Add:

- a try-on test proving a user cannot resolve another user's wardrobe image by ID
- migration-level or query-plan-oriented tests where practical, or at minimum schema assertions for the new indexes

**Step 2: Run test to verify it fails**

Run the targeted backend test subset.

**Step 3: Write minimal implementation**

- Update wardrobe resolution in `tryon` to filter by `current_user.id`
- add a B-tree index for `fit`
- add GIN indexes for `color` and `style_tags`

**Step 4: Run verification**

Run:

- `cd backend && .venv/bin/pytest tests/test_catalog.py tests/<new_tryon_test_file>.py -q`

Expected: PASS.

**Step 5: Commit**

Use a Lore-format commit describing why search and try-on need stronger production boundaries around the catalog system.

## Task 8: Constrain the category taxonomy deliberately

**Files:**
- Modify: `backend/app/schemas/catalog.py`
- Modify: `backend/app/models/catalog.py` or add a validation layer/service
- Modify: `docs/catalog-items-structure-review.md`
- Optional: `backend/alembic/versions/<new_revision>_catalog_category_constraint.py`

**Step 1: Decide the enforcement layer**

Choose one:

- database enum/check constraint
- backend validation mapping layer

Do not implement both unless there is a concrete reason.

**Step 2: Write the failing tests**

Add tests proving invalid categories are rejected and valid categories remain accepted across create and update flows.

**Step 3: Write minimal implementation**

Implement the chosen taxonomy guard with the smallest enforceable boundary.

**Step 4: Run verification**

Run: `cd backend && .venv/bin/pytest tests/test_catalog.py -q`
Expected: PASS.

**Step 5: Commit**

Use a Lore-format commit describing why category normalization is required for downstream outfit and try-on correctness.

## Risks And Explicit Non-Goals

- Do not convert catalog responses to signed read URLs in this feature.
- Do not add S3 object deletion yet.
- Do not change the mobile catalog contract unless the storage decision changes.
- Do not rename every legacy `R2_*` setting in the same PR unless you decide to pay the migration cost intentionally.

## Open Questions

1. The plan assumes catalog images can be served from a stable public base URL such as a public S3 URL or CloudFront distribution. Confirm that with infra before coding.
2. `docs/tasks.md` references a catalog ingestion script, but that script is not present in this repo. If it still exists elsewhere, update it to use the same storage helper after this feature ships.
3. If existing catalog items need image replacement from the admin UI, extend Task 4 with an edit dialog that calls `PATCH /catalog/items/{item_id}` after the create path is stable.

Plan complete and saved to `docs/plans/2026-04-05-catalog-item-s3-images.md`. Two execution options:

1. Subagent-Driven (this session) - I dispatch fresh subagent per task, review between tasks, fast iteration
2. Parallel Session (separate) - Open new session with executing-plans, batch execution with checkpoints
