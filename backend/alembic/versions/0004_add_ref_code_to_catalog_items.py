"""Add ref_code to catalog_items

Revision ID: 0004
Revises: 0003
Create Date: 2026-03-30
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "catalog_items",
        sa.Column("ref_code", sa.String(100), nullable=True),
    )
    op.create_unique_constraint("uq_catalog_items_ref_code", "catalog_items", ["ref_code"])
    op.create_index("ix_catalog_items_ref_code", "catalog_items", ["ref_code"])


def downgrade() -> None:
    op.drop_index("ix_catalog_items_ref_code", table_name="catalog_items")
    op.drop_constraint("uq_catalog_items_ref_code", "catalog_items", type_="unique")
    op.drop_column("catalog_items", "ref_code")
