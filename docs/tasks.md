# Fashion App — Task Breakdown

**Project Goal**: Ship a mobile-first (iOS + Android) fashion app with TryOn, Assistant, Wardrobe, and Discover tabs backed by a FastAPI + PostgreSQL + AI stack.
**Scope**: MVP Phase 1 per PRD — Mango catalog only; no social/in-app purchase features.

---

## Milestones

| # | Milestone | Success Criteria |
|---|-----------|-----------------|
| 1 | Backend Scaffolded | FastAPI runs locally, DB connects, auth works |
| 2 | AI Services Integrated | Claude tagging, CLIP embeddings, Kling submit/poll working end-to-end |
| 3 | All API Endpoints Complete | Every route documented in the spec returns correct responses |
| 4 | Flutter App Shell | 4-tab navigation, auth screens, API client wired up |
| 5 | Core Features Complete | TryOn, Wardrobe, Assistant, Discover all functional |
| 6 | QA & AI Evaluation Pass | All AI accuracy thresholds met; no critical bugs |
| 7 | Production Deploy | App live on staging; production checklist green |

---

## Phase 1: Project Setup & Infrastructure

- [ ] Initialize FastAPI project with folder structure (`app/`, `models/`, `routers/`, `services/`, `schemas/`, `auth/`)
  - Done: `uvicorn app.main:app` starts without errors
- [ ] Create `requirements.txt` with all pinned dependencies (fastapi, uvicorn, sqlalchemy, asyncpg, pgvector, anthropic, boto3, python-jose, passlib, httpx, pillow, open-clip-torch)
  - Done: `pip install -r requirements.txt` succeeds cleanly
- [ ] Set up `.env.example` with all required variables (DATABASE_URL, SECRET_KEY, ANTHROPIC_API_KEY, KLING_API_KEY, R2 credentials, ENV, LOG_LEVEL)
  - Done: All variables documented; `.env.example` committed
- [ ] Configure `app/config.py` using pydantic `BaseSettings` to load env vars
  - Done: Settings object loads all values; missing required vars raise clear errors
- [ ] Set up `app/database.py` with async SQLAlchemy engine, session factory, and `get_db` dependency
  - Done: Async DB session injected into a test route successfully
- [ ] Create `docker-compose.yml` with `api` and `db` (pgvector/pgvector:pg15) services
  - Done: `docker compose up --build` starts both services; API reaches DB
- [ ] Set up Alembic with async support; configure `alembic.ini` and `env.py`
  - Done: `alembic revision` and `alembic upgrade head` run without errors
- [ ] Set up Cloudflare R2 bucket with folder structure (`wardrobe/`, `tryon/`, `catalog/`) and CORS policy allowing Flutter app origins
  - Done: Test upload via pre-signed URL succeeds; files visible in R2 dashboard
- [ ] Initialize git repo, `.gitignore` (exclude `.env`, `__pycache__`, `.venv`)
  - Done: Sensitive files not tracked

---

## Phase 2: Database Schema & Migrations

- [ ] Enable `pgvector` extension on PostgreSQL instance
  - Done: `CREATE EXTENSION IF NOT EXISTS vector;` succeeds
- [ ] Create `users` ORM model (`id`, `email`, `password_hash`, `skin_tone`, `created_at`, `updated_at`)
  - Done: Model importable; migration generated
- [ ] Create `catalog_items` ORM model with all fields including `clip_embedding VECTOR(512)`
  - Done: Model importable; migration generated
- [ ] Create `wardrobe_items` ORM model with `user_id` FK, `clip_embedding VECTOR(512)`, `times_used`, `deleted_at` (soft delete)
  - Done: Model importable; migration generated
- [ ] Create `saved_outfits` ORM model with `slots JSONB`, `source` check constraint (`tryon`/`assistant`), `generated_image_url`
  - Done: Model importable; migration generated
- [ ] Generate and apply initial Alembic migration for all four tables
  - Done: `alembic upgrade head` creates all tables with correct columns
