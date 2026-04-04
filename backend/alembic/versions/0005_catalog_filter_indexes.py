"""Add B-tree and GIN indexes for catalog filter columns

Revision ID: 0005
Revises: 0004
Create Date: 2026-04-05

Adds indexes to support the query patterns used in GET /catalog/search:
- fit: exact-match B-tree index
- color: GIN index for array overlap queries (color.overlap(...))
- style_tags: GIN index for array containment queries (style_tags.contains([...]))
"""
from typing import Sequence, Union

from alembic import op

revision: str = "0005"
down_revision: Union[str, None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # B-tree index for exact fit filter
    op.create_index("ix_catalog_items_fit", "catalog_items", ["fit"])

    # GIN indexes for array overlap / containment filters
    op.execute("""
        CREATE INDEX ix_catalog_items_color_gin
        ON catalog_items
        USING gin (color);
    """)
    op.execute("""
        CREATE INDEX ix_catalog_items_style_tags_gin
        ON catalog_items
        USING gin (style_tags);
    """)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_catalog_items_style_tags_gin;")
    op.execute("DROP INDEX IF EXISTS ix_catalog_items_color_gin;")
    op.drop_index("ix_catalog_items_fit", table_name="catalog_items")
