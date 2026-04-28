# Admin Playground — gpt-image-2 Outfit Visualizer

**Date:** 2026-04-28
**Status:** Approved (pending spec review)
**Owner:** admin panel
**Related:** `admin/src/app/tryon/page.js`, `admin/src/app/catalog/page.js`, `backend/app/routers/tryon.py`

---

## 1. Goal

Add a single-page playground in the admin panel where the operator can:

1. Pick one or more catalog items (with their product images) from the existing DB.
2. Type a free-form instruction prompt (called "system prompt" by the user; not persisted).
3. Pick generation parameters (size, quality, count).
4. Send the items' images plus the prompt to **gpt-image-2** through the local OpenAI-compatible proxy (`http://localhost:8317/v1`), and view the generated images inline.

Primary use case: visualize how selected catalog items render on a virtual model, and iterate on the prompt without touching the database.

## 2. Non-Goals

- No persistence of prompts, generated images, or selections.
- No mobile app exposure — admin-only.
- No batch / queued generation. One synchronous call per click.
- No outfit recommendation logic; this is a creative testing tool, not a recommendation surface.
- No catalog or wardrobe data mutations.

## 3. User Flow

1. Operator navigates to `/playground` from the sidebar (new entry under Try-On).
2. Page loads with empty selection, prompt, and result area; default generation params (`size=1024x1536`, `quality=high`, `n=1`).
3. Operator filters/searches the catalog grid (reusing the existing filter shape from `/catalog`).
4. Operator clicks item cards to toggle selection. Selected items appear as a sticky chip rail at the top of the picker, with thumbnail and an `×` to deselect. Hard cap of **16 selections** (gpt-image-2 input limit).
5. Operator types a prompt (1–2000 chars) and optionally adjusts the **Advanced** panel (size / quality / n).
6. Operator clicks **Generate**. Button disables; result area shows a skeleton.
7. Backend returns `n` base64 PNGs as data URLs; the page renders them in a grid with a per-image **Download** button.
8. On error, the result area shows an alert with the message; the generate button re-enables for retry.
9. Operator changes prompt or selection and re-runs as desired.

## 4. Architecture

### 4.1 Routes / Files

**Backend (FastAPI):**
- New router: `backend/app/routers/playground.py`
- New service: `backend/app/services/codex_image_service.py`
- New schemas: `backend/app/schemas/playground.py`
- Modified: `backend/app/main.py` (register router), `backend/app/config.py` (add proxy settings)
- Tests: `backend/tests/test_playground.py`

**Frontend (Next.js admin):**
- New page: `admin/src/app/playground/page.js`
- Modified: `admin/src/lib/api.js` (add `generatePlaygroundImage`), `admin/src/components/Sidebar.js` (add nav entry).

### 4.2 Endpoint Contract

```
POST /playground/generate-image          (Bearer JWT)

Request:
{
  "catalog_item_ids": ["<uuid>", ...],   // 1..16
  "prompt": "<string>",                   // 1..2000 chars
  "size": "1024x1024" | "1024x1536" | "1536x1024",   // default "1024x1536"
  "quality": "low" | "medium" | "high",                // default "high"
  "n": 1                                                // 1..4, default 1
}

Response 200:
{
  "images": ["data:image/png;base64,iVBORw0KG...", ...],
  "model": "gpt-image-2",
  "item_count": <int>,
  "elapsed_ms": <int>
}

Errors:
  401  unauthorized                                          (existing JWT middleware)
  422  Pydantic validation                                   (length / range / list size)
  404  one or more catalog_item_ids do not exist             ("Catalog item {id} not found")
  502  S3 download failed OR proxy returned non-2xx          ("Image generation failed: ...")
  504  proxy timeout                                         ("Image generation timed out")
```

### 4.3 Data Flow

```
Admin UI
  -> POST /playground/generate-image  (Bearer token, JSON body)
Router (playground.py)
  - Pydantic validates body (size whitelist, quality whitelist, n in [1,4],
    prompt length, ids list size 1..16)
  - SELECT CatalogItem WHERE id IN (:ids)            (single query, async)
  - 404 if any id missing from result
  - resolve image URL per item:  image_front_no_bg_url ?? image_front_url
  - 422 if any item has neither URL ("Catalog item {id} has no front image")
  - service.generate_outfit_image(reference_urls, prompt, size, quality, n)

Service (codex_image_service.py, httpx.AsyncClient, 90s timeout)
  - asyncio.gather: GET each reference URL -> bytes (10s per fetch)
      on failure -> raise ReferenceImageError
  - POST {CODEX_PROXY_URL}/images/edits
      Authorization: Bearer {CODEX_PROXY_API_KEY}
      multipart/form-data:
        model:    gpt-image-2
        image[]:  <bytes>  (one part per reference image)
        prompt:   <string>
        size:     <string>
        quality:  <string>
        n:        <int>
      on non-2xx -> raise CodexProxyError(status, body)
      on timeout -> raise CodexProxyTimeout
  - parse response -> [f"data:image/png;base64,{d['b64_json']}" for d in resp["data"]]

Router
  - return PlaygroundGenerateResponse(images=..., model="gpt-image-2",
                                       item_count=len(ids), elapsed_ms=...)
```