- [ ] Add HNSW index migration for `catalog_items.clip_embedding` (cosine ops)
  - Done: Index visible in `\d catalog_items`
- [ ] Add HNSW index migration for `wardrobe_items.clip_embedding` (cosine ops)
  - Done: Index visible in `\d wardrobe_items`
- [ ] Create and test Pydantic schemas (`schemas/`) for all four models — request bodies and response shapes
  - Done: Schemas serialize/deserialize correctly in unit tests

---

## Phase 3: Authentication

- [ ] Implement password hashing utility using `passlib[bcrypt]` with cost factor 12
  - Done: `hash_password` and `verify_password` functions tested
- [ ] Implement JWT token creation using `python-jose` (HS256, 7-day expiry)
  - Done: `create_access_token` returns valid JWT decodable with secret key
- [ ] Implement `get_current_user` FastAPI dependency (decodes token, fetches user from DB, raises 401 on failure)
  - Done: Dependency blocks unauthenticated requests correctly
- [ ] Implement `POST /auth/signup` endpoint (validate email uniqueness, hash password, return token)
  - Done: Returns `access_token`; duplicate email returns 409
- [ ] Implement `POST /auth/login` endpoint (verify password, return token)
  - Done: Returns `access_token`; wrong password returns 401
- [ ] Register auth router in `app/main.py`
  - Done: `/auth/signup` and `/auth/login` visible in `/docs`
- [ ] Write integration tests for signup → login → protected endpoint flow
  - Done: All auth scenarios (success, duplicate email, wrong password, missing token) pass

---

## Phase 4: Storage Service

- [ ] Implement `services/storage_service.py` with boto3 R2 client initialization
  - Done: Client connects to R2 endpoint without errors
- [ ] Implement `get_upload_url(user_id, item_id)` — generates 15-min pre-signed PUT URL with `image/jpeg` content type
  - Done: Pre-signed URL generated; Flutter client can PUT a JPEG to it
- [ ] Implement `get_signed_read_url(key)` — generates short-lived GET URL for serving private images
  - Done: Signed read URL returns image in browser
- [ ] Implement helper to upload bytes directly from backend (for Kling result images)
  - Done: Backend can write a JPEG to `tryon/{user_id}/{job_id}.jpg`

---

## Phase 5: CLIP Embedding Service

- [ ] Implement `services/clip_service.py`: load `ViT-B-32` model via `open_clip`, set to eval mode
  - Done: Model loads on startup without errors
- [ ] Implement `embed_image(image_bytes: bytes) -> list[float]`: preprocess image, run inference, L2-normalize, return 512-dim list
  - Done: Returns deterministic 512-dim vector for same input image
- [ ] Implement async wrapper `embed_image_async` using `asyncio.run_in_executor` to avoid blocking the event loop
  - Done: CLIP inference doesn't block FastAPI event loop
- [ ] Implement `find_similar_items(embedding, limit, source)` using SQLAlchemy + pgvector cosine distance query across `catalog_items` and/or `wardrobe_items`
  - Done: Returns ranked items by cosine similarity; correct source filtering
- [ ] Write unit tests for `embed_image` (output dimension = 512, values normalized)
  - Done: Tests pass

---

## Phase 6: Claude Service

- [ ] Implement `services/claude_service.py` with Anthropic client initialization
  - Done: Client initializes with API key
- [ ] Implement image preprocessing step: crop garment region, strip faces before sending to Claude
  - Done: No visible faces in images sent to Claude API
- [ ] Implement `tag_wardrobe_item(image_bytes, media_type)`: encode image as base64, send with tagging prompt, parse JSON response
  - Done: Returns structured dict with category, subtype, color, pattern, fit, style_tags
- [ ] Handle `json.JSONDecodeError` in tagging: retry once with stricter prompt, then return `{"category": "unknown", "confidence": 0.0}` fallback
  - Done: Non-JSON Claude response doesn't crash the endpoint
