"""Playground tables and seed data

Revision ID: 0008
Revises: 0007
Create Date: 2026-04-30

Adds four tables for the persisted playground feature:
- system_prompts: singleton-shaped library of global system prompts (one row active)
- user_prompt_templates: library of user-prompt templates with {{MODEL}} placeholder
- model_personas: library of model personas (gendered) slotted into templates
- playground_runs: persisted generation history with full prompt snapshots

Seeds 1 system prompt + 3 templates + 8 personas. UUIDs are generated in Python
to avoid a pgcrypto dependency.
"""
import uuid
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0008"
down_revision: Union[str, None] = "0007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# ---------------------------------------------------------------------------
# Seed content
# ---------------------------------------------------------------------------

GLOBAL_SYSTEM_PROMPT_CONTENT = """Generate a single photographic fashion image for an apparel commerce platform.

The clothing reference images attached to this request are the wardrobe ground truth. Recreate every garment exactly as shown in the attached references. Do not infer additional garments. Do not assume a garment exists if it is not in a reference image.

Priority order (resolve any conflict in this order):
1. Clothing fidelity — exact recreation of every garment in the references
2. Garment visibility — every garment must be clearly visible in the final frame
3. Pose suitability — the pose must match the outfit's vibe and reveal the garments
4. Anatomical and photographic correctness
5. Overall image quality and mood

Clothing fidelity rules (non-negotiable):
For every garment in the attached references, preserve exactly:
- garment type, color, silhouette, cut, fit, proportions
- fabric, material appearance, texture, weight, drape behavior
- logos, graphics, prints, patterns
- stitching, trims, hardware, closures, straps
- decorative details, embellishments, asymmetry, layering
Fit each garment naturally onto the model's body with realistic drape, folds, tension, and fabric weight. Reproduce the same color, weave, and finish as the reference. Never invent, simplify, restyle, recolor, or remove garment details. Never add garments or accessories that are not present in the references.

Composition rules:
- Full-body composition: head fully in frame, feet fully visible at the bottom of the frame
- Comfortable margin around the subject; never crop the outfit
- One model only, unless the user prompt specifies otherwise
- Never let pose, framing, or arm position hide important garment details

Pose selection — driven by the outfit vibe stated in the user prompt:
- Elegant / evening / formal / luxurious → poised graceful stance, subtle hip shift, clean arm placement
- Tailored / structured / power-dressing → upright confident stance, squared shoulders, commanding presence
- Relaxed / oversized / streetwear / casual → effortless stance, hands in pockets, relaxed shoulders, slight lean
- Romantic / soft / feminine → softer body lines, gentle arm placement, graceful angles
- Edgy / bold / fashion-forward → assertive editorial pose, stronger angles, attitude
- Playful / youthful → light energetic pose, subtle movement that keeps the outfit visible
If the user prompt does not state a vibe, infer it from the garments themselves.

Garment-aware pose adjustments:
- Jacket with pockets and a styling that supports it → hands may rest naturally in the pockets
- Dramatic dress, skirt, or coat → pose must reveal drape, hemline, slit, or volume
- Wide-leg pants → stance must clearly show the leg shape and fabric flow
- Statement shoes or boots → feet placement must keep them clearly visible
- Asymmetrical cuts, slits, sharp tailoring, layered structure → choose angles that reveal those features
- Never let arms, hands, or body position obscure key garment details

Photographic constraints:
- Photographic image only — never cartoon, illustration, painting, anime, CGI, 3D render, or stylized non-photographic look
- Anatomically correct — five fingers per hand, no duplicate or merged limbs, natural proportions, no facial distortion
- Sharp clothing detail with realistic fabric texture rendering
- Skin rendering follows the user prompt's specified style; default to realistic with subtle editorial retouching

Universal exclusions:
- No text, captions, watermarks, or invented brand marks
- No accessories (bags, jewelry, hats, sunglasses, scarves, belts, etc.) unless visible in the reference images
- No background props, furniture, signage, additional people, or animals
- No cropped feet, no missing or hidden shoes
- No changes to garment color, design, or proportion from the references

Conflict resolution:
If any styling, lighting, environment, or pose instruction in the user prompt conflicts with clothing fidelity or garment visibility, always prioritize clothing fidelity and garment visibility. Re-pose, re-light, or re-compose as needed to keep every garment clearly recognizable and faithful to the reference.

The user prompt below specifies the model, outfit vibe, environment, lighting, camera, and any per-image variations for this generation."""


