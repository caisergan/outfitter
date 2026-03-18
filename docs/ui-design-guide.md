# Outfitter — UI Design Guide

**Version:** 1.0
**Date:** March 2026
**Audience:** External Figma Designer
**Scope:** MVP (no dark mode)

---

## How to Use This Document

This guide is the single source of truth for the visual design of Outfitter. It is written foundation-first: start at Section 1 and work sequentially. Every token, measurement, and rule is defined explicitly — nothing should require a judgment call. If a value is not defined here, raise it as a question before designing around it.

The document is structured as follows:

- **Sections 1–7** define the design foundations (brand, color, type, spacing, radius, shadow, icons). Build your Figma variable library and styles from these sections before creating any components.
- **Section 8** defines the component library in detail. Build each component as a Figma component with all variants and states.
- **Section 9** defines screen layouts. Compose screens from Section 8 components only after the component library is complete.
- **Sections 10–12** define interaction, accessibility, and design rules. Reference these throughout.

---

## 1. Brand & Design Philosophy

### App Identity

**App name:** Outfitter
**Tagline concept:** "Your wardrobe, styled by AI."
**Design personality:** Clean. Confident. Editorial. Tactile. Minimal.

### Core Principle

The clothes are the UI. Every design decision must serve one goal: get the product imagery on screen as fast, large, and clean as possible. The interface chrome — headers, tabs, labels, buttons — should recede. White space is not empty space; it is the negative space that makes the clothes read.

This is not a utility app with fashion content. It is a fashion experience that happens to have utility.

### Design Personality Breakdown

| Adjective | What it means in practice |
|-----------|--------------------------|
| **Clean** | White backgrounds, no decorative fills, no gratuitous gradients |
| **Confident** | Black CTAs, bold editorial headers, decisive layout choices |
| **Editorial** | Large full-bleed images, generous vertical rhythm, content at hero scale |
| **Tactile** | Cards that feel liftable, pill chips that feel pressable, smooth spring transitions |
| **Minimal** | Every element earns its place — if it does not serve the user, remove it |

### Dark Mode

Not in scope for MVP. All designs are light mode only. Do not design dark variants at this stage.

---

## 2. Color System

### 2.1 Neutral Palette

| Token Name | Hex | RGB | Usage | Do NOT Use For |
|------------|-----|-----|-------|----------------|
| `neutral-0` | `#FFFFFF` | 255 255 255 | Page/screen background, card backgrounds on white | Text |
| `neutral-50` | `#FAFAFA` | 250 250 250 | Subtle surface differentiation within white backgrounds | Large background fills (too similar to white) |
| `neutral-100` | `#F5F5F5` | 245 245 245 | Card surface background, skeleton loader base, shortcut tile bg | Text backgrounds, borders |
| `neutral-200` | `#EEEEEE` | 238 238 238 | Divider lines between list items, subtle section separators | Text, interactive backgrounds |
| `neutral-300` | `#E5E5E5` | 229 229 229 | Borders on cards, input field default border, bottom nav top border, drag handle | Text |
| `neutral-400` | `#CCCCCC` | 204 204 204 | Disabled border states, placeholder graphics | Body text (fails contrast) |
| `neutral-500` | `#999999` | 153 153 153 | Secondary text, placeholder text in inputs, unselected tab labels, secondary metadata | Primary text, headings |
| `neutral-700` | `#555555` | 85 85 85 | Tertiary text, Caption text in dense lists | Page backgrounds |
| `neutral-900` | `#111111` | 17 17 17 | Primary text, headings, CTA button backgrounds, icon fill on selected state | Light surface backgrounds |

### 2.2 Text Colors

| Token Name | Hex | Usage |
|------------|-----|-------|
| `text-primary` | `#111111` | All headings, primary body text, labels on white backgrounds |
| `text-secondary` | `#999999` | Supporting metadata, subtitles, placeholder labels, "See all" links |
| `text-tertiary` | `#CCCCCC` | Timestamp, fine print, disabled labels |
| `text-inverse` | `#FFFFFF` | Text on black backgrounds (CTA buttons, dark overlays) |
| `text-on-accent` | `#FFFFFF` | Text on the accent gradient (story ring labels do not sit on gradient — this is for edge cases) |

### 2.3 Interactive Colors

| Token Name | Hex | Usage | Do NOT Use For |
|------------|-----|-------|----------------|
| `cta-bg` | `#111111` | Primary CTA button background, selected filter chip background | Link text on white (too heavy) |
| `cta-text` | `#FFFFFF` | Text/icon on primary CTA, text on selected filter chip | Text on white backgrounds |
| `destructive` | `#D32F2F` | Delete actions, error snackbar background, destructive CTA variant | Decorative use, warnings (use warning color) |
| `success` | `#2E7D32` | Confirmation states, success snackbar, "saved" confirmation text | General text or decorative use |
| `warning` | `#E65100` | Incomplete required field indicator, warning inline message | Decorative use |
| `link` | `#111111` | Inline text links (underlined) — same as primary text, differentiated by underline only | — |

### 2.4 Accent — AI & Story Gradient

This gradient is used exclusively for two contexts: story/collection ring borders, and AI feature entry points. Do not use it decoratively elsewhere.

| Token Name | Value | Usage |
|------------|-------|-------|
| `accent-gradient-start` | `#9B5DE5` | Gradient stop 1 (purple-violet) |
| `accent-gradient-end` | `#F15BB5` | Gradient stop 2 (pink-magenta) |
| `accent-gradient` | `linear-gradient(135deg, #9B5DE5 0%, #F15BB5 100%)` | Story ring borders, AI feature badge/icon backgrounds |

The gradient direction is 135 degrees (top-left to bottom-right). Do not reverse it. Do not use it as a button background. Do not apply it to text.

### 2.5 Overlay Colors

| Token Name | Value | Usage |
|------------|-------|-------|
| `scrim-default` | `rgba(0, 0, 0, 0.40)` | Bottom sheet scrim, modal overlay |
| `scrim-heavy` | `rgba(0, 0, 0, 0.60)` | Full-screen loading overlay when content must be fully blocked |
| `overlay-white-soft` | `rgba(255, 255, 255, 0.85)` | In-content loading state overlaid on visible content |
| `image-gradient-overlay` | `linear-gradient(to top, rgba(0,0,0,0.45) 0%, transparent 60%)` | Editorial card bottom gradient for text legibility over images |

---

## 3. Typography System

### 3.1 Font Family

**Primary font: Plus Jakarta Sans**

Reasoning: Plus Jakarta Sans is a contemporary geometric sans-serif with slightly humanist character. Compared to Inter (which skews more utilitarian), Plus Jakarta Sans has a stronger editorial personality — the diagonal leg of the 'k', the open apertures — that reads as fashion-forward without sacrificing readability. It performs well at small display sizes and at large editorial headings. It is available free on Google Fonts and imports cleanly into Figma.

**Fallback stack:** Plus Jakarta Sans → Inter → system-ui → sans-serif

Use Plus Jakarta Sans exclusively. Do not mix in a second typeface family. The type hierarchy is achieved entirely through size, weight, and color.

### 3.2 Type Scale

