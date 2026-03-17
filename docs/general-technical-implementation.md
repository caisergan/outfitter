# Technical Implementation Guide — Fashion App

**Version:** 1.0
**Date:** 2026-03-02
**Status:** Draft
**Based on:** PRD v1.0

---

## Table of Contents

1. [System Architecture](#1-system-architecture)
2. [Backend Setup (FastAPI)](#2-backend-setup-fastapi)
3. [Database Setup (PostgreSQL + pgvector)](#3-database-setup-postgresql--pgvector)
4. [API Reference](#4-api-reference)
5. [AI Integrations](#5-ai-integrations)
6. [Storage (S3 / Cloudflare R2)](#6-storage-s3--cloudflare-r2)
7. [Authentication](#7-authentication)
8. [Mobile App (Flutter)](#8-mobile-app-flutter)
9. [Environment Configuration](#9-environment-configuration)
10. [Deployment](#10-deployment)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. System Architecture

The app is composed of four main layers:

```
Flutter Mobile App (iOS + Android)
           │
           ▼ HTTPS / REST
FastAPI Backend (Python)
           │
   ┌───────┴────────┐
   ▼                ▼
PostgreSQL        S3 / Cloudflare R2
(+ pgvector)      (images, try-ons)
   │
   ├── catalog_items   (brand catalog + CLIP embeddings)
   ├── wardrobe_items  (user closet + CLIP embeddings)
   ├── saved_outfits   (Lookbook)
   └── users           (profile, preferences)
           │
   ┌───────┼───────────┐
   ▼       ▼           ▼
Claude   Kling       CLIP
API      API         Service
```

### Technology Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Dart) |
| Backend | FastAPI (Python 3.11+) |
| Database | PostgreSQL 15 + pgvector |
| ORM | SQLAlchemy 2.0 (async) |
| Image storage | S3 or Cloudflare R2 |
| Try-on AI | Kling API |
| Assistant + Tagging | Claude API (Anthropic) |
| Semantic search | CLIP (ViT-based) + pgvector |
| Auth | JWT (python-jose) |

---

## 2. Backend Setup (FastAPI)

### Prerequisites

- Python 3.11+
- PostgreSQL 15 with `pgvector` extension
- An S3-compatible bucket (AWS S3 or Cloudflare R2)
- API keys: Anthropic (Claude), Kling

### Installation

```bash
git clone https://github.com/your-org/fashion-app-backend.git
cd fashion-app-backend

python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

pip install -r requirements.txt
```

**`requirements.txt`**

```
fastapi==0.111.0
uvicorn[standard]==0.29.0
sqlalchemy[asyncio]==2.0.29
asyncpg==0.29.0
pgvector==0.2.5
anthropic==0.25.0
boto3==1.34.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.9
httpx==0.27.0
pillow==10.3.0
open-clip-torch==2.24.0
```

### Running Locally

```bash
# Copy and fill in your env vars
cp .env.example .env

# Apply database migrations
alembic upgrade head

# Start the server
uvicorn app.main:app --reload --port 8000
```

The API will be available at `http://localhost:8000`.
Interactive docs: `http://localhost:8000/docs`

### Project Structure

```
app/
├── main.py               # App entrypoint, router registration
├── config.py             # Settings from environment
├── database.py           # Async SQLAlchemy engine + session
├── models/               # SQLAlchemy ORM models
│   ├── catalog.py
│   ├── wardrobe.py
│   ├── outfit.py
│   └── user.py
├── routers/              # Route handlers
│   ├── catalog.py
│   ├── wardrobe.py
│   ├── outfits.py
│   └── tryon.py
├── services/             # Business logic
│   ├── claude_service.py
│   ├── kling_service.py
│   ├── clip_service.py
│   └── storage_service.py
├── schemas/              # Pydantic request/response models
└── auth/                 # JWT middleware
```

---

## 3. Database Setup (PostgreSQL + pgvector)

### Enable pgvector

```sql
-- Run once on your PostgreSQL instance
CREATE EXTENSION IF NOT EXISTS vector;
```

### Schema

#### `users`

```sql
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    skin_tone   TEXT,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);
```

#### `catalog_items`

```sql
CREATE TABLE catalog_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand           TEXT NOT NULL,
    category        TEXT NOT NULL,        -- top, bottom, shoes, accessory, outerwear, bag
    subtype         TEXT,                 -- e.g. "midi skirt", "sneaker"
    name            TEXT NOT NULL,
    color           TEXT[],
    pattern         TEXT,
    fit             TEXT,
    style_tags      TEXT[],
    image_url       TEXT NOT NULL,
    product_url     TEXT,
    clip_embedding  VECTOR(512),
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

-- Cosine similarity index for fast vector search
CREATE INDEX ON catalog_items USING hnsw (clip_embedding vector_cosine_ops);
```

#### `wardrobe_items`

```sql
CREATE TABLE wardrobe_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category        TEXT NOT NULL,
    subtype         TEXT,
    color           TEXT[],
    pattern         TEXT,
    fit             TEXT,
    style_tags      TEXT[],
    image_url       TEXT NOT NULL,
    clip_embedding  VECTOR(512),
    times_used      INT DEFAULT 0,
    deleted_at      TIMESTAMPTZ,          -- soft delete
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX ON wardrobe_items USING hnsw (clip_embedding vector_cosine_ops);
```

#### `saved_outfits`

```sql
CREATE TABLE saved_outfits (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source              TEXT NOT NULL CHECK (source IN ('playground', 'assistant')),
    slots               JSONB NOT NULL,   -- {"top": item_id, "bottom": item_id, ...}
    generated_image_url TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);
```

### Alembic Migrations

```bash
# Create a new migration after changing models
alembic revision --autogenerate -m "describe_your_change"

# Apply all pending migrations
alembic upgrade head

# Roll back one migration
alembic downgrade -1
```

---

## 4. API Reference

All endpoints require `Authorization: Bearer <token>` unless noted.

---

### Catalog

#### `GET /catalog/search`

Search catalog items with filters.

**Query Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `category` | string | No | `top`, `bottom`, `shoes`, `accessory`, `outerwear`, `bag` |
| `color` | string | No | Comma-separated color names |
| `brand` | string | No | Brand name (e.g. `mango`) |
| `style` | string | No | Style tag |
| `fit` | string | No | Fit descriptor |
| `limit` | int | No | Max results (default: 20) |
| `offset` | int | No | Pagination offset (default: 0) |

**Response**

```json
{
  "items": [
    {
      "id": "uuid",
      "brand": "mango",
      "category": "top",
      "name": "Linen Shirt",
      "color": ["white"],
      "image_url": "https://cdn.example.com/item.jpg",
      "product_url": "https://mango.com/item"
    }
  ],
  "total": 84
}
```

---

#### `GET /catalog/similar/{item_id}`

Return semantically similar items using CLIP embeddings and pgvector.

**Path Parameters**

| Name | Type | Description |
|------|------|-------------|
| `item_id` | UUID | Source item to match against |

**Query Parameters**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `limit` | int | 10 | Number of results |
| `source` | string | `catalog` | `catalog`, `wardrobe`, or `both` |

**Response**

```json
{
  "items": [
    {
      "id": "uuid",
      "similarity": 0.92,
      "name": "Relaxed Linen Blouse",
      "category": "top",
      "image_url": "https://cdn.example.com/item2.jpg"
    }
  ]
}
```

---

### Wardrobe

#### `GET /wardrobe`

List the authenticated user's wardrobe items.

**Query Parameters**

| Name | Type | Description |
|------|------|-------------|
| `category` | string | Filter by category |
| `sort` | string | `color` or `recent` (default: `recent`) |
| `limit` | int | Max results (default: 50) |
| `offset` | int | Pagination offset |

---

#### `POST /wardrobe`

Add a pre-tagged item to the wardrobe. Used after confirming auto-detected tags from `/wardrobe/tag`.

**Request Body**

```json
{
  "category": "top",
  "subtype": "blouse",
  "color": ["cream", "beige"],
  "pattern": "solid",
  "fit": "relaxed",
  "style_tags": ["casual", "linen"],
  "image_url": "https://r2.example.com/user-uploads/uuid.jpg"
}
```

---

#### `DELETE /wardrobe/{item_id}`

Soft-delete a wardrobe item. Sets `deleted_at` and removes it from future outfit suggestions.

---

#### `POST /wardrobe/tag`

Submit a clothing photo and receive auto-detected tags from Claude Vision.

**Request**

`multipart/form-data` with field `file` (JPEG or PNG, max 10 MB).

**Response**

```json
{
  "category": "bottom",
  "subtype": "midi skirt",
  "color": ["black"],
  "pattern": "solid",
  "fit": "a-line",
  "style_tags": ["elegant", "minimal"],
  "confidence": 0.94
}
```

> **Note:** The user must confirm or correct these tags before calling `POST /wardrobe` to save the item.

---

### Outfits

#### `POST /outfits/suggest`

Generate 3–5 outfit suggestions from parameters using the Claude Assistant.

**Request Body**

```json
{
  "occasion": "brunch",
  "season": "spring",
  "color_preference": "neutral",
  "source": "mix"
}
```

| Field | Options |
|-------|---------|
| `occasion` | `casual`, `work`, `brunch`, `date`, `party`, `beach`, `travel`, `gym` |
| `season` | `spring`, `summer`, `autumn`, `winter` |
| `color_preference` | `neutral`, `bold`, `pastel`, `monochrome`, `earthy` |
| `source` | `wardrobe`, `catalog`, `mix` |

**Response**

```json
{
  "outfits": [
    {
      "slots": {
        "top": { "id": "uuid", "name": "Linen Shirt", "brand": "mango", "image_url": "..." },
        "bottom": { "id": "uuid", "name": "Wide Trousers", "brand": "mango", "image_url": "..." },
        "shoes": { "id": "uuid", "name": "Loafers", "brand": "mango", "image_url": "..." }
      },
      "style_note": "A relaxed spring look ideal for a sunny brunch."
    }
  ]
}
```

---

#### `GET /outfits`

List the authenticated user's saved Lookbook outfits.

---

#### `POST /outfits`

Save an outfit to the Lookbook.

**Request Body**

```json
{
  "source": "playground",
  "slots": {
    "top": "item-uuid",
    "bottom": "item-uuid",
    "shoes": "item-uuid"
  },
  "generated_image_url": "https://r2.example.com/tryon/uuid.jpg"
}
```

---

#### `DELETE /outfits/{outfit_id}`

Delete a saved outfit.

---

### Try-On

#### `POST /tryon/submit`

Submit an outfit for photorealistic try-on via Kling API. Returns a job ID immediately (async).

**Request Body**

```json
{
  "slots": {
    "top": "item-uuid",
    "bottom": "item-uuid",
    "shoes": "item-uuid"
  },
  "model_preference": "neutral",
  "user_photo_url": null
}
```

| Field | Description |
|-------|-------------|
| `model_preference` | `neutral` uses a default AI model; pass a skin tone code for alternatives |
| `user_photo_url` | Signed URL to user's full-body photo (v1.1+); `null` for default model |

**Response**

```json
{
  "job_id": "kling-job-uuid",
  "status": "pending"
}
```

---

#### `GET /tryon/status/{job_id}`

Poll the status of a try-on generation job.

**Response — in progress**

```json
{
  "job_id": "kling-job-uuid",
  "status": "processing"
}
```

**Response — complete**

```json
{
  "job_id": "kling-job-uuid",
  "status": "complete",
  "image_url": "https://r2.example.com/tryon/result-uuid.jpg"
}
```

**Response — failed / timeout**

```json
{
  "job_id": "kling-job-uuid",
  "status": "failed",
  "error": "generation_timeout"
}
```

> **Polling guidance:** Poll every 2 seconds. Stop after 30 seconds and surface a timeout message to the user.

---

## 5. AI Integrations

### 5.1 Claude — Wardrobe Auto-Tagging

Before sending a photo to Claude, crop it to the garment region and strip any visible faces to avoid sending PII.

```python
# services/claude_service.py
import anthropic
import base64

client = anthropic.Anthropic()

TAGGING_PROMPT = """
You are a fashion AI. Analyze this clothing item and return a JSON object with:
- category: one of [top, bottom, shoes, accessory, outerwear, bag]
- subtype: specific garment type (e.g. "midi skirt", "sneaker")
- color: list of dominant colors (e.g. ["black", "white"])
- pattern: one of [solid, striped, floral, plaid, graphic, other]
- fit: one of [fitted, relaxed, oversized, a-line, straight]
- style_tags: list of 2-4 style descriptors (e.g. ["casual", "minimal"])

Return only valid JSON. No explanation.
"""

async def tag_wardrobe_item(image_bytes: bytes, media_type: str = "image/jpeg") -> dict:
    image_b64 = base64.standard_b64encode(image_bytes).decode("utf-8")

    response = client.messages.create(
        model="claude-opus-4-6",
        max_tokens=256,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": image_b64,
                        },
                    },
                    {"type": "text", "text": TAGGING_PROMPT},
                ],
            }
        ],
    )

    return json.loads(response.content[0].text)
```

---

### 5.2 Claude — Outfit Assistant

```python
# services/claude_service.py

SUGGEST_PROMPT = """
You are a personal fashion stylist. Given the user's parameters and available items,
suggest {count} complete outfits. Each outfit must include slots: top, bottom, shoes,
and optionally accessory or outerwear.

Parameters:
- Occasion: {occasion}
- Season: {season}
- Color preference: {color_preference}
- Source: {source}

Available items (JSON list):
{items_json}

Return a JSON array of outfits. Each outfit:
{{
  "slots": {{"top": "<item_id>", "bottom": "<item_id>", "shoes": "<item_id>"}},
  "style_note": "<one sentence description>"
}}

Return only valid JSON. No explanation.
"""

async def suggest_outfits(params: dict, available_items: list) -> list:
    prompt = SUGGEST_PROMPT.format(
        count=4,
        occasion=params.get("occasion", "casual"),
        season=params.get("season", "spring"),
        color_preference=params.get("color_preference", "neutral"),
        source=params.get("source", "mix"),
        items_json=json.dumps(available_items, ensure_ascii=False),
    )

    response = client.messages.create(
        model="claude-opus-4-6",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )

    return json.loads(response.content[0].text)
```

> **Cost optimization:** Cache outfit suggestions for identical parameter combinations with a 24-hour TTL using Redis or a simple in-memory cache.

---

### 5.3 CLIP — Embedding Service

```python
# services/clip_service.py
import open_clip
import torch
from PIL import Image
import io

model, _, preprocess = open_clip.create_model_and_transforms(
    "ViT-B-32", pretrained="openai"
)
model.eval()

def embed_image(image_bytes: bytes) -> list[float]:
    """Return a 512-dim CLIP embedding for the given image bytes."""
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    tensor = preprocess(image).unsqueeze(0)

    with torch.no_grad():
        embedding = model.encode_image(tensor)
        embedding = embedding / embedding.norm(dim=-1, keepdim=True)  # normalize

    return embedding[0].tolist()
```

**Similarity query (pgvector):**

```python
# Using SQLAlchemy + pgvector
from pgvector.sqlalchemy import Vector

async def find_similar_items(embedding: list[float], limit: int = 10):
    query = (
        select(CatalogItem)
        .order_by(CatalogItem.clip_embedding.cosine_distance(embedding))
        .limit(limit)
    )
    result = await db.execute(query)
    return result.scalars().all()
```

---

### 5.4 Kling API — Try-On

```python
# services/kling_service.py
import httpx

KLING_BASE_URL = "https://api.klingai.com/v1"

async def submit_tryon(outfit_image_urls: dict, model_photo_url: str) -> str:
    """Submit a try-on job and return the Kling job ID."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{KLING_BASE_URL}/tryon/submit",
            headers={"Authorization": f"Bearer {settings.KLING_API_KEY}"},
            json={
                "garment_images": outfit_image_urls,  # {"top": url, "bottom": url, ...}
                "model_image": model_photo_url,
            },
            timeout=10.0,
        )
        response.raise_for_status()
        return response.json()["job_id"]


async def poll_tryon_status(job_id: str) -> dict:
    """Check the status of a Kling try-on job."""
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{KLING_BASE_URL}/tryon/status/{job_id}",
            headers={"Authorization": f"Bearer {settings.KLING_API_KEY}"},
            timeout=10.0,
        )
        response.raise_for_status()
        return response.json()  # {"status": "complete", "image_url": "..."}
```

---

## 6. Storage (S3 / Cloudflare R2)

User images and generated try-ons are stored in R2 (or S3) with user-scoped prefixes.

### Bucket Structure

```
fashion-app-media/
├── wardrobe/{user_id}/{item_id}.jpg     # User wardrobe photos
├── tryon/{user_id}/{job_id}.jpg         # Generated try-on images
└── catalog/{brand}/{item_id}.jpg        # Scraped brand catalog images
```

### Generating a Pre-Signed Upload URL

```python
# services/storage_service.py
import boto3
from botocore.config import Config

s3 = boto3.client(
    "s3",
    endpoint_url=settings.R2_ENDPOINT_URL,       # e.g. https://<account>.r2.cloudflarestorage.com
    aws_access_key_id=settings.R2_ACCESS_KEY_ID,
    aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
    config=Config(signature_version="s3v4"),
)

def get_upload_url(user_id: str, item_id: str) -> str:
    """Return a pre-signed URL for the client to upload directly to R2."""
    key = f"wardrobe/{user_id}/{item_id}.jpg"
    return s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": settings.R2_BUCKET, "Key": key, "ContentType": "image/jpeg"},
        ExpiresIn=900,  # 15 minutes
    )
```

---

## 7. Authentication

The API uses JWT bearer tokens.

### Signup & Login

```
POST /auth/signup   { email, password }  →  { access_token, token_type }
POST /auth/login    { email, password }  →  { access_token, token_type }
```

### Token Validation Middleware

```python
# auth/jwt.py
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id: str = payload.get("sub")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)

    user = await get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    return user
```

### Security Requirements

- Passwords hashed with bcrypt (cost factor 12)
- Tokens expire after 7 days; refresh token flow planned for v1.1
- All endpoints enforce HTTPS; TLS 1.2 minimum
- Signed image URLs expire after 15 minutes

---

## 8. Mobile App (Flutter)

### Key Packages

```yaml
# pubspec.yaml dependencies
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0               # HTTP client
  flutter_riverpod: ^2.5.0  # State management
  go_router: ^13.2.0        # Navigation
  image_picker: ^1.0.7      # Camera + gallery
  cached_network_image: ^3.3.1
  shared_preferences: ^2.2.2
  flutter_dotenv: ^5.1.0
```

### Navigation Structure

```dart
// 4-tab bottom navigation
final router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(path: '/discover',   builder: (_,__) => const DiscoverTab()),
        GoRoute(path: '/playground', builder: (_,__) => const PlaygroundTab()),
        GoRoute(path: '/assistant',  builder: (_,__) => const AssistantTab()),
        GoRoute(path: '/wardrobe',   builder: (_,__) => const WardrobeTab()),
      ],
    ),
  ],
);
```

### Try-On Polling (Flutter)

```dart
Future<String> pollTryonResult(String jobId) async {
  const maxAttempts = 15;   // 15 × 2s = 30s timeout
  const pollInterval = Duration(seconds: 2);

  for (var i = 0; i < maxAttempts; i++) {
    final response = await apiClient.get('/tryon/status/$jobId');
    final status = response.data['status'];

    if (status == 'complete') return response.data['image_url'];
    if (status == 'failed')   throw Exception('generation_failed');

    await Future.delayed(pollInterval);
  }

  throw Exception('generation_timeout');
}
```

### Try-On Handler (Full Flow)

```dart
Future<void> handleGenerate(Outfit outfit) async {
  setLoading(true);
  try {
    // 1. Submit job
    final jobId = await api.submitTryon(outfit);

    // 2. Poll for result
    final imageUrl = await pollTryonResult(jobId);

    // 3. Show result
    setGeneratedImageUrl(imageUrl);
  } on Exception catch (e) {
    showErrorSnackbar(e);
  } finally {
    setLoading(false);
  }
}
```

---

## 9. Environment Configuration

Copy `.env.example` to `.env` and fill in all values.

```bash
# .env

# Database
DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/fashionapp

# Auth
SECRET_KEY=your-256-bit-secret

# AI APIs
ANTHROPIC_API_KEY=sk-ant-...
KLING_API_KEY=kling-...

# Storage (Cloudflare R2 or AWS S3)
R2_ENDPOINT_URL=https://<account_id>.r2.cloudflarestorage.com
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET=fashion-app-media

# App
ENV=development         # development | production
LOG_LEVEL=info
```

---

## 10. Deployment

### Docker Compose (Local / Staging)

```yaml
# docker-compose.yml
services:
  api:
    build: .
    ports:
      - "8000:8000"
    env_file: .env
    depends_on:
      - db

  db:
    image: pgvector/pgvector:pg15
    environment:
      POSTGRES_DB: fashionapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

```bash
docker compose up --build
```

### Production Checklist

- [ ] Set `ENV=production` and a strong `SECRET_KEY`
- [ ] Run `alembic upgrade head` on first deploy
- [ ] Create HNSW indexes on both `clip_embedding` columns
- [ ] Enable HTTPS and set `SECURE_COOKIES=true`
- [ ] Set up R2 CORS to allow Flutter mobile app origins
- [ ] Configure rate limiting on `/tryon/submit` (max 10 req/min per user)
- [ ] Set up log aggregation (e.g. Datadog, Logtail)

---

## 11. Troubleshooting

### `pgvector` extension not found

**Cause:** pgvector not installed on the PostgreSQL instance.

**Solution:**

```bash
# Using Docker (recommended)
docker pull pgvector/pgvector:pg15

# Or install manually on the host
sudo apt install postgresql-15-pgvector
```

Then in psql:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

---

### Try-on job times out after 30 seconds

**Cause:** Kling API processing delay exceeds the timeout budget.

**Solution:**

1. Confirm the Kling API key is valid and not rate-limited.
2. Show a progress indicator in the UI while waiting — do not block the thread.
3. After 30 seconds, surface a user-friendly message: *"Generation is taking longer than usual. Try again in a moment."*
4. Log the `job_id` for manual inspection.

---

### Claude returns non-JSON response for tagging

**Cause:** Prompt injection or unexpected image content caused Claude to return a prose response.

**Solution:**

```python
try:
    tags = json.loads(response.content[0].text)
except json.JSONDecodeError:
    # Retry once with a stricter prompt, then return a default fallback
    tags = {"category": "unknown", "confidence": 0.0}
```

---

### CLIP embedding dimension mismatch in pgvector

**Cause:** Column defined with wrong vector size (e.g. 768 vs 512).

**Solution:** Confirm the model variant and redefine the column:

```sql
ALTER TABLE catalog_items ALTER COLUMN clip_embedding TYPE vector(512);
```

Use `ViT-B-32` for 512-dim embeddings. `ViT-L-14` produces 768-dim embeddings.

---

### Wardrobe grid drops below 60 fps on Android

**Cause:** Large image sizes or unbounded list rendering.

**Solution:**

- Use `CachedNetworkImage` with a fixed thumbnail size (e.g. 200×200).
- Ensure the R2 bucket serves resized thumbnails (use Cloudflare Image Resizing or a Lambda@Edge function).
- Replace `ListView` with `GridView.builder` (lazy rendering).

---

*End of Technical Implementation Guide*
