"""Single source of truth for catalog taxonomy maps and rules.

Used by:
- ``backfill_catalog_taxonomy.py``     — runs Phase 2 of the refactor
- ``import_mango_catalog.py``           — replaces ``derive_subtype()`` once
                                          Phase 3 lands (call ``resolve_category``)
- ``import_bershka_catalog.py``         — same
- ``app/schemas/catalog.py``            — Phase 3 imports the controlled
                                          vocabularies as the canonical Literal
                                          source

Anything that classifies a catalog or wardrobe item against the new
vocabulary should import from here. Updating these constants in one place
keeps the API schema, the importers, the backfill, and downstream
analytics in lockstep.
"""

from __future__ import annotations

from typing import Callable

# ---------------------------------------------------------------------------
# Controlled vocabularies
#
# These are the canonical lists. Mirrored in ``app/schemas/catalog.py`` as
# Pydantic Literals after Phase 3, and as CHECK constraint allowlists in the
# 0014 finalize migration. Adding a value here is the start of a vocab change
# — propagate to schemas, migration, mobile/admin filter dropdowns.
# ---------------------------------------------------------------------------

SLOTS: frozenset[str] = frozenset({
    "top", "bottom", "dress", "outerwear", "footwear",
    "accessory", "bag", "underwear", "swimwear", "activewear",
})

CATEGORIES: frozenset[str] = frozenset({
    # tops (slot=top)
    "t-shirt", "polo", "shirt", "blouse", "sweater", "cardigan",
    "sweatshirt", "hoodie", "tank-top",
    # bottoms (slot=bottom)
    "jeans", "trousers", "shorts", "skirt", "joggers",
    # one-piece (slot=dress)
    "dress", "jumpsuit", "bodysuit",
    # outerwear (slot=outerwear)
    "blazer", "jacket", "coat", "trench-coat", "vest",
    # footwear (slot=footwear)
    "sneakers", "boots", "heels", "sandals",
    # accessories (slot=accessory or bag)
    "belt", "cap", "bag", "scarf", "sunglasses",
})
assert len(CATEGORIES) == 31, f"CATEGORIES drifted to {len(CATEGORIES)} entries; expected 31"

PATTERNS: frozenset[str] = frozenset({
    "plain", "striped", "checkered", "plaid", "floral", "paisley",
    "polka-dot", "geometric", "animal-print", "abstract", "tie-dye",
    "color-blocked", "embroidered", "sequined", "graphic", "logo",
    "camouflage", "gradient",
})
assert len(PATTERNS) == 18

FITS: frozenset[str] = frozenset({
    "regular", "slim", "skinny", "relaxed", "oversized", "loose",
    "straight", "mom", "wide-leg", "flare", "bootcut", "balloon",
    "baggy", "bodycon", "a-line", "shift", "fit-and-flare",
    "cropped", "tapered",
})
assert len(FITS) == 19

STYLE_TAGS: frozenset[str] = frozenset({
    "minimal", "classic", "old-money", "clean-girl", "preppy",
    "streetwear", "bohemian", "romantic", "edgy", "grunge", "vintage",
    "y2k", "sporty", "athleisure", "utility", "glam", "parisian",
})
assert len(STYLE_TAGS) == 17

OCCASION_TAGS: frozenset[str] = frozenset({
    "office", "interview", "formal", "wedding-guest", "smart-casual",
    "casual", "date-night", "party", "festival", "travel", "beach",
    "athletic", "loungewear",
})
assert len(OCCASION_TAGS) == 13


# ---------------------------------------------------------------------------
# Slug -> category map for Mango + Bershka source JSON
#
# Built from ``output/category-map.json`` and verified against
# ``output/{mango,bershka}_products.json``. See
# ``docs/plans/2026-05-01-catalog-taxonomy-refactor.md`` Appendix A for the
# full provenance and confidence grading.
#
# Slugs that map to None are out-of-vocab; the backfill script leaves
# ``category`` NULL for those items (per Q3 — manual cleanup).
# Slugs in ``AMBIGUOUS_SLUG_RULES`` are NOT in this map; they are resolved
# via ``resolve_category()`` which dispatches to a per-slug rule function.
# ---------------------------------------------------------------------------