| Style Name | Size (px) | Line Height | Letter Spacing | Weight | Weight Name | Usage Context |
|------------|-----------|-------------|----------------|--------|-------------|---------------|
| `display` | 32px | 40px (1.25) | −0.5px | 700 | Bold | Hero/editorial splash text on large image cards |
| `heading-1` | 24px | 32px (1.33) | −0.3px | 700 | Bold | Screen titles, tab headers |
| `heading-2` | 18px | 26px (1.44) | −0.2px | 700 | Bold | Section headers ("Seasonal Edits", "Recently Saved") |
| `heading-3` | 16px | 22px (1.375) | 0px | 600 | SemiBold | Card titles, bottom sheet titles, item names |
| `body-large` | 16px | 24px (1.5) | 0px | 400 | Regular | Primary body copy, onboarding explanatory text |
| `body-regular` | 14px | 20px (1.43) | 0px | 400 | Regular | Standard list labels, item descriptions, form field text |
| `body-small` | 13px | 18px (1.38) | 0px | 400 | Regular | Supporting descriptions, snackbar text, secondary metadata |
| `label` | 12px | 16px (1.33) | 0.1px | 600 | SemiBold | Button labels, filter chip labels, tab bar labels (selected) |
| `caption` | 11px | 14px (1.27) | 0.2px | 400 | Regular | Story circle usernames, image captions, timestamp text |
| `overline` | 10px | 14px (1.4) | 0.8px | 600 | SemiBold | Category tags, attribute chip labels, metadata overlines |

### 3.3 Typography Rules

