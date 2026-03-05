"""Add HNSW vector indexes for catalog_items and wardrobe_items

Revision ID: 0003
Revises: 0002
Create Date: 2026-03-03
"""
from typing import Sequence, Union
from alembic import op

revision: str = "0003"
down_revision: Union[str, None] = "312b1e8cffdf"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # HNSW index on catalog_items.clip_embedding (cosine distance)
    op.execute("""
        CREATE INDEX ix_catalog_items_clip_embedding_hnsw
        ON catalog_items
        USING hnsw (clip_embedding vector_cosine_ops)
        WITH (m = 16, ef_construction = 64);
    """)

    # HNSW index on wardrobe_items.clip_embedding (cosine distance)
    op.execute("""
        CREATE INDEX ix_wardrobe_items_clip_embedding_hnsw
        ON wardrobe_items
        USING hnsw (clip_embedding vector_cosine_ops)
        WITH (m = 16, ef_construction = 64);
    """)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_wardrobe_items_clip_embedding_hnsw;")
    op.execute("DROP INDEX IF EXISTS ix_catalog_items_clip_embedding_hnsw;")