SLUG_TO_CATEGORY: dict[str, str | None] = {
    # ---- HIGH confidence (1:1) ----------------------------------------
    "t-shirts":            "t-shirt",
    "jeans":               "jeans",
    "trousers":            "trousers",
    "pants":               "trousers",        # Mango uses "pants" for trousers
    "shorts":              "shorts",
    "skirts":              "skirt",
    "blazers":             "blazer",
    "coats":               "coat",
    "jackets":             "jacket",
    "polos":               "polo",
    "shirts":              "shirt",
    "sweaters":            "sweater",
    "sweatshirts":         "sweatshirt",
    "dresses":             "dress",
    "bags":                "bag",
    "vests":               "vest",
    "cardigans":           "cardigan",
    "bodysuits":           "bodysuit",

    # ---- MEDIUM confidence (heuristic) --------------------------------
    "sweaters-and-cardigans":     "sweater",   # default; cardigans rare in this slug
    "jackets-and-coats":          "jacket",    # default; coat refinement optional
    "sweatshirts-and-hoodies":    "hoodie",    # hoodie is the more specific subset
    "overshirts":                 "shirt",     # subtype of shirt
    "tops":                       "t-shirt",   # generic "top" container
    "tops-and-bodies":            "t-shirt",   # default; bodysuits a small subset
    "shoes":                      "sneakers",  # broad — refine via name keywords if needed
    "gilets":                     "vest",      # sleeveless outerwear
    "trench-coats":               "trench-coat",
    "trench-coats-and-parkas":    "trench-coat",
    "baggy-trousers":             "trousers",  # subset of trousers

    # ---- SKIP (out-of-vocab — leaves category NULL) -------------------
    "accessories":                None,
    "leather":                    None,        # material, not category
    "linen":                      None,        # material, not category
    "swimwear":                   None,
    "bikinis-and-swimsuits":      None,
    "pajamas":                    None,
    "underwear":                  None,
    "tracksuit":                  None,
}


# ---------------------------------------------------------------------------
# Ambiguous slug rules
#
# These slugs cannot be resolved by lookup alone — they need extra context
# (gender, product name keywords). Each rule is a callable taking
# (gender, name) and returning the resolved category or None.
# ---------------------------------------------------------------------------

def _rule_shirts_or_blouses(gender: str | None, name: str) -> str:
    """Q2=a — gender-keyed: women → blouse, men → shirt."""
    return "blouse" if gender == "women" else "shirt"


def _rule_dresses_or_jumpsuits(gender: str | None, name: str) -> str:
    """Q3=b — name-keyword pass; default to dress (majority of Mango W slug)."""
    return "jumpsuit" if "jumpsuit" in name.lower() else "dress"


def _rule_skirts_or_shorts(gender: str | None, name: str) -> str:
    """Q3=b — name-keyword pass; default to shorts (the slug puts shorts last)."""
    return "skirt" if "skirt" in name.lower() else "shorts"


AMBIGUOUS_SLUG_RULES: dict[str, Callable[[str | None, str], str]] = {
    "shirts---blouses":      _rule_shirts_or_blouses,   # Mango W
    "shirts-and-blouses":    _rule_shirts_or_blouses,   # Bershka W
    "dresses-and-jumpsuits": _rule_dresses_or_jumpsuits,
    "skirts-and-shorts":     _rule_skirts_or_shorts,
}


def resolve_category(*, slug: str, gender: str | None, name: str) -> str | None:
    """Resolve a (slug, gender, name) tuple to a category from the controlled vocab.

    Returns ``None`` for out-of-vocab slugs (manual cleanup later).
    The returned value is guaranteed to be in ``CATEGORIES`` or None.
    """
    rule = AMBIGUOUS_SLUG_RULES.get(slug)
    if rule is not None:
        result = rule(gender, name or "")
    else:
        result = SLUG_TO_CATEGORY.get(slug)
    if result is not None and result not in CATEGORIES:
        # Belt-and-braces: surface map drift loudly during dev rather than
        # quietly inserting unknown categories.
        raise ValueError(
            f"taxonomy_maps: slug {slug!r} resolved to {result!r}, "
            f"which is not in CATEGORIES — fix the map."
        )
    return result