### 4.4 Configuration

Add to `Settings` in `backend/app/config.py`:

```python
CODEX_PROXY_URL: str = "http://localhost:8317/v1"
CODEX_PROXY_API_KEY: str = "dummy"
```

These can be overridden via `.env`. Defaults match the user's local OpenAI-compatible proxy. The "API key" is purely a placeholder for the proxy's `Authorization` header — the proxy authenticates via the host's Codex OAuth session.

### 4.5 Why `image_front_no_bg_url` first

`backend/app/models/catalog.py` exposes both `image_front_url` and `image_front_no_bg_url`. The background-removed variant is a cleaner reference for gpt-image-2 (less noise, item silhouette clearer), so prefer it when present and fall back to the standard front image otherwise.

## 5. Frontend Details

### 5.1 Page Layout

```
+-- "Playground" header ------------------------------------+
| Test gpt-image-2 against catalog items.                   |
+----------------------------------------------------------+
| Selected items rail (sticky):                            |
|   [thumb][thumb][thumb] +N more     [Clear all]           |
+----------------------------------------------------------+
| Catalog picker:                                          |
|   filter chips (category, brand, gender, color, style…)   |
|   item grid (image + name + brand). click toggles select. |
|   selected: ring-2 ring-indigo-500 + checkmark overlay.   |
|   pagination (prev / page x of y / next)                  |
+----------------------------------------------------------+
| Prompt:                                                   |
|   <Textarea rows=6, placeholder hint, 1..2000 chars>      |
+----------------------------------------------------------+
| Advanced (collapsible):                                   |
|   Size [1024x1536 v]  Quality [high v]  Count [1]         |
+----------------------------------------------------------+
| [ Generate ]   (disabled when 0 items OR empty prompt)    |
+----------------------------------------------------------+
| Result:                                                   |
|   loading skeleton OR                                     |
|   <img grid of n images, each with Download button> OR    |
|   <Alert with error message>                              |
+----------------------------------------------------------+
```

### 5.2 Reused patterns

- Filter row mirrors the `FILTER_FIELDS` array from `admin/src/app/catalog/page.js`.
- Item card style matches the catalog table row image styling.
- `apiFetch`-based call via `admin/src/lib/api.js`.
- Toast-based error surfaces via `sonner` (already installed).
- Visual style: existing slate-950 / indigo-600 theme.

### 5.3 State (single client component)

```javascript
const [filters, setFilters]               // catalog filters
const [filterOptions, setFilterOptions]   // dropdown values
const [results, setResults]               // current catalog page
const [offset, setOffset]                 // pagination
const [selected, setSelected]             // Map<id, item> for picked items
const [prompt, setPrompt]                 // textarea value
const [size, setSize]                     // 1024x1024 / 1024x1536 / 1536x1024
const [quality, setQuality]               // low / medium / high
const [count, setCount]                   // 1..4
const [generating, setGenerating]         // loading flag
const [generatedImages, setGeneratedImages] // string[] of data URLs
const [genError, setGenError]             // string | null
const [advancedOpen, setAdvancedOpen]
```

### 5.4 Sidebar

Add to `navItems` after the Try-On entry:

```javascript
{ href: "/playground", label: "Playground", icon: Sparkles }
```

(Already imports `lucide-react`; `Sparkles` is part of that package.)

## 6. Backend Details

### 6.1 Schema

```python
# backend/app/schemas/playground.py
from typing import Annotated
from uuid import UUID
from pydantic import BaseModel, Field, conlist

PlaygroundSize    = Literal["1024x1024", "1024x1536", "1536x1024"]
PlaygroundQuality = Literal["low", "medium", "high"]

class PlaygroundGenerateRequest(BaseModel):
    catalog_item_ids: Annotated[list[UUID], Field(min_length=1, max_length=16)]
    prompt: Annotated[str, Field(min_length=1, max_length=2000)]
    size: PlaygroundSize = "1024x1536"
    quality: PlaygroundQuality = "high"
    n: Annotated[int, Field(ge=1, le=4)] = 1

class PlaygroundGenerateResponse(BaseModel):
    images: list[str]            # data URLs
    model: str
    item_count: int
    elapsed_ms: int
```

### 6.2 Service

