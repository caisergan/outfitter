# Product Requirements Document — Fashion App

**Version:** 1.0
**Date:** 2026-03-02
**Status:** Draft

---

## 1. Executive Summary

### Problem Statement

Young women (18–30) spend significant time mentally piecing together outfits from disconnected sources — brand websites, their own wardrobe, and social feeds — with no unified tool that lets them visualize results before committing to a purchase or look.

### Proposed Solution

A mobile-first (iOS + Android) fashion app that unifies a scraped brand catalog with the user's personal wardrobe, enables visual outfit building with AI-powered photorealistic try-on, and provides parameter-driven outfit suggestions via an LLM assistant.

### Success Criteria

| Metric | Target |
|--------|--------|
| Outfit generation (Kling render) p95 latency | ≤ 12 seconds |
| Wardrobe auto-tagging accuracy (category + color) | ≥ 90% on internal eval set |
| Assistant outfit relevance (user-rated) | ≥ 80% thumbs-up on suggested outfits |
| Day-7 retention | ≥ 35% |
| Lookbook save rate per generation | ≥ 40% |

---

## 2. User Experience & Functionality

### 2.1 User Personas

**Persona A — "The Planner" (Sofia, 24)**
Plans outfits for specific upcoming events. Wants to see exactly how an outfit will look on her body before buying anything. Shops at Mango, Stradivarius, Bershka.

**Persona B — "The Discoverer" (Elif, 21)**
Browses for style inspiration with no specific event in mind. Saves looks to revisit later. Influenced by seasonal trends and occasion-based edits.

**Persona C — "The Organizer" (Dilan, 27)**
Has a large wardrobe and struggles to rediscover items. Wants to digitize her closet and get novel outfit combinations from clothes she already owns.

---

### 2.2 App Structure

| Tab | Responsibility |
|-----|---------------|
| **Discover** | Curated outfit feed, seasonal edits, occasion collections |
| **TryOn** | Drag-and-drop outfit builder + AI photorealistic try-on |
| **Assistant** | Parameter-driven AI outfit suggestions |
| **Wardrobe** | User's personal digital closet |

---

### 2.3 User Stories & Acceptance Criteria

#### Feature: TryOn

**US-1:** As a user, I want to assemble an outfit by selecting items for each clothing slot so that I can visualize a complete look before generating a try-on.

*Acceptance Criteria:*

- Canvas shows slots: Top, Bottom, Shoes, Accessory; optional Outerwear, Bag
- Empty slots display a category icon; filled slots display item thumbnail
- Tapping any slot opens a bottom sheet with category-scoped item browser
- Bottom sheet shows category tabs + horizontal scroll; swipe-up expands to full-screen grid
- Filters available in full-screen: color, brand, style, pattern, fit
- Items sourced from both brand catalog and user's wardrobe
- Tapping a filled slot reopens the bottom sheet scoped to that exact category for easy swapping

**US-2:** As a user, I want to generate a photorealistic try-on image of my assembled outfit so that I can see how it looks on a model (or me).

*Acceptance Criteria:*

- Default model: neutral AI-generated; diverse skin tones selectable on first launch
- "Use my photo" option: user uploads selfie or full-body photo; AI maps outfit to their body
- "Generate" CTA triggers Kling API call; loading state shown during render
- Generation completes within 10 seconds for 95th percentile of requests
- Post-generation options: Save to Lookbook, Share, Regenerate (new pose/lighting), Edit Outfit

**US-3:** As a user, I want a Lookbook gallery so that I can revisit all my generated looks.

*Acceptance Criteria:*

- All saved generations appear in a personal Lookbook grid
- Each saved look retains its full item list (slots + items) for future reference
- Tapping a look re-opens it in TryOn with slots pre-filled

---

#### Feature: Outfit Assistant

**US-4:** As a user, I want to set occasion, season, color preference, and item source parameters so that the AI surfaces outfits relevant to my exact context.

*Acceptance Criteria:*

- Parameter screen exposes: Occasion (8 options), Season (4), Color preference (5), Source (My Wardrobe / Shop Catalog / Mix Both)
- All parameters optional (app uses sensible defaults if skipped)
- "Find Outfits" CTA triggers outfit generation

**US-5:** As a user, I want to browse 3–5 swipeable outfit suggestion cards so that I can compare options without overwhelming myself.

*Acceptance Criteria:*