# ---------------------------------------------------------------------------
# Stradivarius name-keyword rules
#
# Stradivarius source data is a flat list with no embedded category. We infer
# from the product ``name``. Order matters — most-specific prefixes first so
# "polo shirt" wins over plain "shirt", "t-shirt" wins over "shirt", etc.
#
# Substring matches are case-insensitive. The first matching rule wins.
# A target of None means "skip" (set category NULL).
# ---------------------------------------------------------------------------

STRADIVARIUS_KEYWORD_RULES: list[tuple[str, str | None]] = [
    # Most specific multi-word phrases first.
    ("polo shirt",   "polo"),
    ("tank top",     "tank-top"),
    ("tank-top",     "tank-top"),
    ("boat neck",    "t-shirt"),
    ("turtleneck",   "t-shirt"),
    ("bodysuit",     "bodysuit"),
    ("bandeau",      "tank-top"),
    ("camisole",     "tank-top"),
    ("balaclava",    None),
    ("sweatshirt",   "sweatshirt"),
    ("hoodie",       "hoodie"),
    ("jumper",       "sweater"),
    ("cardigan",     "cardigan"),
    ("sweater",      "sweater"),
    # Watch out: substring "blouse" precedes "shirt" so blouses get caught
    # before falling through to the "shirt" suffix on "shirts and blouses".
    ("blouse",       "blouse"),
    # Specific shirt variants
    ("oversize long sleeve striped t-shirt", "t-shirt"),
    ("t-shirt",      "t-shirt"),
    ("tshirt",       "t-shirt"),
    ("shirt",        "shirt"),
    # Bottoms
    ("jeans",        "jeans"),
    ("denim",        "jeans"),
    ("trousers",     "trousers"),
    ("shorts",       "shorts"),
    ("skirt",        "skirt"),
    # One-pieces
    ("jumpsuit",     "jumpsuit"),
    ("dress",        "dress"),
    # Outerwear
    ("trench coat",  "trench-coat"),
    ("trench-coat",  "trench-coat"),
    ("blazer",       "blazer"),
    ("jacket",       "jacket"),
    ("coat",         "coat"),
    ("parka",        "coat"),
    ("vest",         "vest"),
    ("gilet",        "vest"),
    # Footwear
    ("trainers",     "sneakers"),
    ("sneakers",     "sneakers"),
    ("heels",        "heels"),
    ("sandals",      "sandals"),
    # "boots" must precede the "shoes" fallback, "boot" handles singular forms
    ("boots",        "boots"),
    ("boot",         "boots"),
    ("shoes",        "sneakers"),  # broad fallback for footwear
    # Accessories
    ("sunglasses",   "sunglasses"),
    ("glasses",      "sunglasses"),  # rare; sub of sunglasses for now
    ("belt",         "belt"),
    ("cap",          "cap"),
    ("hat",          "cap"),         # caps and hats lumped together
    ("scarf",        "scarf"),
    ("bag",          "bag"),
    # Last-resort fallback for generic "top"
    ("top",          "t-shirt"),
]


def stradivarius_category_from_name(name: str) -> str | None:
    """Apply STRADIVARIUS_KEYWORD_RULES (most-specific first) to a product name."""
    if not name:
        return None
    needle = name.lower()
    for substr, target in STRADIVARIUS_KEYWORD_RULES:
        if substr in needle:
            return target
    return None


# ---------------------------------------------------------------------------
# Subtype cleanup remap
#
# The OLD ``subtype`` column (now renamed to ``subcategory`` in 0013) is a
# free-text soup containing, mixed together: real subcategory values
# (oxford, henley, midi), fits (slim, mom, wide-leg), patterns (striped,
# floral, embroidered), and noise (sleeve descriptors, brand-promo strings).
#
# Phase 2's cleanup pass uses ``classify_subtype`` to route each value to
# the correct destination column.
# ---------------------------------------------------------------------------