- [ ] Define `SUGGEST_PROMPT` template with all parameter placeholders (occasion, season, color_preference, source, count, items_json)
  - Done: Prompt template renders correctly with test values
- [ ] Implement `suggest_outfits(params, available_items)`: format prompt, call Claude, parse JSON array response
  - Done: Returns list of outfit dicts with `slots` and `style_note`
- [ ] Implement outfit suggestion caching (in-memory dict or Redis) with 24-hour TTL keyed on parameter hash
  - Done: Same parameters within TTL return cached result without calling Claude
- [ ] Write unit tests for both Claude service functions using mocked Anthropic responses
  - Done: Tests pass without hitting real API

---

## Phase 7: Kling Try-On Service

- [ ] Implement `services/kling_service.py` with base URL and API key configuration
  - Done: Kling base URL and key loaded
- [ ] Implement `submit_tryon(outfit_image_urls, model_photo_url) -> str`: POST to Kling, return `job_id`
  - Done: Returns valid job ID string; raises `httpx.HTTPStatusError` on failure
- [ ] Implement `poll_tryon_status(job_id) -> dict`: GET status endpoint, return status dict with optional `image_url`
  - Done: Returns `{"status": "complete", "image_url": "..."}` or `{"status": "processing"}`
- [ ] Handle Kling `timeout` and `failed` states gracefully with descriptive exceptions
  - Done: Timeout and failed states raise catchable exceptions with useful messages

---

## Phase 8: Catalog Data Pipeline

- [ ] Update existing `scraper.py` to output structured catalog data matching `catalog_items` schema (brand, category, name, color, pattern, fit, style_tags, image_url, product_url)
  - Done: Scraped items match DB schema fields
- [ ] Write catalog ingestion script: read scraped data, upload images to R2 under `catalog/{brand}/{item_id}.jpg`, insert rows to `catalog_items`
  - Done: Mango catalog items appear in DB after running script
- [ ] Integrate CLIP embedding into ingestion script: embed each catalog image and store 512-dim vector in `clip_embedding` column
  - Done: `clip_embedding` column non-null for all ingested items
- [ ] Verify HNSW index on `catalog_items` functions correctly after bulk insert
  - Done: `/catalog/similar/{item_id}` returns semantically relevant results

---

## Phase 9: Catalog API Endpoints

- [ ] Implement `GET /catalog/search` with query parameters (category, color, brand, style, fit, limit, offset) and SQLAlchemy filtering
  - Done: Returns paginated `{"items": [...], "total": N}` with correct filtering
- [ ] Implement `GET /catalog/similar/{item_id}` using CLIP embedding + pgvector cosine search; support `source` param (`catalog`, `wardrobe`, `both`)
  - Done: Returns ranked similar items with `similarity` score
- [ ] Register catalog router in `app/main.py`
  - Done: Endpoints visible in `/docs`
- [ ] Write integration tests for catalog search (filters, pagination) and similarity (correct source routing)
  - Done: All test cases pass

---

## Phase 10: Wardrobe API Endpoints

- [ ] Implement `GET /wardrobe` with category filter and sort options (`color`, `recent`), pagination, and soft-delete exclusion
  - Done: Returns only authenticated user's non-deleted items
- [ ] Implement `POST /wardrobe/tag` — accept `multipart/form-data`, validate file type/size (JPEG/PNG, max 10 MB), call Claude tagging service, return tag dict
  - Done: Returns structured tags within 5 seconds; rejects oversized/wrong-type files
- [ ] Implement `POST /wardrobe` — accept pre-tagged item body, upload to R2 if needed, compute CLIP embedding, insert to DB
  - Done: Item appears in `GET /wardrobe` immediately after save
- [ ] Implement `DELETE /wardrobe/{item_id}` — soft delete by setting `deleted_at`; verify item belongs to authenticated user
  - Done: Item excluded from future queries; 403 if wrong user; 404 if not found
- [ ] Register wardrobe router in `app/main.py`
  - Done: Endpoints visible in `/docs`