```python
# backend/app/services/codex_image_service.py
class CodexProxyError(RuntimeError):       # non-2xx from proxy
class CodexProxyTimeout(RuntimeError):     # timeout
class ReferenceImageError(RuntimeError):   # S3 download failed

async def generate_outfit_image(
    reference_urls: list[str],
    prompt: str,
    size: str,
    quality: str,
    n: int,
) -> list[str]:
    # 1. async download each reference (httpx.AsyncClient, 10s per request, gather)
    # 2. POST multipart to {CODEX_PROXY_URL}/images/edits
    # 3. parse data[*].b64_json -> ["data:image/png;base64,..." ...]
    # 4. raise typed errors on failure
```

### 6.3 Router

```python
# backend/app/routers/playground.py
@router.post("/generate-image", response_model=PlaygroundGenerateResponse)
async def generate_image(
    body: PlaygroundGenerateRequest,
    db: DbDep,
    _: CurrentUserDep,
) -> PlaygroundGenerateResponse:
    # 1. SELECT CatalogItem WHERE id IN (...)
    # 2. 404 if any id missing
    # 3. resolve reference URLs (no_bg first, then front)
    # 4. start = time.perf_counter()
    # 5. images = await generate_outfit_image(...)
    # 6. map service errors to HTTPException (502 / 504)
    # 7. return response with elapsed_ms
```

## 7. Error Handling

| Failure mode                              | HTTP    | UI behavior                               |
| ----------------------------------------- | ------- | ----------------------------------------- |
| No JWT / invalid                          | 401     | redirect to `/login` (existing behavior)  |
| Empty prompt / 0 items / >16 items / bad size | 422 | toast + inline; button re-enables         |
| Selected item has no front image URL      | 422     | toast `"Catalog item ... has no front image"` |
| One or more `catalog_item_ids` not found  | 404     | toast `"Catalog item ... not found"`      |
| S3 fetch fails on any reference image     | 502     | toast `"Failed to fetch reference image"` |
| Proxy returns non-2xx                     | 502     | toast `"Image generation failed: ..."`    |
| Proxy timeout                             | 504     | toast `"Image generation timed out"`      |

The frontend never retries automatically. The user re-clicks Generate to retry.

## 8. Testing

### 8.1 Backend (`backend/tests/test_playground.py`)

- `test_generate_happy_path` — mocks `httpx` (both download and proxy), seeds two `CatalogItem`s, asserts:
  - response shape (`images` non-empty, `model == "gpt-image-2"`, `item_count == 2`)
  - service was called with the resolved reference URLs (no_bg preferred)
  - multipart payload includes `model`, `image[]`, `prompt`, `size`, `quality`, `n`
- `test_generate_unknown_item_id` — one missing UUID -> 404
- `test_generate_item_missing_image` — item exists but both `image_front_no_bg_url` and `image_front_url` null -> 422
- `test_generate_proxy_error` — proxy returns 500 -> 502
- `test_generate_proxy_timeout` — `httpx.TimeoutException` -> 504
- `test_generate_validation_empty_prompt` -> 422
- `test_generate_validation_no_items` -> 422
- `test_generate_validation_too_many_items` (>16) -> 422
- `test_generate_unauthorized` -> 401

Tests follow the existing `backend/tests/conftest.py` pattern (sqlite for catalog rows, `httpx.AsyncClient` mocked via `respx` or monkeypatch).

### 8.2 Frontend

Manual verification per project `CLAUDE.md` (run `admin` dev server):

- Picker selects/deselects, hard cap at 16, chips work, clear all works
- Validation: empty prompt disables button; 0 items disables button
- Successful generation renders images in the grid
- Download button works
- Error path shows alert and re-enables button

## 9. Risks / Mitigations

| Risk                                                    | Mitigation                                          |
| ------------------------------------------------------- | --------------------------------------------------- |
| Proxy doesn't actually accept `/v1/images/edits`        | Service is the only place to swap; UI/router stable. Fallback path documented (Approach B in brainstorming) |
| Large reference images blow up multipart payload        | Catalog images are S3-hosted product shots, typically <500KB. Cap aside, no resizing on first pass; revisit if 413 from proxy |
| `gpt-image-2` parameter names differ from `gpt-image-1` | If proxy rejects a param name, adjust in service only; spec lists OpenAI gpt-image-1 contract as reference |
| Long generation times block the UI                      | 90s httpx timeout, button disabled, skeleton visible. Acceptable for a playground |
| Base64 payload bloats response                          | n capped at 4 + size capped at 1536px; worst case ~8MB JSON; acceptable for admin-only local-dev tool |

## 10. Acceptance Criteria

- New `Playground` entry visible in the admin sidebar.
- `/playground` route renders the picker, prompt, advanced controls, generate button, and result area.
- Selecting 1–16 catalog items + non-empty prompt + clicking Generate produces at least one base64 image rendered inline within ~60s under normal proxy conditions.
- Backend tests above all pass.
- No DB writes occur during a playground generation (verified by absence of new rows after a run).
- Errors surface as toasts + inline alerts; the page never crashes on a backend failure.