- Cards are horizontally swipeable with dot pagination
- Each card shows stacked raw product images (Top → Bottom → Shoes → extras), item name, and brand
- Tapping any item opens a detail sheet: product info, brand, and buy link
- "Refresh" generates a new batch using the same parameters
- "Try On" sends the full outfit to TryOn with all slots pre-filled
- "Save Outfit" saves to Lookbook without generating a try-on image

**US-6:** As a user, I want the "Try On" button to seamlessly hand off the suggested outfit to TryOn so that I don't have to re-select items manually.

*Acceptance Criteria:*

- All slots in TryOn are pre-filled with the suggested outfit items
- User can swap individual items before tapping "Generate"
- Navigation goes directly to TryOn tab

---

#### Feature: Wardrobe

**US-7:** As a user, I want to photograph my physical clothing items so that the app auto-detects their attributes and adds them to my digital closet.

*Acceptance Criteria:*

- "+" triggers camera; supports flat-lay and hanging photos
- AI detects: category, subtype, dominant colors, pattern, fit, style tags within 5 seconds of photo submission
- Confirmation card shown before saving; user can correct any detected tag
- Item saved and immediately available in TryOn slot browser and Assistant

**US-8:** As a user, I want to browse and filter my wardrobe so that I can find specific items quickly.

*Acceptance Criteria:*

- Category tabs: All, Tops, Bottoms, Shoes, Outerwear, Accessories
- Sort options: Color, Recently Added
- Default view: grid; toggle to list view
- Grid renders ≥ 50 items without visible scroll jank (60 fps on mid-range Android)

**US-9:** As a user, I want an item detail view that lets me find matching pieces and edit metadata so that I can maintain an accurate closet.

*Acceptance Criteria:*

- Detail screen shows full image, all tags, and number of times used in outfit suggestions
- "Find matching items" opens Assistant with the item pre-locked as an anchor piece
- Tags editable inline
- Delete removes item from wardrobe and from any saved outfits referencing it (soft-delete with user confirmation)

---

### 2.4 Non-Goals (Out of Scope for MVP)

- Social/community feed or following other users
- In-app purchasing or affiliate checkout
- Brand catalog editing by end users (developer-maintained only)
- Android tablet or iPad-optimized layouts
- Offline mode
- Push notification system
- Localization beyond English

---

## 3. AI System Requirements

### 3.1 Models & APIs

| Component | Model / API | Purpose |
|-----------|-------------|---------|
| Try-on generation | Kling API | Photorealistic outfit rendering in TryOn |
| Semantic item matching | CLIP (OpenAI ViT-based) | Embedding catalog + wardrobe items for similarity search |
| Outfit suggestion logic | Claude (Anthropic) | Generating outfit combos from parameters, style note generation |
| Wardrobe auto-tagging | Claude (vision) | Classifying photographed clothing items |

### 3.2 CLIP & Vector Search

- All catalog and wardrobe images embedded with CLIP at ingest time
- Embeddings stored in PostgreSQL via `pgvector` extension
- Similarity search used by Assistant to find semantically matching pieces
- Re-embedding triggered on wardrobe item add/edit

### 3.3 Evaluation Strategy

| AI Component | Evaluation Method | Pass Threshold |
|---|---|---|
| Wardrobe auto-tagging | Internal labeled test set of 200 clothing photos | ≥ 90% category accuracy, ≥ 85% color accuracy |
| Assistant outfit relevance | Manual rating by 3 internal reviewers on 50 parameter combinations | ≥ 80% rated "relevant" |
| Kling try-on quality | Visual QA (correct garment placement, no artifacts) on 30 test renders | ≥ 90% pass rate |
| CLIP semantic matching | Precision@5 on curated item-pair ground truth set | ≥ 80% |

---

## 4. Technical Specifications

### 4.1 Architecture Overview

```
Mobile App (Flutter)
        │
        ▼
FastAPI Backend
        │
  ┌─────┴──────┐
  │            │
PostgreSQL   S3 / Cloudflare R2
(+ pgvector)  (images, try-ons)
  │
  ├── Catalog Table (brand items + CLIP embeddings)
  ├── Wardrobe Table (user items + CLIP embeddings)
  ├── Outfits Table (saved looks + slot → item mapping)
  └── Users Table (profile, preferences)
        │
        ├── Claude API (Assistant + tagging)
        ├── Kling API (try-on generation)
        └── CLIP inference (embedding service)
```