- [ ] Write integration tests for full wardrobe lifecycle (tag → confirm → save → list → delete)
  - Done: Full flow tested end-to-end

---

## Phase 11: Outfits API Endpoints

- [ ] Implement `POST /outfits/suggest` — validate request body, fetch available items from wardrobe/catalog based on `source` param, call Claude suggest service
  - Done: Returns 3–5 outfit dicts with `slots` and `style_note`
- [ ] Implement `GET /outfits` — list saved Lookbook outfits for authenticated user, ordered by `created_at` desc
  - Done: Returns user's saved outfits with full slot detail
- [ ] Implement `POST /outfits` — save outfit to Lookbook, validate `source` is `tryon` or `assistant`, validate slot item IDs exist
  - Done: Outfit saved and returned with assigned `id`
- [ ] Implement `DELETE /outfits/{outfit_id}` — hard delete; verify ownership
  - Done: Outfit removed; 403 if wrong user
- [ ] Register outfits router in `app/main.py`
  - Done: Endpoints visible in `/docs`
- [ ] Write integration tests for suggest → save → list → delete flow
  - Done: Full flow passes

---

## Phase 12: Try-On API Endpoints

- [ ] Implement `POST /tryon/submit` — validate slot item IDs, resolve image URLs, call Kling `submit_tryon`, return `{"job_id": ..., "status": "pending"}`
  - Done: Returns valid Kling job ID within 2 seconds
- [ ] Add rate limiting on `POST /tryon/submit` (max 10 req/min per user)
  - Done: 429 returned when limit exceeded
- [ ] Implement `GET /tryon/status/{job_id}` — call Kling `poll_tryon_status`, store result image to R2 when complete, return status dict
  - Done: Returns `complete` with R2 image URL when job finishes
- [ ] Register try-on router in `app/main.py`
  - Done: Endpoints visible in `/docs`
- [ ] Write integration tests for submit → poll (mock Kling responses for processing, complete, failed, timeout states)
  - Done: All status states handled correctly

---

## Phase 13: Flutter App Setup

- [ ] Initialize Flutter project; configure `pubspec.yaml` with all dependencies (dio, flutter_riverpod, go_router, image_picker, cached_network_image, shared_preferences, flutter_dotenv)
  - Done: `flutter pub get` succeeds; app compiles on iOS and Android
- [ ] Configure `flutter_dotenv` for environment-based API base URL
  - Done: App reads API URL from `.env` file
- [ ] Set up `dio` HTTP client with base URL, JWT auth interceptor, and error handling interceptor
  - Done: All API calls automatically include auth token
- [ ] Configure `go_router` with 4-tab `ShellRoute` (Discover, TryOn, Assistant, Wardrobe) and auth guard redirecting unauthenticated users to login
  - Done: Navigation works; unauthenticated deep links redirect to login
- [ ] Set up Riverpod providers: `authProvider`, `catalogProvider`, `wardrobeProvider`, `outfitProvider`, `tryonProvider`
  - Done: Providers compile; basic state readable in widgets
- [ ] Create reusable widget: `ItemThumbnail` (uses `CachedNetworkImage`, fixed 200×200 size, handles loading/error states)
  - Done: Thumbnail renders for any image URL without memory issues

---

## Phase 14: Flutter Auth Screens

- [ ] Build Login screen (email + password fields, "Login" CTA, "Sign up" link, loading state, error snackbar)
  - Done: Successful login stores token and navigates to main tabs
- [ ] Build Signup screen (email + password fields, "Create Account" CTA, loading state, duplicate email error handling)
  - Done: Successful signup stores token and navigates to main tabs
- [ ] Implement token persistence using `shared_preferences` (store/retrieve/delete on logout)
  - Done: App remembers login across restarts; logout clears token
- [ ] Build auth guard: check for stored token on app launch; route to login or main tabs accordingly
  - Done: Cold-start takes user to correct screen

---

## Phase 15: Flutter Wardrobe Tab

- [ ] Build Wardrobe tab with category tabs (All, Tops, Bottoms, Shoes, Outerwear, Accessories)
  - Done: Tabs filter grid; correct items shown per category