# Real garment-subtype values that should remain in `subcategory`.
# Curated — extend as catalog grows. These are values that are MORE specific
# than `category` but not captured by `fit` or `pattern`.
KEEP_AS_SUBCATEGORY: frozenset[str] = frozenset({
    # Shirt sub-cuts
    "oxford", "henley", "button-down", "button down", "flannel",
    # Dress lengths
    "mini", "midi", "maxi",
    # Sweater necklines
    "crew-neck", "crew neck", "v-neck", "turtleneck", "mock-neck",
    # Jacket sub-cuts
    "bomber", "denim-jacket", "biker", "puffer", "varsity", "letterman",
    # Trouser sub-cuts (NB: "wide-leg" is fit, not subcategory)
    "chinos", "cargo", "cargos", "jogger",
    # Skirt sub-cuts
    "pleated", "pencil",
    # Sneaker styles
    "running", "skate", "high-top", "low-top",
})


def _normalize(value: str | None) -> str:
    """Lowercase, strip, and dedupe whitespace for vocabulary matching."""
    if not value:
        return ""
    return " ".join(value.lower().strip().split())


def _strip_fit_suffix(value: str) -> str:
    """Strip a trailing " fit" so e.g. "slim fit" -> "slim", "regular fit" -> "regular"."""
    if value.endswith(" fit"):
        return value[: -len(" fit")]
    return value


def _normalize_for_fit(value: str) -> str:
    """Map common fit phrasings to the canonical FIT vocabulary."""
    n = _strip_fit_suffix(_normalize(value))
    # canonical hyphen forms — accept "wide leg" or "wide-leg"
    if n in ("wide leg", "wide-leg"):
        return "wide-leg"
    if n in ("a line", "a-line"):
        return "a-line"
    if n in ("fit and flare", "fit-and-flare"):
        return "fit-and-flare"
    if n == "flared":
        return "flare"
    if n in ("relaxed", "relaxed fit"):
        return "relaxed"
    return n


# Sleeve / length / construction descriptors that are real but don't belong
# in any of {category, subcategory, fit, pattern}. They get DROPPED on cleanup.
DROP_SUBCATEGORY_TOKENS: frozenset[str] = frozenset({
    "short sleeve", "short sleeved", "long sleeve", "long sleeved",
    "sleeveless", "short-sleeve", "long-sleeve",
    "tops and bodies", "shirts blouses", "shirts and blouses",
    "shirts---blouses",
    "regular",  # too generic to be a subcategory; if also a fit, fit captures it
    "knitwear", "casual", "basics", "plus sizes",
})


def classify_subtype(value: str | None) -> tuple[str, str | None]:
    """Route a polluted ``subtype`` value to its proper destination.

    Returns ``(target_column, target_value)``. ``target_column`` is one of:
    - ``"subcategory"`` — keep (already a useful subcategory term)
    - ``"fit"``         — move to the ``fit`` column
    - ``"pattern"``     — append to the ``pattern_array`` column
    - ``"category"``    — promote to the new ``category`` column
    - ``"drop"``        — discard (set ``subcategory`` to NULL)

    ``target_value`` is the normalized value to write, or None for "drop".
    """
    n = _normalize(value)
    if not n:
        return ("drop", None)

    # 1. Exact-match against pattern vocab
    if n in PATTERNS:
        return ("pattern", n)

    # 2. Try fit vocab after normalization (strip "fit" suffix, dehyphen variants)
    fit_candidate = _normalize_for_fit(n)
    if fit_candidate in FITS:
        return ("fit", fit_candidate)

    # 3. Try category vocab — sometimes the subtype is actually a garment type
    if n in CATEGORIES:
        return ("category", n)

    # 4. Curated subcategory list
    if n in KEEP_AS_SUBCATEGORY:
        # Normalize to hyphenated canonical form for the few that have spaces
        if n == "crew neck":
            return ("subcategory", "crew-neck")
        if n == "button down":
            return ("subcategory", "button-down")
        return ("subcategory", n)

    # 5. Explicit drop list
    if n in DROP_SUBCATEGORY_TOKENS:
        return ("drop", None)

    # 6. Default: drop. The map is conservative on purpose — an unknown
    #    polluted value is more likely to be noise than meaningful data.
    return ("drop", None)