TEMPLATES_SEED = [
    {
        "slug": "evening_editorial",
        "label": "Evening Editorial",
        "description": "Polished evening look in a refined indoor setting",
        "body": (
            "Render {{MODEL}} in an elegant outfit vibe.\n"
            "Environment: a quiet hotel suite with cream walls, soft drapery, and a faint reflection on a polished marble floor.\n"
            "Lighting: warm key from a window at frame-left, gentle fill from a paper lantern, low contrast, no harsh shadows.\n"
            "Camera: full-body, 50mm equivalent, eye-level, slight three-quarter angle, f/4.\n"
            "Skin: realistic editorial retouching with visible pores, faint specular highlights, no plastic smoothing."
        ),
    },
    {
        "slug": "streetwear_urban",
        "label": "Streetwear Urban",
        "description": "Relaxed streetwear look in a daylit city scene",
        "body": (
            "Render {{MODEL}} in a relaxed outfit vibe.\n"
            "Environment: a clean concrete sidewalk against a graffiti-free brick wall, late-morning city light, no signage or text in frame.\n"
            "Lighting: overcast daylight, soft and even, with a subtle rim from the sky.\n"
            "Camera: full-body, 35mm equivalent, eye-level, straight-on, f/2.8 with the wall slightly out of focus.\n"
            "Skin: realistic with neutral grading, fine texture, no makeup glow."
        ),
    },
    {
        "slug": "lookbook_neutral",
        "label": "Lookbook Neutral",
        "description": "Tailored lookbook composition on a neutral seamless",
        "body": (
            "Render {{MODEL}} in a tailored outfit vibe.\n"
            "Environment: seamless paper backdrop in a neutral warm-grey, no props, no shadow on the floor join.\n"
            "Lighting: large softbox key from frame-left at 45 degrees, white bounce from frame-right, mild background separation light.\n"
            "Camera: full-body, 85mm equivalent, eye-level, dead-centre, f/5.6 for crisp garment detail.\n"
            "Skin: realistic with subtle editorial retouching, even tone, no heavy contouring."
        ),
    },
]


PERSONAS_SEED = [
    # Female ----------------------------------------------------------------
    {
        "slug": "f_tan_brunette_updo",
        "label": "Tan brunette, soft updo",
        "gender": "female",
        "description": (
            "- Mid-20s\n"
            "- Tan skin with warm undertones\n"
            "- Slim athletic build, average height\n"
            "- Dark brunette hair in a soft low updo, a few loose face-framing strands\n"
            "- Subtle bronzed makeup, glossy nude lip\n"
            "- Calm composed expression\n"
            "- Direct confident gaze toward camera"
        ),
    },
    {
        "slug": "f_fair_blonde_waves",
        "label": "Fair blonde, loose waves",
        "gender": "female",
        "description": (
            "- Mid-20s\n"
            "- Fair skin with cool undertones\n"
            "- Slim build, average-tall height\n"
            "- Honey-blonde hair in loose shoulder-length waves with a centre part\n"
            "- Soft natural makeup, dewy skin, neutral lip\n"
            "- Relaxed half-smile\n"
            "- Soft gaze just past the camera"
        ),
    },
    {
        "slug": "f_deep_coily",
        "label": "Deep skin, natural coily hair",
        "gender": "female",
        "description": (
            "- Mid-20s\n"
            "- Deep skin with rich warm undertones\n"
            "- Slim athletic build, average height\n"
            "- Natural 4A/4B coily hair in a defined shoulder-length silhouette\n"
            "- Minimal makeup, glowing skin, glossy lip\n"
            "- Poised neutral expression\n"
            "- Steady direct gaze toward camera"
        ),
    },
    {
        "slug": "f_olive_dark_bob",
        "label": "Olive complexion, sleek dark bob",
        "gender": "female",
        "description": (
            "- Mid-20s\n"
            "- Olive skin with neutral undertones\n"
            "- Slim straight-line build, average height\n"
            "- Sleek jet-black chin-length bob with a clean centre part\n"
            "- Sharp brow, matte skin, defined matte lip\n"
            "- Cool composed expression\n"
            "- Strong direct gaze toward camera"
        ),
    },
    # Male ------------------------------------------------------------------
    {
        "slug": "m_tan_brunette_tousled",
        "label": "Tan brunette, short tousled hair",
        "gender": "male",
        "description": (
            "- Mid-20s\n"
            "- Tan skin with warm undertones\n"
            "- Lean athletic build, average-tall height\n"
            "- Dark brunette hair, short and lightly tousled on top\n"
            "- Light stubble, neat brows, no visible product\n"
            "- Calm focused expression\n"
            "- Steady direct gaze toward camera"
        ),
    },
    {
        "slug": "m_fair_blonde_sidepart",
        "label": "Fair blonde, side-part",
        "gender": "male",
        "description": (
            "- Mid-20s\n"
            "- Fair skin with cool undertones\n"
            "- Lean build, average-tall height\n"
            "- Sandy-blonde hair, neat side-parted style with a soft natural finish\n"
            "- Clean-shaven, brushed brows\n"
            "- Relaxed neutral expression\n"
            "- Soft gaze just past the camera"
        ),
    },
    {
        "slug": "m_deep_lowfade",
        "label": "Deep skin, low-fade cropped hair",
        "gender": "male",
        "description": (
            "- Mid-20s\n"
            "- Deep skin with warm undertones\n"
            "- Athletic muscular build, average-tall height\n"
            "- Black low-fade haircut, sharp lineup, short crop on top\n"
            "- Trimmed neat beard, well-defined brows\n"
            "- Confident neutral expression\n"
            "- Direct steady gaze toward camera"
        ),
    },
    {
        "slug": "m_olive_modern_fade",
        "label": "Olive complexion, modern fade",
        "gender": "male",
        "description": (
            "- Mid-20s\n"
            "- Olive skin with neutral undertones\n"
            "- Lean straight-line build, average-tall height\n"
            "- Dark-brown modern mid-fade with longer textured top\n"
            "- Clean-shaven, sharp brows\n"
            "- Cool composed expression\n"
            "- Strong direct gaze toward camera"
        ),
    },
]