- [ ] Build wardrobe item grid using `GridView.builder` (lazy rendering, 2-column layout)
  - Done: 50+ items render at 60 fps on mid-range Android
- [ ] Implement sort toggle (Color / Recently Added)
  - Done: Grid re-renders in correct order on toggle
- [ ] Build "Add Item" flow: tap "+" → `image_picker` (camera/gallery) → upload to pre-signed R2 URL → call `POST /wardrobe/tag` → show confirmation card
  - Done: Full photo-to-tag flow works end-to-end
- [ ] Build tag confirmation card: show detected tags; allow inline edits per field; "Save" calls `POST /wardrobe`
  - Done: User can correct tags before saving; item appears in grid immediately
- [ ] Build wardrobe item detail screen (full image, all tags, times used, Edit tags, Delete with confirmation dialog)
  - Done: Delete triggers soft-delete API call; item removed from grid

---

## Phase 16: Flutter TryOn Tab

- [ ] Build outfit canvas with clothing slots (Top, Bottom, Shoes, Accessory; optional Outerwear, Bag) showing category icons when empty or item thumbnails when filled
  - Done: Slots render correctly; filled/empty states visually distinct
- [ ] Build slot browser bottom sheet (category-scoped, horizontal image scroll, swipe-up to full-screen grid)
  - Done: Tapping a slot opens correct category items; item selectable by tap
- [ ] Implement full-screen item browser with filters (color, brand, style, pattern, fit) calling `GET /catalog/search`
  - Done: Filters update item grid in real time
- [ ] Implement item preview/swap: tapping a filled slot reopens browser in same category; selecting new item updates slot
  - Done: Slot updates immediately on item selection
- [ ] Build "Generate" CTA: call `POST /tryon/submit`, show loading indicator, poll `GET /tryon/status/{job_id}` every 2 seconds (max 30s), display result or timeout message
  - Done: Full submit-poll-display flow works; correct error messages on failure/timeout
- [ ] Build post-generation options (Save to Lookbook, Share image, Edit Outfit)
  - Done: Save calls `POST /outfits`; Edit returns to slot canvas with items pre-filled
- [ ] Build Lookbook sub-view: grid of saved outfits; tapping re-opens outfit in TryOn with slots pre-filled
  - Done: Saved outfits grid renders; re-open flow populates all slots correctly

---

## Phase 17: Flutter Assistant Tab

- [ ] Build parameter selection screen with chips for Occasion (8 options), Season (4), Color Preference (5), Source (3)
  - Done: All parameters selectable; defaults pre-filled
- [ ] Implement "Find Outfits" CTA: call `POST /outfits/suggest` with selected parameters; show loading state
  - Done: Loading spinner shown; results appear on success
- [ ] Build swipeable outfit card carousel (horizontal scroll, dot pagination, 3–5 cards)
  - Done: Cards swipe horizontally; dot indicator updates
- [ ] Build single outfit card: stacked product images (Top → Bottom → Shoes → extras), item names, brands, style note
  - Done: All slot items rendered; style note text displayed
- [ ] Implement "Refresh" — re-calls `POST /outfits/suggest` with same parameters
  - Done: New outfit batch replaces old cards
- [ ] Implement "Try On" button on outfit card — navigates to TryOn tab with all outfit slots pre-filled
  - Done: All slots populated from Assistant outfit without manual selection
- [ ] Implement "Save Outfit" on outfit card — calls `POST /outfits` with `source: "assistant"`
  - Done: Outfit appears in Lookbook; no try-on image generated
- [ ] Implement item detail sheet on card: tapping any item shows product info, brand, and product URL (opens in browser)
  - Done: Detail sheet appears on item tap; buy link opens browser

---

## Phase 18: Flutter Discover Tab

- [ ] Build Discover tab with static curated outfit feed (manually curated, hardcoded or from a simple JSON config)
  - Done: Feed scrolls; items display correctly