### 4.2 Backend Endpoints (FastAPI)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/catalog/search` | GET | Filter catalog items by category, color, brand, style, fit |
| `/catalog/similar/{item_id}` | GET | Return semantically similar items via pgvector |
| `/wardrobe` | GET/POST/DELETE | CRUD for user wardrobe items |
| `/wardrobe/tag` | POST | Submit wardrobe photo → Claude returns auto-detected tags |
| `/outfits/suggest` | POST | Submit parameters → Claude returns outfit combos |
| `/outfits` | GET/POST/DELETE | CRUD for saved outfits and Lookbook |
| `/tryon/submit` | POST | Submit outfit slot config → Kling job ID returned |
| `/tryon/status/{job_id}` | GET | Poll Kling job status; return image URL when complete |

### 4.3 Database Schema (Key Tables)

**catalog_items**

```
id, brand, category, subtype, name, color[], pattern, fit,
style_tags[], image_url, product_url, clip_embedding (vector),
created_at, updated_at
```

**wardrobe_items**

```
id, user_id, category, subtype, color[], pattern, fit,
style_tags[], image_url, clip_embedding (vector), times_used,
created_at, updated_at
```

**saved_outfits**

```
id, user_id, source (tryon | assistant), slots (JSONB),
generated_image_url, created_at
```

### 4.4 Integration Points

| Service | Integration Type | Notes |
|---------|-----------------|-------|
| Kling API | REST (async job poll) | Submit → poll until complete; handle timeout at 30s |
| Claude API | REST (Anthropic SDK) | Used for Assistant suggestions and wardrobe photo tagging |
| CLIP | Self-hosted or managed inference endpoint | Must support batch embedding at ingest |
| S3 / Cloudflare R2 | SDK (boto3 / r2) | Pre-signed URLs for client-side image upload |
| PostgreSQL + pgvector | SQLAlchemy ORM | pgvector `<->` operator for cosine similarity |

### 4.5 Security & Privacy

- All API endpoints require JWT authentication (issued at signup/login)
- Wardrobe photos stored in user-scoped S3 prefixes; access via signed URLs (15-min expiry)
- No wardrobe photos or user data shared with third parties other than Claude API (for tagging) and Kling API (for try-on)
- Claude API calls containing wardrobe photos must not include personally identifiable user metadata
- Data deletion: user account deletion triggers hard delete of wardrobe items and generated images within 30 days
- HTTPS enforced on all endpoints; TLS 1.2 minimum

---

## 5. Risks & Roadmap

### 5.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Kling API latency exceeds 12s p95 | Medium | High | Async UX with progress indicator; retry logic; fallback message if >30s |
| Kling API availability / pricing change | Medium | High | Abstract behind internal `/tryon` service layer for provider swap |
| CLIP tagging low accuracy on non-Western garment styles | Medium | Medium | Expand evaluation set; allow user correction flow |
| pgvector query latency on large catalogs | Low | Medium | Add HNSW index; benchmark at 100k items before launch |
| Claude API token cost at scale | Low | Medium | Cache outfit suggestions for identical parameter combos (TTL 24h) |
| User photos containing faces sent to Claude | High | High | Strip faces / crop to garment region before sending to Claude for tagging |

### 5.2 Phased Roadmap

#### MVP (Phase 1)

- TryOn: slot builder, Kling try-on with default model, Lookbook save
- Assistant: parameter screen + outfit card swiper, Try On handoff, Save Outfit
- Wardrobe: camera add, Claude auto-tagging, category browsing, item detail
- Discover tab: static curated feed (manually curated content, no personalization)
- Auth: signup/login (email + password)
- Catalog: Mango only

#### v1.1 (Phase 2)

- "Use my photo" try-on (user selfie → Kling)
- Catalog expanded: Stradivarius, Bershka
- TryOn: Regenerate with new pose/lighting
- Wardrobe: "Find matching items" → Assistant anchor piece
- Discover: personalization based on saved outfit tags

#### v2.0 (Phase 3)

- Discover: algorithm-driven personalized feed
- Assistant: multi-turn refinement ("more casual", "add a bag")
- Wardrobe: outfit history and wear-frequency analytics
- Push notifications: weekly outfit suggestions
- Localization: Turkish + English

---

*End of PRD*