# ---------------------------------------------------------------------------
# Migration ops
# ---------------------------------------------------------------------------

def upgrade() -> None:
    op.create_table(
        "system_prompts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("slug", sa.String(64), nullable=False),
        sa.Column("label", sa.String(128), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint("slug", name="uq_system_prompts_slug"),
    )
    op.create_index(
        "ix_system_prompts_slug", "system_prompts", ["slug"], unique=False
    )

    op.create_table(
        "user_prompt_templates",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("slug", sa.String(64), nullable=False),
        sa.Column("label", sa.String(128), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint("slug", name="uq_user_prompt_templates_slug"),
    )
    op.create_index(
        "ix_user_prompt_templates_slug",
        "user_prompt_templates",
        ["slug"],
        unique=False,
    )

    op.create_table(
        "model_personas",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("slug", sa.String(64), nullable=False),
        sa.Column("label", sa.String(128), nullable=False),
        sa.Column("gender", sa.String(16), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "gender IN ('female','male')", name="ck_model_personas_gender"
        ),
        sa.UniqueConstraint("slug", name="uq_model_personas_slug"),
    )
    op.create_index("ix_model_personas_slug", "model_personas", ["slug"], unique=False)
    op.create_index("ix_model_personas_gender", "model_personas", ["gender"], unique=False)

    op.create_table(
        "playground_runs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "catalog_item_ids",
            postgresql.ARRAY(postgresql.UUID(as_uuid=True)),
            nullable=False,
        ),
        sa.Column("system_prompt_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("template_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("persona_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("system_prompt_text", sa.Text(), nullable=False),
        sa.Column(
            "user_prompt_text",
            sa.Text(),
            nullable=False,
            server_default="",
        ),
        sa.Column("final_prompt_text", sa.Text(), nullable=False),
        sa.Column("size", sa.String(16), nullable=False),
        sa.Column("quality", sa.String(16), nullable=False),
        sa.Column("n", sa.Integer(), nullable=False),
        sa.Column(
            "image_keys",
            postgresql.ARRAY(sa.String()),
            nullable=False,
            server_default="{}",
        ),
        sa.Column("model_name", sa.String(64), nullable=False),
        sa.Column("elapsed_ms", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "status IN ('success','failed')", name="ck_playground_runs_status"
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["system_prompt_id"],
            ["system_prompts.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["template_id"],
            ["user_prompt_templates.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["persona_id"],
            ["model_personas.id"],
            ondelete="SET NULL",
        ),
    )
    op.create_index(
        "ix_playground_runs_user_id_created_at",
        "playground_runs",
        ["user_id", "created_at"],
        unique=False,
    )

    # ---- Seeds ----
    bind = op.get_bind()

    bind.execute(
        sa.text(
            "INSERT INTO system_prompts (id, slug, label, content, is_active) "
            "VALUES (:id, :slug, :label, :content, true)"
        ),
        {
            "id": str(uuid.uuid4()),
            "slug": "global",
            "label": "Global editorial system prompt",
            "content": GLOBAL_SYSTEM_PROMPT_CONTENT,
        },
    )

    for tpl in TEMPLATES_SEED:
        bind.execute(
            sa.text(
                "INSERT INTO user_prompt_templates (id, slug, label, description, body, is_active) "
                "VALUES (:id, :slug, :label, :description, :body, true)"
            ),
            {"id": str(uuid.uuid4()), **tpl},
        )

    for persona in PERSONAS_SEED:
        bind.execute(
            sa.text(
                "INSERT INTO model_personas (id, slug, label, gender, description, is_active) "
                "VALUES (:id, :slug, :label, :gender, :description, true)"
            ),
            {"id": str(uuid.uuid4()), **persona},
        )


def downgrade() -> None:
    op.drop_index(
        "ix_playground_runs_user_id_created_at", table_name="playground_runs"
    )
    op.drop_table("playground_runs")
    op.drop_index("ix_model_personas_gender", table_name="model_personas")
    op.drop_index("ix_model_personas_slug", table_name="model_personas")
    op.drop_table("model_personas")
    op.drop_index(
        "ix_user_prompt_templates_slug", table_name="user_prompt_templates"
    )
    op.drop_table("user_prompt_templates")
    op.drop_index("ix_system_prompts_slug", table_name="system_prompts")
    op.drop_table("system_prompts")