- [ ] Create seasonal edits section (e.g., "Spring Picks", "Summer Essentials") using horizontal scrollable rows
  - Done: Section headers and item rows render correctly
- [ ] Create occasion collections section (e.g., "Date Night", "Work Week")
  - Done: Collections display with occasion labels
- [ ] Ensure tapping any item in Discover opens catalog item detail sheet consistent with Assistant tab
  - Done: Item sheet opens correctly from Discover context

---

## Phase 19: AI Evaluation & Quality Gates

- [ ] Curate labeled test set of 200 clothing photos for wardrobe auto-tagging evaluation (ground truth: category, color)
  - Done: Dataset with correct labels ready
- [ ] Run Claude tagging on 200-photo eval set; compute category accuracy and color accuracy
  - Pass threshold: category ≥ 90%, color ≥ 85%
- [ ] Curate 30 outfit configurations for Kling visual QA (correct garment placement, no artifacts)
  - Done: 30 test renders collected
- [ ] Run visual QA pass on 30 Kling renders
  - Pass threshold: ≥ 27/30 renders pass (≥ 90%)
- [ ] Generate curated item-pair ground truth set for CLIP Precision@5 evaluation (≥ 50 item pairs)
  - Done: Ground truth set ready
- [ ] Compute Precision@5 on CLIP similarity results against ground truth
  - Pass threshold: Precision@5 ≥ 80%
- [ ] Rate 50 Assistant outfit parameter combinations (3 internal reviewers); compute thumbs-up rate
  - Pass threshold: ≥ 80% rated "relevant"

---

## Phase 20: Performance & Security Hardening

- [ ] Load test `GET /catalog/search` at expected traffic; verify HNSW index keeps p95 latency acceptable at 100k items
  - Done: Query time acceptable under load
- [ ] Measure Kling p95 latency across 20 test renders; verify ≤ 12 seconds
  - Done: p95 ≤ 12s or retry/fallback UX implemented
- [ ] Verify Flutter wardrobe grid renders ≥ 50 items at 60 fps on target mid-range Android device
  - Done: No scroll jank on test device
- [ ] Audit all API endpoints: confirm JWT auth enforced on all protected routes
  - Done: Unauthenticated requests to all protected routes return 401
- [ ] Verify bcrypt cost factor = 12 on all password hashing
  - Done: Correct cost factor confirmed in code and output
- [ ] Verify R2 signed image URLs expire after 15 minutes
  - Done: URL returns 403 after 15 minutes
- [ ] Add rate limiting middleware to `POST /tryon/submit` (10 req/min per user)
  - Done: Requests exceeding limit receive 429
- [ ] Confirm no PII (faces, user metadata) sent to Claude API in tagging requests; test on 20 real photos with face crops
  - Done: Face stripping verified

---

## Phase 21: Deployment

- [ ] Write production `Dockerfile` for FastAPI app (multi-stage build, non-root user)
  - Done: Image builds and runs; health check endpoint returns 200
- [ ] Configure production environment variables (strong `SECRET_KEY`, `ENV=production`)
  - Done: Config validated via `app/config.py` on startup
- [ ] Run `alembic upgrade head` on production DB; verify all tables and HNSW indexes created
  - Done: All tables present; indexes confirmed with `\d`
- [ ] Enable HTTPS on API host; verify TLS 1.2 minimum
  - Done: SSL cert active; TLS version confirmed via `openssl s_client`
- [ ] Set up log aggregation (Datadog or Logtail)
  - Done: Logs streaming from API container to log platform
- [ ] Configure R2 CORS to allow Flutter app origins in production
  - Done: CORS pre-flight succeeds from mobile emulator
- [ ] Run full end-to-end smoke test on staging: signup → add wardrobe item → get outfit suggestions → generate try-on → save to Lookbook
  - Done: All steps complete without errors on staging environment
- [ ] Build signed Flutter release builds for iOS and Android
  - Done: `.ipa` and `.apk` build without errors; install on test devices

---

## Dependencies Map

