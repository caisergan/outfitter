"""Add gender to catalog_items

Revision ID: 0006
Revises: 0005
Create Date: 2026-04-12
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0006"
down_revision: Union[str, None] = "0005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "catalog_items",
        sa.Column("gender", sa.String(length=16), nullable=True),
    )
    op.create_index("ix_catalog_items_gender", "catalog_items", ["gender"])


def downgrade() -> None:
    op.drop_index("ix_catalog_items_gender", table_name="catalog_items")
    op.drop_column("catalog_items", "gender")