1. **Maximum 2 weights per screen view.** A screen may use Regular + Bold, or Regular + SemiBold, or SemiBold + Bold. Never mix all three simultaneously in visible content.
2. **No all-caps on body text.** The `overline` style is the only style that may be displayed in all-caps, and only for category labels (10px, tracked at +0.8px).
3. **No italics as a primary style.** Italic is reserved for the "style note" text in the Assistant suggestion card — one instance per card, maximum.
4. **No decorative typefaces.** The app wordmark ("Outfitter") uses `heading-1` size in Bold weight — it is the same typeface, not a logotype font.
5. **Truncation:** Single-line labels truncate with ellipsis at the end. Never clip or wrap where single-line is specified.
6. **Text over images:** Use `text-inverse` (#FFFFFF) with the `image-gradient-overlay` behind it. Never place dark text directly on a photograph.

---

## 4. Spacing & Layout System

### 4.1 Base Unit

All spacing is derived from a **4px base grid**. Every margin, padding, gap, and dimension must be a multiple of 4px.

### 4.2 Spacing Scale

| Token Name | Value | Usage Examples |
|------------|-------|----------------|
| `space-xs` | 4px | Icon-to-label gap, internal chip padding (vertical), tag chip internal vertical padding |
| `space-sm` | 8px | Gap between stacked metadata lines, bottom sheet drag handle top margin, card internal gap between image and label |
| `space-md` | 12px | Card internal padding (all sides), gap between filter chips, section header bottom margin |
| `space-lg` | 16px | Standard screen horizontal margin, gap between stacked form fields, grid gap in 3-column wardrobe grid |
| `space-xl` | 20px | Horizontal margin on wider content sections, vertical padding inside primary CTA button |
| `space-2xl` | 24px | Vertical gap between feed sections, section header top margin, bottom sheet header height |
| `space-3xl` | 32px | Large section separations, empty state content gap, hero card bottom margin |
| `space-4xl` | 40px | Generous padding around onboarding content, large empty state vertical offsets |
| `space-5xl` | 48px | Safe area + content offset at screen top, bottom nav height |
| `space-6xl` | 64px | Vertical offset for full-screen centered empty state illustrations |

### 4.3 Screen Margins

- **Standard horizontal content margin:** 16px on each side (`space-lg`)
- **Horizontal scroll section padding:** 16px leading padding before first item; trailing 16px after last item; the scroll row itself bleeds to screen edges
- **Full-bleed images:** 0px horizontal margin — image extends to screen edges
- **Bottom sheet content padding:** 16px horizontal, 24px top (below drag handle), 16px bottom (above system home indicator)

### 4.4 Safe Areas

- **Top:** Respect the iOS status bar safe area (~59px on iPhone 14/15, variable). Content begins below the status bar. The app header sits within the safe area inset, not below it — the header background extends behind the status bar.
- **Bottom:** Respect the iOS home indicator safe area (~34px). The bottom navigation bar sits above the home indicator, and the bar's background color extends behind the indicator zone. No interactive content should be placed in the home indicator zone.
- Design at iPhone 14 Pro resolution: **390×844pt** logical canvas.

### 4.5 Layout Grid Philosophy

Outfitter does not use a traditional 12-column Figma grid. The layout is content-driven:

- **Full-bleed zones:** Photography and generated AI images span 100% of screen width with 0px horizontal margin.
- **Padded zones:** All text, buttons, metadata, and card grids sit within the 16px horizontal margin on each side, yielding a **358px** content width on a 390px canvas.
- **Section headers:** Heading 2 text left-aligned at 16px from edge; "See all" right-aligned at 16px from edge; both on the same baseline row.
- **Horizontal scroll rows:** Overflow the 16px margin — the row starts at 16px but items can be scrolled to the screen edge. Do not cut off items with a mask at 16px.

### 4.6 Section Vertical Spacing

- Gap between two content sections (e.g., Story row to "AI Stilist" cards): **32px**
- Gap between section header row and section content: **12px**
- Gap between a screen title heading and the first content element below it: **24px**

### 4.7 Card Internal Spacing

- **Card internal padding (all card types):** 12px all sides (`space-md`)
- **Gap between card image and card text content (where applicable):** 8px (`space-sm`)

---

## 5. Border Radius System

### 5.1 Radius Token Table

| Token Name | Value | Components That Use This Radius |
|------------|-------|----------------------------------|
| `radius-none` | 0px | Full-bleed images, screen-edge dividers |
| `radius-sm` | 4px | Attribute/tag chips (small), overline badges |
| `radius-md` | 8px | Input field corners, snackbar, tooltip |
| `radius-lg` | 12px | Wardrobe item cards (3-column grid), shortcut tiles, skeleton loaders |
| `radius-xl` | 16px | Outfit cards (Discover feed), outfit slot tiles (Playground), outfit suggestion cards (Assistant) |
| `radius-2xl` | 24px | Bottom sheet top corners, large editorial feature cards, AI try-on result image |
| `radius-full` | 9999px | Pill buttons (CTA and secondary), filter chips, story circle avatar border, FAB, search bar, tag chips (28px height), spinner |

### 5.2 Component-to-Radius Mapping

| Component | Radius Token |
|-----------|-------------|
| Primary CTA button | `radius-full` |
| Secondary CTA button | `radius-full` |
| Filter chip | `radius-full` |
| Tag chip (wardrobe) | `radius-full` |
| Story circle border | `radius-full` |
| Bottom navigation FAB | `radius-full` |
| Search input bar | `radius-full` |
| Snackbar/toast | `radius-md` |
| Standard input field | `radius-md` |
| Outfit card (Discover) | `radius-xl` |
| Outfit slot tile (Playground) | `radius-xl` |
| Suggestion card (Assistant) | `radius-xl` |
| AI try-on result image | `radius-2xl` |
| Bottom sheet | `radius-2xl` (top corners only, bottom corners 0px) |
| Wardrobe item card | `radius-lg` |
| Shortcut tile | `radius-lg` |
| Skeleton loader shapes | `radius-lg` |
| Editorial feature card | `radius-xl` |

---

## 6. Elevation & Shadow System

### 6.1 Philosophy

The reference visual language avoids heavy shadows. Elevation is communicated through color difference (white card on white background uses a subtle border, not a shadow) and through very gentle drop shadows. Heavy box shadows are a violation of the brand aesthetic.

### 6.2 Elevation Levels

| Level | Shadow Value | Usage | Do NOT Use For |
|-------|-------------|-------|----------------|
| **Level 0 — Flat** | `none` | Cards that sit on colored backgrounds, full-bleed image containers, filter chips, input fields | — |
| **Level 1 — Card lift** | `0px 2px 8px rgba(0, 0, 0, 0.06)` | Outfit cards on white background, wardrobe item cards, shortcut tiles, suggestion cards | Bottom sheets (use Level 2), any element that already has a visible border |
| **Level 2 — Sheet** | `0px -4px 24px rgba(0, 0, 0, 0.10)` | Bottom sheets, modals, any sheet that floats over full-screen content | Cards within a bottom sheet |

### 6.3 Elevation Rules

- Cards that have a `neutral-300` (#E5E5E5) border do **not** also receive a shadow. Choose one: border OR Level 1 shadow. Do not combine.
- Wardrobe item cards in the 3-column grid use **Level 1 shadow** (no border) to lift against the white background.
- The bottom navigation bar uses a `neutral-300` 1px top border only — no shadow.
- The FAB uses **Level 1 shadow**.
- Snackbars use **Level 2 shadow** (they float above all content).

---

## 7. Iconography

### 7.1 Icon Style

- **Style:** Outlined (stroke-based, not filled) for all default states
- **Stroke weight:** 1.5px at 24px canvas size (scales proportionally)
- **Corner style:** Rounded joins and caps on all strokes
- **Fill:** Only on selected/active states (tab bar selected icon switches from outlined to filled)

### 7.2 Icon Set

**Recommended set: Phosphor Icons** (available as Figma plugin and open-source). Phosphor's "Regular" weight at 1.5px stroke matches the visual language. Alternative: Lucide Icons (near-identical aesthetic). Do not use Material Icons (too Android-native) or SF Symbols directly (not Figma-native).

### 7.3 Icon Sizes

| Context | Size | Notes |
|---------|------|-------|
| Tab bar icons | 24×24px | Selected state: filled variant; unselected: outlined |
| Inline icons (next to text) | 20×20px | Aligned to text midline |
| FAB "+" icon | 28×28px | White stroke on black circle |
| Bottom sheet drag handle | Not an icon — see Section 8.4 | — |
| Shortcut tile icon | 28×28px | Centered in 72×72px tile |
| Action row icons (Try-On result) | 24×24px | Stacked above label text |
| Slot tile category icon | 28×28px | Centered in slot tile |
| Remove "×" on filled slot tile | 16×16px | Inside 24×24px white circle button |
| Search icon (inside search bar) | 20×20px | `text-secondary` color |

### 7.4 Icon Colors

Icons always inherit the color context of their surrounding text:

- On white background, default state: `text-secondary` (#999999)
- On white background, selected/active: `text-primary` (#111111)
- On black background (CTA button): `text-inverse` (#FFFFFF)
- On image overlay: `text-inverse` (#FFFFFF)

Do not use the accent gradient on icons. Icon color is always flat.

### 7.5 Icons Needed Per Screen

**Bottom Navigation Bar:**
- Discover: compass or home icon (outlined → filled when selected)
- Playground: layers or grid icon
- Assistant: sparkle or wand icon
- Wardrobe: hanger or shirt icon
- FAB: plus (+) icon (always white, always 28px)

**Discover Tab:**
- Bell (notifications) — top right header
- Magnifying glass (search) — top right header
- Chevron right — "See all" rows

**Playground Tab:**
- X (close/remove) — filled slot remove button
- Arrow cycle (regenerate) — action row
- Floppy disk or bookmark (save) — action row
- Share arrow (share) — action row
- Pencil (edit) — action row

**Assistant Tab:**
- Arrows clockwise (refresh/regenerate suggestions) — top right
- Heart or bookmark (save outfit) — suggestion card
- Magic wand or sparkle (try on) — suggestion card CTA

**Wardrobe Tab:**
- Sliders or sort icon — header right
- Plus (+) — secondary FAB
- Trash (delete) — item detail action
- Magnifying glass — find matching action

**Add Item Flow:**
- Photo library icon — source picker tile
- Camera icon — source picker tile
- Import/link icon — source picker tile

---

## 8. Component Library

### 8.1 Buttons

#### 8.1.1 Primary CTA Button

**Anatomy:** Pill-shaped container + label text (optionally leading icon)

| Property | Value |
|----------|-------|
| Height | 52px |
| Width options | Full-width (matches content area = 358px) or fixed 200px for paired side-by-side use |
| Border radius | `radius-full` (9999px) |
| Background | `cta-bg` (#111111) |
| Label style | `label` (12px, SemiBold, +0.1px spacing) |
| Label color | `text-inverse` (#FFFFFF) |
| Horizontal padding | 24px each side (for fixed-width variant) |
| Icon size | 20px, 8px gap to label |

**States:**

| State | Visual Change |
|-------|--------------|
| Default | Background #111111, white text |
| Pressed | Background #333333 (lightens 10%), scale 0.98 |
| Disabled | Background #111111 at 40% opacity, text at 40% opacity, not pressable |
| Loading | Text hidden, replaced by 20px white circular spinner centered in button |

**Touch target:** The button itself is 52px tall which exceeds the 44px minimum. No additional invisible target expansion needed.

#### 8.1.2 Secondary CTA Button (Outlined)

| Property | Value |
|----------|-------|
| Height | 52px |
| Width options | Same as Primary |
| Border radius | `radius-full` |
| Background | Transparent |
| Border | 1.5px solid `text-primary` (#111111) |
| Label style | `label` (12px, SemiBold) |
| Label color | `text-primary` (#111111) |

**States:**

| State | Visual Change |
|-------|--------------|
| Default | Transparent bg, black border |
| Pressed | `neutral-100` (#F5F5F5) fill, scale 0.98 |
| Disabled | Border and text at 40% opacity |
| Loading | Same spinner, black stroke |

#### 8.1.3 Ghost / Text Button

| Property | Value |
|----------|-------|
| Height | 44px (touch target minimum) |
| Background | None |
| Border | None |
| Label style | `body-regular` (14px) with 1px underline, OR with trailing chevron icon (20px) |
| Label color | `text-primary` (#111111) |

Used for: "See all" section links, inline navigation links. Not for primary or secondary actions.

#### 8.1.4 Destructive Button

Same dimensions as Primary CTA. Background `destructive` (#D32F2F), white text. Use only for irreversible actions (delete item, remove from wardrobe). Always paired with a confirmation step — do not trigger destructive action on first tap.

#### 8.1.5 Small Action Button (Icon + Label stacked, used in AI result action row)

| Property | Value |
|----------|-------|
| Layout | Icon (24px) centered above label |
| Label style | `caption` (11px, Regular) |
| Label color | `text-secondary` (#999999) |
| Touch target | 52×52px minimum tap area around icon+label unit |
| Background | None (transparent, floating on white or near-white) |

---

### 8.2 Cards

#### 8.2.1 Outfit Card (Discover Feed)

**Anatomy:** Image container → optional overlay gradient → optional pill tag (bottom-left) → optional title text (bottom, on gradient)

| Property | Value |
|----------|-------|
| Width | Full content width: 358px |
| Height | 420px |
| Border radius | `radius-xl` (16px) |
| Image | Full bleed, object-fit: cover |
| Elevation | Level 1 shadow |
| Tag pill position | 12px from bottom, 12px from left edge of card |
| Tag pill style | `radius-full`, 28px height, 10px horizontal padding, `label` text, white bg, `text-primary` color |
| Title text position | 16px from bottom, 16px from left, above gradient overlay |
| Title text style | `heading-3` (16px SemiBold), `text-inverse` (#FFFFFF) |
| Overlay gradient | `image-gradient-overlay` applied when title text is present |

**States:**

| State | Visual Change |
|-------|--------------|
| Default | Card at rest with Level 1 shadow |
| Pressed | Scale 0.97, shadow reduces to Level 0 |

#### 8.2.2 Outfit Suggestion Card (Assistant Swiper)

**Anatomy:** Product image stack (3 layered thumbnails) → item list rows → style note → CTA row

| Property | Value |
|----------|-------|
| Width | Full content width: 358px |
| Total card height | ~480px |
| Border radius | `radius-xl` (16px) |
| Background | `neutral-0` (#FFFFFF) |
| Elevation | Level 1 shadow |
| Card padding | 16px all sides |

**Image stack zone:**
- Height: 240px
- Layout: 3 square product images (Top, Bottom, Shoes) arranged in a triangle composition (large center-left Top image ~160×200px, smaller Bottom top-right ~96×96px, smaller Shoes bottom-right ~96×96px)
- Images have `radius-lg` (12px) corners
- Images have a 1px `neutral-300` border

**Item list zone:**
- Below image stack, top margin 12px
- 3 rows, each row: thumbnail 40×40px (`radius-sm`) + item name (`body-regular`) + brand name (`caption`, `text-secondary`) — tappable row navigates to item detail
- Row height: 48px

**Style note:**
- Italic `body-small` (13px), `text-secondary` (#999999)
- Top margin: 12px
- Max 2 lines, truncates

**CTA row:**
- Top margin: 16px
- Two buttons side by side, equal width: "Try On" (Primary CTA, half-width) and "Save" (Secondary CTA, half-width)
- Gap between buttons: 8px

**Swipe behavior:** Card swiped right = saved; swiped left = dismissed. Visual indicator: on swipe right, a "Saved" green label fades in on the card. On swipe left, a "Skip" gray label fades in. These labels are centered on the card at `heading-2` size.

#### 8.2.3 Wardrobe Item Card (3-Column Grid)

| Property | Value |
|----------|-------|
| Width | (358px − 2×8px gap) ÷ 3 = 114px |
| Aspect ratio | 1:1 (square) |
| Border radius | `radius-lg` (12px) |
| Image | Object-fit: cover, fills entire card |
| Background | `neutral-100` (#F5F5F5) when no image loaded |
| Elevation | Level 1 shadow |
| Label | No label by default (image-only card) |
| Selected state | 2px `cta-bg` (#111111) border overlay, checkmark icon top-right (multi-select mode only) |

#### 8.2.4 Shortcut Tile (Icon Grid)

| Property | Value |
|----------|-------|
| Width | 72px |
| Height | 72px |
| Border radius | `radius-lg` (12px) |
| Background | `neutral-100` (#F5F5F5) |
| Icon | 28px, centered vertically, icon color `text-primary` |
| Label | Below tile, 4px gap, `caption` style, `text-secondary`, center-aligned, max 10 characters |
| Touch target | The entire 72px tile is the touch target |

---

### 8.3 Bottom Navigation Bar

**Anatomy:** White bar spanning full screen width → 4 tab slots + 1 center FAB

| Property | Value |
|----------|-------|
| Bar height | 83px total (49px visible bar + 34px home indicator safe area) |
| Background | `neutral-0` (#FFFFFF) |
| Top border | 1px solid `neutral-300` (#E5E5E5) |
| Blur / frosted glass | None |

**Tab slots (4 tabs):**

| Property | Value |
|----------|-------|
| Layout | Icon centered above label |
| Icon size | 24px |
| Label | `overline` (10px, SemiBold), always visible (all 4 tabs show label) |
| Selected icon | Filled variant, `text-primary` (#111111) |
| Selected label | `text-primary` (#111111) |
| Unselected icon | Outlined variant, `text-secondary` (#999999) |
| Unselected label | `text-secondary` (#999999) |
| Touch target | Tap area spans full tab slot width, minimum 44px height |

**Center FAB (Add action):**

| Property | Value |
|----------|-------|
| Diameter | 56px |
| Border radius | `radius-full` (9999px) |
| Background | `cta-bg` (#111111) |
| Icon | Plus (+), 28px, white |
| Position | Centered horizontally, vertically centered within the 49px bar (not the full 83px) |
| Elevation | Level 1 shadow |

The FAB is NOT a tab. It does not have a selected state. Tapping it always opens the Add Item bottom sheet. The 2 tabs to the left (Discover, Playground) and 2 tabs to the right (Assistant, Wardrobe) are spaced evenly around the FAB.

---

### 8.4 Bottom Sheet / Modal

**Anatomy:** Scrim → Sheet container → Drag handle → Optional header → Scrollable content

| Property | Value |
|----------|-------|
| Sheet background | `neutral-0` (#FFFFFF) |
| Top corners border radius | `radius-2xl` (24px) |
| Bottom corners | 0px (flush to screen bottom) |
| Scrim | `scrim-default` (rgba(0,0,0,0.40)) |
| Drag handle width | 36px |
| Drag handle height | 4px |
| Drag handle border radius | `radius-full` |
| Drag handle color | `neutral-300` (#E5E5E5) |
| Drag handle position | Centered horizontally, 8px from top of sheet |
| Elevation | Level 2 shadow |

**Height behavior:**
- **Minimum height:** 50% of screen height (422px on 844px canvas)
- **Maximum height:** 100% of screen height (full-screen, status bar stays visible)
- **Snap points:** 50%, 75%, 100%
- Spring animation: damping ratio 0.85, stiffness medium

**Optional header:**
- Title: `heading-3` (16px SemiBold), centered horizontally
- Close button: 24px X icon, positioned 16px from right, vertically centered with title
- Header height: 52px (includes drag handle zone)
- Bottom divider: 1px `neutral-200` below header when content scrolls

**Content zone:**
- 16px horizontal padding
- Content begins 8px below drag handle (or below header if header present)
- 16px bottom padding (above home indicator safe area)

---

### 8.5 Filter Chips / Tab Chips

**Anatomy:** Pill container → Label text

| Property | Value |
|----------|-------|
| Height | 34px |
| Horizontal padding | 14px each side |
| Border radius | `radius-full` |
| Label style | `label` (12px, SemiBold) |

**States:**

| State | Background | Text Color | Border |
|-------|-----------|------------|--------|
| Selected | `cta-bg` (#111111) | `text-inverse` (#FFFFFF) | None |
| Unselected | `neutral-100` (#F5F5F5) | `text-primary` (#111111) | None |
| Disabled | `neutral-100` (#F5F5F5) | `neutral-400` (#CCCCCC) | None |

**Layout:**
- Horizontal scroll row, no wrapping
- Gap between chips: 8px
- Leading padding of scroll row: 16px
- Trailing padding: 16px
- Row height: 34px chip + 8px vertical margin above + 8px below = 50px total row height

**Used in:** Playground slot browser (category filter), Wardrobe tab category bar, Assistant parameter selection (wrapping variant — see Section 9.4)

---

### 8.6 Story Circles (Discover Tab)

**Anatomy:** Gradient ring → Avatar image → Label below

| Property | Value |
|----------|-------|
| Avatar diameter | 64px |
| Border ring thickness | 2.5px |
| Ring gap (between ring and image) | 2px (white gap between gradient ring and avatar) |
| Ring style (unviewed) | `accent-gradient` (135deg, #9B5DE5 → #F15BB5) |
| Ring style (viewed) | Solid `neutral-300` (#E5E5E5) |
| Avatar border radius | `radius-full` |
| Label style | `caption` (11px, Regular) |
| Label color | `text-secondary` (#999999) |
| Label alignment | Center-aligned, below avatar, 4px gap |
| Label max width | 64px (truncate at ~8 characters with ellipsis) |
| Touch target | 64px diameter image + label area = 64px wide × 84px tall |

**Layout:**
- Horizontal scroll row
- Gap between circles: 16px
- Row leading padding: 16px
- Row height: 64px circle + 4px gap + 14px label = 82px total

---

### 8.7 Input Fields

#### 8.7.1 Standard Input

| Property | Value |
|----------|-------|
| Height | 48px |
| Width | Full content width (358px) |
| Border radius | `radius-md` (8px) |
| Background | `neutral-0` (#FFFFFF) |
| Border default | 1px solid `neutral-300` (#E5E5E5) |
| Border focus | 1.5px solid `text-primary` (#111111) |
| Border error | 1.5px solid `destructive` (#D32F2F) |
| Placeholder text | `body-regular` (14px), `text-secondary` (#999999) |
| Input text | `body-regular` (14px), `text-primary` (#111111) |
| Horizontal padding | 14px |
| Label above field | `body-small` (13px), `text-secondary`, 4px below label to field |

**States:**

| State | Border |
|-------|--------|
| Default (unfocused) | 1px `neutral-300` |
| Focused | 1.5px `text-primary` (#111111) |
| Filled (has value) | 1px `neutral-300` |
| Error | 1.5px `destructive` (#D32F2F) + error message `caption` in `destructive` color below |
| Disabled | 1px `neutral-400`, background `neutral-100`, text `text-tertiary` |

#### 8.7.2 Search Bar (Pill Variant)

| Property | Value |
|----------|-------|
| Height | 44px |
| Width | Full content width (358px) |
| Border radius | `radius-full` (9999px) |
| Background | `neutral-100` (#F5F5F5) |
| Border | None |
| Leading icon | Magnifying glass, 20px, `text-secondary`, 14px from left edge |
| Placeholder | `body-regular`, `text-secondary` |
| Input text | `body-regular`, `text-primary` |
| Horizontal padding | 14px left (icon zone) + 40px from edge to account for icon, 14px right |

---

### 8.8 Tag / Attribute Chips (Wardrobe)

**Anatomy:** Pill container → Label text (+ optional ✕ icon in editable mode)

| Property | Value |
|----------|-------|
| Height | 28px |
| Horizontal padding | 10px each side |
| Border radius | `radius-full` |
| Label style | `overline` (10px, SemiBold) |

**Variants:**

| Variant | Background | Text Color | Border |
|---------|-----------|------------|--------|
| Default (read) | `neutral-100` (#F5F5F5) | `text-primary` (#111111) | None |
| Selected (active filter) | `cta-bg` (#111111) | `text-inverse` (#FFFFFF) | None |
| Editable | `neutral-100` (#F5F5F5) | `text-primary` (#111111) | None + ✕ icon |

**Editable state:**
- Add ✕ icon (12px) after label text, 4px gap
- Tapping ✕ removes the tag with a fade-out animation (150ms)
- The chip itself (not just the ✕) triggers the edit/remove action

**Used in:** Wardrobe item detail tags (category, color, pattern, fit, style), Add Item tag confirmation sheet

---

### 8.9 Loading & Empty States

#### 8.9.1 Skeleton Loader

| Component | Skeleton Shape | Dimensions |
|-----------|----------------|------------|
| Outfit card (Discover) | Rounded rect | 358×420px, `radius-xl` |
| Wardrobe item card | Square rounded rect | 114×114px, `radius-lg` |
| Story circle | Circle | 64×64px |
| Section header + "see all" | Two rects side by side | 120×18px (left), 48×14px (right) |
| Suggestion card | Rounded rect | 358×480px, `radius-xl` |

**Shimmer animation:**
- Base color: `neutral-100` (#F5F5F5)
- Shimmer highlight: `neutral-200` (#EEEEEE)
- Direction: left to right sweep
- Duration: 1.4 seconds, looping, ease-in-out

#### 8.9.2 Spinner

| Property | Value |
|----------|-------|
| Size | 24px |
| Stroke | `text-primary` (#111111), 2px, or `text-inverse` (#FFFFFF) on dark bg |
| Animation | Continuous rotation, 800ms per revolution |
| Used in | Button loading states, full-screen loading overlay |

#### 8.9.3 Full-Screen Loading Overlay (AI Try-On Generation)

| Property | Value |
|----------|-------|
| Background | `overlay-white-soft` (rgba(255,255,255,0.85)) |
| Spinner | 32px, `text-primary`, centered |
| Status text | `body-regular` (14px), `text-secondary`, 16px below spinner |
| Status text behavior | Fades between messages every 2.5 seconds (see Section 10 for messages) |

#### 8.9.4 Empty Wardrobe State

**Art direction:** Minimal line-art illustration — a single coat hanger drawn in thin strokes (#CCCCCC), hanging alone in the center of the frame. No color fill, no shadow, no background graphic. The illustration should feel light and not heavy or sad — the visual tone is "ready to be filled", not "nothing here".

| Property | Value |
|----------|-------|
| Illustration size | 120×120px |
| Illustration color | `neutral-400` (#CCCCCC) |
| Top margin from illustration | 64px from vertical center |
| Headline | `heading-2` (18px, Bold), `text-primary`, "Your wardrobe is empty" |
| Subtext | `body-regular` (14px), `text-secondary`, "Add your first item to get started", center-aligned, max-width 240px, centered |
| CTA | Primary CTA button, fixed 200px width, centered, "Add Item" |
| Spacing: illustration → headline | 24px |
| Spacing: headline → subtext | 8px |
| Spacing: subtext → CTA | 32px |

#### 8.9.5 Empty Discover State

Same pattern as Empty Wardrobe. Illustration: a simple line-art outline of a hanger with a single spark/star icon to its right — suggesting "outfits waiting to be discovered". Same spacing rules. Headline: "Nothing here yet". Subtext: "Browse outfits or get AI suggestions to start." CTA: "Explore Outfits" (links to scroll-to-top behavior or triggers onboarding).

---

### 8.10 Outfit Slot Tile (Playground)

**Grid:** 2 columns × 3 rows. 6 slots total.
- Required slots: Top, Bottom, Shoes
- Optional slots: Accessory, Outerwear, Bag

**Grid layout:**
- Grid width: 358px
- Column gap: 8px
- Row gap: 8px
- Individual tile width: (358 − 8) ÷ 2 = 175px
- Tile aspect ratio: 6:7 → height = 175 × (7/6) = 204px

#### 8.10.1 Empty Slot Tile

| Property | Value |
|----------|-------|
| Border | 1.5px dashed `neutral-300` (#E5E5E5) |
| Border radius | `radius-xl` (16px) |
| Background | `neutral-0` (#FFFFFF) |
| Category icon | 28px, `neutral-400` (#CCCCCC), vertically centered with label |
| Category label | `caption` (11px, Regular), `text-secondary` (#999999), 4px below icon |
| "Required" label (required slots only) | `overline` (10px, SemiBold), `warning` (#E65100), positioned 8px from bottom, centered |
| Layout | Icon + label centered in tile |

#### 8.10.2 Filled Slot Tile

| Property | Value |
|----------|-------|
| Border | None |
| Border radius | `radius-xl` (16px) |
| Image | Object-fit: contain (show full product on white bg), fills tile |
| Background | `neutral-100` (#F5F5F5) |
| Remove button | 24px circle, white bg (#FFFFFF), black × icon (16px), positioned 8px from top-right corner, Level 1 shadow |

---

### 8.11 AI Try-On Result View (Playground)

**Anatomy:** Generated image → Action row

| Property | Value |
|----------|-------|
| Image width | 358px (full content width) |
| Image height | 476px (3:4 aspect ratio — portrait, shows full body) |
| Border radius | `radius-2xl` (24px) |
| Background (loading) | `neutral-100` (#F5F5F5) skeleton with shimmer |
| Elevation | Level 1 shadow |

**Action row** (below image, 16px margin top):
- 4 actions: Save, Share, Regenerate, Edit
- Layout: 4 equal-width columns spanning 358px
- Each action: 24px icon centered, 4px gap, `caption` label below — this is the small action button from Section 8.1.5
- Gap between icon+label unit: auto-distributed across 4 columns

**Loading state (AI generation in progress):**
- Shimmer skeleton: 358×476px, `radius-2xl`
- Full-screen overlay: `overlay-white-soft` over the entire Playground screen (not just the image zone)
- Status text messages (cycling every 2.5s, fade transition):
  1. "Analyzing your outfit..."
  2. "Generating your look..."
  3. "Almost ready..."
  4. "Adding finishing touches..."

---

### 8.12 Snackbar / Toast

| Property | Value |
|----------|-------|
| Width | Screen width − 32px = 358px |
| Position | Horizontally centered, 16px above bottom navigation bar top edge |
| Border radius | `radius-md` (8px) |
| Background | `cta-bg` (#111111) |
| Text | `body-small` (13px, Regular), `text-inverse` (#FFFFFF) |
| Horizontal padding | 16px |
| Height | Auto (minimum 44px) |
| Elevation | Level 2 shadow |
| Auto-dismiss | 4 seconds |
| Entry animation | Slide up from bottom + fade in, 200ms ease-out |
| Dismiss animation | Fade out, 150ms ease-in |
| Error variant | Background `destructive` (#D32F2F), white text |
| Success variant | Background `success` (#2E7D32), white text |

---

## 9. Screen-by-Screen Layout Specs

### 9.1 Login & Signup Screens

**Navigation pattern:** Modal stack (no back navigation — user must complete auth or dismiss app)
**Background:** `neutral-0` (#FFFFFF), full-screen

**Layout (top to bottom, vertically centered block):**

| Element | Spec |
|---------|------|
| App wordmark | "Outfitter" in `display` style (32px, Bold), `text-primary`, centered, top margin 80px from safe area |
| Tagline | `body-regular` (14px), `text-secondary`, centered, 8px below wordmark |
| Form container | Top margin 48px from tagline |
| Email input | Standard input, full-width, label "Email" |
| Gap between inputs | 12px |
| Password input | Standard input, full-width, label "Password" |
| Forgot password | Ghost text button, right-aligned, `body-small`, 8px below password field |
| Primary CTA | "Sign In" or "Create Account", full-width, top margin 32px |
| Divider + "or" | Horizontal rule with "or" text centered, `caption`, `text-secondary`, 20px vertical margin |
| Apple button | Secondary CTA, full-width, leading Apple logo icon (20px) + "Continue with Apple" |
| Switch screen link | Centered `body-small` — "Don't have an account? Sign up" — `text-secondary` with link portion in `text-primary` underlined, bottom margin 32px from bottom safe area |

**Rules:** No background illustration. No hero photography. The screen is intentionally bare — it positions the product as confident enough not to need a sales pitch at login.

---

### 9.2 Discover Tab

**Navigation pattern:** Root tab, no back action
**Header:**
- Height: 52px (below status bar safe area)
- App wordmark "Outfitter" — `heading-1` style (24px, Bold), left-aligned at 16px
- Right side: notification bell icon (24px) + search icon (24px), 16px gap between, 16px from right edge
- Bottom border: 1px `neutral-200`

**Body (vertical scroll, lazy loading):**

| Section | Layout |
|---------|--------|
| Story circles row | Horizontal scroll row, 82px total height, 16px top margin from header, see Section 8.6 |
| "AI Stilist" section | Section header row + 2 editorial cards side-by-side. Card width: (358 − 8) ÷ 2 = 175px. Aspect ratio: 1:1.4 → height 245px. Cards have `radius-xl`. Overlay text + "Başla" pill button (Secondary CTA, fixed width, `radius-full`, small — 34px height) positioned bottom-left of each card with 12px inset. Image covers full card. |
| "Seasonal Edits" section | Section header + horizontal scroll of outfit cards. Card width: 160px, aspect 9:16 → height 284px. `radius-xl`. Horizontal gap: 12px. |
| "Occasion Collections" section | Same layout as Seasonal Edits. |
| "Recently Saved" section | Same layout as Seasonal Edits. Only shown if user has saved items. |

**Section header row spec:**
- `heading-2` (18px, Bold) left at 16px
- "See all" ghost button right at 16px, `body-small` (13px), `text-secondary`
- Row height: 32px
- Bottom gap to content: 12px

**Vertical gaps between sections:** 32px

---

### 9.3 Playground Tab

**Navigation pattern:** Root tab OR pushed screen from Discover card tap
**Header:**
- "Playground" centered in `heading-1` (24px, Bold)
- Left: back chevron (only shown if navigated from another screen, not when accessed via tab)
- Right: no actions

**Body layout (top to bottom):**

| Zone | Spec |
|------|------|
| Outfit canvas header | "Build your outfit" in `heading-2` left-aligned, 16px from top of content area, 16px from left |
| Slot grid | 2×3 grid, 16px horizontal padding, 8px gap, see Section 8.10 |
| AI Try-On result (post-generation) | Appears above the slot grid (scrollable — the page pushes content down). 16px margin from screen edges, see Section 8.11 |
| Generate button | Full-width Primary CTA, "Generate Try-On", 24px top margin below grid. Disabled state until Top + Bottom + Shoes are filled. |

**Slot Browser Bottom Sheet** (opens on tapping an empty slot):
- Title: slot category name (e.g., "Choose Top") in `heading-3`, centered
- Filter chip row below title: category sub-filters (e.g., T-Shirts, Blouses, Knitwear)
- 2-column product grid below filter row: wardrobe items + brand catalog items mixed, item cards see Section 8.2.3
- Grid padding: 16px horizontal
- Grid gap: 8px
- Bottom sheet height: 75% snap point default

---

### 9.4 Assistant Tab

**Navigation pattern:** Root tab. Two states: Parameter Screen (default) and Suggestion Screen (after submission).

#### Parameter Screen

**Header:** "Find Your Outfit" in `heading-1`, 16px from left, 24px below safe area top

**Body (scrollable):**

| Parameter Section | Layout |
|------------------|--------|
| Section title | `heading-2` (18px, Bold), 24px top margin |
| Chips | Wrap layout (NOT horizontal scroll) — chips wrap to next line. Row gap: 8px. Column gap: 8px. Max 4 chips per row on 358px canvas. |
| Occasion | 8 chips: Casual, Work, Date Night, Brunch, Party, Sport, Travel, Formal — multi-select allowed |
| Season | 4 chips: Spring, Summer, Fall, Winter — single select |
| Color Preference | 5 chips: Neutrals, Earthy, Bold, Pastel, Monochrome — multi-select allowed |
| Source | 3 chips: My Wardrobe, Shop, Mix — single select |

**Sticky CTA at bottom:**
- "Find Outfits" Primary CTA, full-width
- Sticky container: white background, 16px top padding, 16px horizontal, bottom safe area inset
- Container top border: 1px `neutral-200`
- Container is always visible (sticky, does not scroll with content)

#### Suggestion Carousel Screen

**Header:** Back chevron (left, returns to Parameter Screen) + "Suggestions" title centered + "Refresh" icon button right (24px, `text-secondary`)

**Body:**
- Outfit suggestion cards in a horizontal PageView (full-width swipe carousel)
- One card visible at a time, cards are 358px wide
- Dot indicator row below the card: dots are 6px circles, active dot is `text-primary` (#111111), inactive dots are `neutral-300` (#E5E5E5), gap 6px between dots
- Top margin from header to first card: 24px
- Dot indicator: 16px below card

---

### 9.5 Wardrobe Tab

**Navigation pattern:** Root tab
**Header:**
- "My Wardrobe" left-aligned, `heading-1`
- Right: sort/filter icon button (sliders icon, 24px, `text-secondary`)

**Sub-header (category tabs):**
- Filter chip horizontal scroll row, see Section 8.5
- Categories: All, Tops, Bottoms, Shoes, Outerwear, Accessories, Bags
- 12px top margin from main header, 8px bottom margin before grid

**Body:**
- 3-column grid of wardrobe item cards (Section 8.2.3)
- 16px horizontal padding
- 8px gap between cards
- Infinite scroll / lazy load: load 30 items, add 15 more on scroll bottom
- Empty state: Section 8.9.4

**Secondary FAB:**
- "+" icon, 52px diameter, black circle, white "+" (24px)
- Position: 16px from right screen edge, 16px above bottom navigation bar top edge
- Level 1 shadow
- This FAB is separate from the bottom navigation FAB — it is contextual to the Wardrobe tab and triggers the Add Item flow (Section 9.6)

**Item Detail Screen** (pushed full-screen, not a bottom sheet):
- Top half: full-width image (390px wide, 390px tall — square aspect)
- Bottom half (scrollable if needed):
  - Item name: `heading-2` (18px, Bold), 16px top margin
  - Brand name: `body-regular`, `text-secondary`, 4px below name
  - Tags section header: "Tags" `heading-3`, 16px top margin
  - Editable tag chips in wrap layout: see Section 8.8 Editable variant
  - Action row at bottom: two buttons — "Find Matching Outfits" (Secondary CTA) and "Delete" (Destructive, small fixed-width)

---

### 9.6 Add Item Flow

**Triggered by:** Bottom nav FAB or Wardrobe secondary FAB

**Step 1 — Source Picker (Bottom Sheet, 50% height):**

| Element | Spec |
|---------|------|
| Title | "Add Item", `heading-3`, centered in sheet header |
| 3 tiles | Horizontal row of 3 equal-width tiles, see Section 8.2.4 (Shortcut Tile). Tile labels: "Photo Library", "Camera", "Import URL" |
| Search bar | Below tiles, 16px top margin, full-width pill search bar (Section 8.7.2). Placeholder: "Search brand catalog..." |
| Separator | 1px `neutral-200` divider between tiles and search bar |

**Step 2 — Tag Confirmation Sheet (Bottom Sheet, 75% height):**
Opens after image is selected/captured.

| Element | Spec |
|---------|------|
| Item image | Square image preview at top: 120×120px, `radius-lg`, centered, 16px top margin below drag handle |
| Detected tags section | "Detected Tags" `heading-3`, 12px below image |
| Tag chips | Editable chips in wrap layout (Section 8.8 Editable variant). Chips show: category, color, pattern, fit/style. All pre-populated by AI. User can tap ✕ to remove any chip. |
| "Add tag" chip | An outlined dashed-border pill chip (same 28px height), "+ Add tag" label, `text-secondary`, tapping opens a tag selection or text input |
| Save CTA | "Save to Wardrobe" Primary CTA, full-width, sticky at bottom of sheet (same sticky container pattern as Section 9.4) |

---

## 10. Motion & Interaction Principles

### 10.1 Navigation Transitions

| Transition Type | Animation | Duration |
|----------------|-----------|----------|
| Push navigation (drill down) | Slide from right (new screen enters from right, current slides to left) | 300ms ease-in-out |
| Pop navigation (back) | Slide to right (current screen exits right, previous slides in from left) | 250ms ease-in-out |
| Modal/bottom sheet appear | Slide up from bottom + scrim fades in | 350ms spring (damping 0.85) |
| Modal/bottom sheet dismiss | Slide down, scrim fades out | 280ms ease-in |
| Tab switch | Cross-fade (no slide) | 200ms ease |

### 10.2 Content Transitions

| Transition | Animation | Duration |
|------------|-----------|----------|
| Skeleton → loaded content | Cross-fade | 300ms ease-in |
| Loading overlay appear | Fade in | 200ms ease |
| Loading overlay disappear | Fade out | 200ms ease |
| Snackbar enter | Slide up + fade in | 200ms ease-out |
| Snackbar exit | Fade out | 150ms ease-in |
| AI status text message change | Fade out old → fade in new | 200ms fade each direction |
| AI status text cycle interval | Every 2.5 seconds | — |

### 10.3 Interactive Micro-interactions

| Component | Interaction | Animation |
|-----------|-------------|-----------|
| Button press | Scale down | Scale 0.97, 100ms ease |
| Button release | Scale restore | Scale 1.0, 100ms ease |
| Card press | Scale + shadow reduce | Scale 0.97, shadow reduces to Level 0, 100ms |
| Filter chip select | Color fill | Instant (no animation needed, feel snappy) |
| Slot tile tap | Brief scale | Scale 0.95 and restore, 120ms |
| FAB tap | Scale pulse | Scale 1.1 then 1.0, 200ms spring |
| Tag chip remove | Fade + collapse width | Fade out 150ms + width animates to 0px 150ms |

### 10.4 Gesture-Based Interactions

| Gesture | Context | Behavior |
|---------|---------|----------|
| Swipe right | Assistant suggestion card | "Saved" — green overlay label fades in, card slides off-screen right, next card enters from left |
| Swipe left | Assistant suggestion card | "Skip" — gray overlay label fades in, card slides off-screen left, next card enters from right |
| Swipe down | Bottom sheet | Drag handle + sheet follows finger; if released below 40% height threshold, sheet dismisses; otherwise snaps back |
| Long press | Wardrobe item card | Enters multi-select mode — card shows checkmark overlay, other cards show empty checkboxes |
| Pull to refresh | Discover tab scroll | Standard iOS pull-to-refresh, spinner in `text-primary` color |

### 10.5 Accessibility Motion

All animations must be disabled or reduced when the user has enabled "Reduce Motion" in iOS accessibility settings. Replacements:

- Slide transitions → instant or cross-fade
- Spring animations → ease-in-out at 200ms
- Shimmer shimmer animation → static color (no moving highlight)
- Card scale press → instant opacity change (0.7) instead of scale

---

## 11. Accessibility Notes

### 11.1 Color & Contrast

| Pairing | Contrast Ratio | Status |
|---------|---------------|--------|
| `text-primary` (#111111) on `neutral-0` (#FFFFFF) | 19.5:1 | WCAG AAA |
| `text-secondary` (#999999) on `neutral-0` (#FFFFFF) | 3.1:1 | Meets WCAG AA Large text only |
| `text-inverse` (#FFFFFF) on `cta-bg` (#111111) | 19.5:1 | WCAG AAA |
| `text-primary` (#111111) on `neutral-100` (#F5F5F5) | 16.1:1 | WCAG AAA |
| `destructive` (#D32F2F) on `neutral-0` (#FFFFFF) | 5.9:1 | WCAG AA |
| `success` (#2E7D32) on `neutral-0` (#FFFFFF) | 6.7:1 | WCAG AA |

**Note:** `text-secondary` (#999999) on white fails WCAG AA for normal-size body text (3.1:1 < 4.5:1 required). It is acceptable only for text at or above `heading-2` size (18px bold = large text, 3:1 threshold). For small secondary labels at 11–13px, use `neutral-700` (#555555) which achieves 7.4:1.

**Revised rule:** Use `neutral-700` (#555555) for all secondary labels at 13px and below. Use `neutral-500` (#999999) only for secondary labels at 16px or above, or for placeholder text in inputs (placeholder text has a separate accessibility treatment).

### 11.2 Touch Targets

- Minimum touch target for any interactive element: **44×44px**
- Tab bar items, filter chips, and small icons must have invisible tap area extensions if the visible element is smaller than 44×44px
- The 28px wardrobe item tag chip (editable mode) must have a 44px minimum tap target centered on the chip

### 11.3 Screen Reader Support

- All images must have descriptive content descriptions (provided by engineering from AI-generated tags)
- All icon-only buttons must have accessible labels (e.g., "Remove item", "Save outfit")
- Bottom sheet must announce its state to screen reader when it appears and dismisses
- Swipeable suggestion cards must have alternative interaction (tap for save, double-tap for dismiss or equivalent)
- Tab bar must announce tab name and selected state

### 11.4 Color Independence

Color must never be the only differentiator for state:

- Selected vs. unselected filter chip: color change (black fill) + ALSO label weight change (already SemiBold in both states — consider adding a checkmark icon to selected chip as additional indicator)
- Error state on input: red border + ALSO error message text below field
- Viewed vs. unviewed story circle: gradient ring vs. gray ring + ALSO add a subtle visual indicator (such as a dot below the circle) for users with color vision deficiency
- Success/error snackbar: background color change + ALSO icon prefix (checkmark or warning icon, 20px)

### 11.5 Text in Images

Never embed text in images. All text must be live text rendered by the UI layer, not baked into photography or generated images.

---

## 12. Design Dos and Don'ts

### DO

- **Let product imagery dominate.** When a product photo is on screen, maximize the image area. Crop, aspect-ratio, and scale decisions should always favor the image.
- **Use white space generously.** Breathing room between sections (32px), within cards (12px internal padding), and around typography is not wasted space — it is the negative space that makes the clothes read.
- **Use black/dark CTAs throughout.** The `cta-bg` (#111111) button color signals premium quality and is decisive. Resist any temptation to use a brand color or gradient on primary CTAs.
- **Maintain typographic restraint.** If two weights can communicate the hierarchy, do not reach for a third.
- **Keep backgrounds white or near-white.** The `neutral-0` and `neutral-100` surfaces are the only acceptable card and screen backgrounds. Light gray for elevated surfaces only.
- **Align to the 4px grid obsessively.** Every measurement must be divisible by 4. If a component doesn't fit, fix the component.
- **Make every touch target at least 44×44px.** If a visual element is smaller, extend the touch target invisibly.
- **Test every screen with product images removed.** The layout must still communicate hierarchy and content structure without relying on image content.

### DO NOT

- **Do not use more than 2 typeface weights per screen.** Bold + Regular, or SemiBold + Regular. Not all three simultaneously.
- **Do not use decorative gradients except for the accent.** The `accent-gradient` (#9B5DE5 → #F15BB5) is reserved exclusively for story circles and AI feature indicators. Do not use gradients on backgrounds, buttons, headers, or any other element.
- **Do not use drop shadows above Level 1 on cards.** Cards must use either a subtle `neutral-300` border OR a Level 1 shadow (not both, and nothing heavier).
- **Do not use colorful backgrounds.** No tinted background surfaces, no brand-color washes, no tinted sections. Every background surface must be white or a shade within the neutral palette.
- **Do not crowd the bottom navigation area.** The bottom nav bar and its home indicator zone are sacred. No floating content, no persistent labels, no overlapping elements intrude into the 83px bottom nav zone (except the secondary FAB in Wardrobe, which is positioned 16px above the bar).
- **Do not embed text in images.** Every text element must be live text.
- **Do not use all-caps on body text.** The `overline` style is the only uppercase style, and only for short category labels.
- **Do not introduce new colors or gradients.** Every color used in the design must be from the defined palette in Section 2. If a situation feels like it needs a new color, solve it with the existing palette first.
- **Do not use decorative illustration on non-empty states.** Rich illustration and decoration are reserved for empty state guidance. Every other screen is product-forward.
- **Do not use the accent gradient on icons or text.** It is a border/ring decoration only.

---

*End of Outfitter UI Design Guide v1.0*
*Prepared for external Figma designer handoff — March 2026*