```
Phase 1 (Setup) ──────────────────────────────┐
     │                                          │
     ├──> Phase 2 (DB Schema) ─────────────────┤
     │                                          │
     ├──> Phase 3 (Auth)                        │
     │                                          │
     ├──> Phase 4 (Storage)                     │
     │                                          │
     ├──> Phase 5 (CLIP)                        ▼
     ├──> Phase 6 (Claude) ──> Phase 8 (Catalog Ingestion)
     └──> Phase 7 (Kling)           │
               │                    ▼
               │          Phase 9 (Catalog API)
               │                    │
               ├──> Phase 10 (Wardrobe API) ─────┐
               ├──> Phase 11 (Outfits API)  ──────┤──> Phase 15–18 (Flutter Features)
               └──> Phase 12 (Try-On API)  ────────┘          │
                                                               ▼
                                              Flutter Setup (Phase 13) + Auth (Phase 14)
                                                               │
                                                               ▼
                                                    Phase 19 (AI Evaluation)
                                                               │
                                                               ▼
                                                    Phase 20 (Hardening) ──> Phase 21 (Deploy)
```

**Critical Path**: Setup → DB Schema → Auth + CLIP + Claude + Kling → API Endpoints → Flutter Features → AI Eval → Hardening → Deploy

---

## Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Kling p95 latency > 12 seconds | High | Medium | Async UX with progress indicator; 30s timeout with user-friendly message; log job_id for inspection |
| Claude returns non-JSON for tagging | Medium | Medium | Retry once with stricter prompt; fallback to `{"category": "unknown"}` |
| CLIP accuracy low on non-Western garments | Medium | Medium | Expand eval set; user correction flow is first-class in UX |
| pgvector HNSW query slow at scale | Medium | Low | Benchmark at 100k items before launch; HNSW index planned from day 1 |
| Kling API pricing or availability change | High | Medium | Abstract behind internal `/tryon/` service layer; swappable provider |
| Faces sent to Claude in wardrobe photos | High | High | Face-strip / garment-crop preprocessing mandatory before any Claude API call |
| Flutter wardrobe grid jank on Android | Medium | Medium | `GridView.builder` (lazy), fixed thumbnail sizes, R2 image resizing |

---

## Phase Summary

| Phase | # Tasks | Parallel with |
|-------|---------|--------------|
| 1 — Project Setup | 9 | Nothing (run first) |
| 2 — DB Schema | 9 | Phase 3, 4, 5, 6, 7 |
| 3 — Authentication | 7 | Phase 2, 4, 5, 6, 7 |
| 4 — Storage Service | 4 | Phase 2, 3, 5, 6, 7 |
| 5 — CLIP Service | 5 | Phase 2, 3, 4, 6, 7 |
| 6 — Claude Service | 8 | Phase 2, 3, 4, 5, 7 |
| 7 — Kling Service | 4 | Phase 2, 3, 4, 5, 6 |
| 8 — Catalog Ingestion | 4 | Phase 3–7 after Phase 6 done |
| 9 — Catalog API | 4 | Phase 10, 11, 12 |
| 10 — Wardrobe API | 6 | Phase 9, 11, 12 |
| 11 — Outfits API | 6 | Phase 9, 10, 12 |
| 12 — Try-On API | 5 | Phase 9, 10, 11 |
| 13 — Flutter Setup | 6 | Phase 1–12 (parallel) |
| 14 — Flutter Auth | 4 | After Phase 3 + 13 |
| 15 — Flutter Wardrobe | 6 | After Phase 10 + 14 |
| 16 — Flutter TryOn | 7 | After Phase 9, 12 + 14 |
| 17 — Flutter Assistant | 8 | After Phase 11 + 14 |
| 18 — Flutter Discover | 4 | After Phase 14 |
| 19 — AI Evaluation | 7 | After all AI endpoints live |
| 20 — Hardening | 8 | After all features complete |
| 21 — Deployment | 8 | After Phase 20 |
| **Total** | **133** | |
