"""Rename image_url to image_front_url and add image_back_url column

Revision ID: 0007
Revises: 0006
Create Date: 2026-04-23
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0007"
down_revision: Union[str, None] = "0006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "catalog_items",
        "image_url",
        new_column_name="image_front_url",
    )
    op.add_column("catalog_items", sa.Column("image_back_url", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("catalog_items", "image_back_url")
    op.alter_column(
        "catalog_items",
        "image_front_url",
        new_column_name="image_url",
    )
