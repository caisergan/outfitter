"""Split catalog/wardrobe taxonomy into slot, category, subcategory

Revision ID: 0013
Revises: 0012
Create Date: 2026-05-01

Phase 1 of the catalog taxonomy refactor (see
docs/plans/2026-05-01-catalog-taxonomy-refactor.md). Additive only —
no data is destroyed; CHECK constraints + NOT NULL come in 0014 after
Phase 2 backfill.

For BOTH ``catalog_items`` and ``wardrobe_items``:
  - Rename ``category`` -> ``slot`` (10-value wardrobe slot vocabulary)
  - Rename index ``ix_*_category`` -> ``ix_*_slot``
  - Rename ``subtype`` -> ``subcategory`` (data preserved; cleanup is Phase 2)
  - Add new ``category`` column (nullable; ~31-value garment-type vocab,
    backfilled by Phase 2)
  - Add ``occasion_tags`` array column (nullable; populated by vision-AI
    in Phase 4)
  - Add ``pattern_array`` array column (nullable; backfilled from the
    existing scalar ``pattern`` in Phase 2; the scalar gets dropped and
    ``pattern_array`` renamed to ``pattern`` in 0014)

Tests use ``Base.metadata.create_all()`` rather than running migrations
(see ``backend/tests/conftest.py``), so the Postgres-only ``ARRAY`` type
here is fine — conftest patches ``sqlalchemy.ARRAY`` to JSON for the
SQLite test engine independently.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0013"
down_revision: Union[str, None] = "0012"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Tables receiving the same shape changes.
_TABLES: tuple[str, ...] = ("catalog_items", "wardrobe_items")


def upgrade() -> None:
    for table in _TABLES:
        # 1. Rename category -> slot, refresh the index name to match.
        op.alter_column(table, "category", new_column_name="slot")
        op.drop_index(f"ix_{table}_category", table_name=table)
        op.create_index(f"ix_{table}_slot", table, ["slot"])

        # 2. Rename subtype -> subcategory (no index existed on this column).
        op.alter_column(table, "subtype", new_column_name="subcategory")

        # 3. Add new garment-type category column (no index yet — added in 0014
        #    once the backfill finishes and we know the column is populated).
        op.add_column(table, sa.Column("category", sa.String(length=50), nullable=True))

        # 4. Add occasion_tags array column.
        op.add_column(
            table,
            sa.Column("occasion_tags", sa.ARRAY(sa.String()), nullable=True),
        )

        # 5. Add pattern_array column. Old scalar `pattern` stays for Phase 2
        #    backfill; both columns coexist until 0014 drops the scalar and
        #    renames pattern_array -> pattern.
        op.add_column(
            table,
            sa.Column("pattern_array", sa.ARRAY(sa.String()), nullable=True),
        )


def downgrade() -> None:
    # Reverse order so the table walks back to its 0012-state cleanly.
    for table in _TABLES:
        op.drop_column(table, "pattern_array")
        op.drop_column(table, "occasion_tags")
        op.drop_column(table, "category")

        op.alter_column(table, "subcategory", new_column_name="subtype")

        op.drop_index(f"ix_{table}_slot", table_name=table)
        op.alter_column(table, "slot", new_column_name="category")
        op.create_index(f"ix_{table}_category", table, ["category"])
