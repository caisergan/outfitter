"""Allow 'pending' status on tryon_runs

Revision ID: 0010
Revises: 0009
Create Date: 2026-04-30

Extends the status check constraint to permit `'pending'` so the new async
generate flow can persist a row before kicking off the long-running codex
call. Existing rows are unaffected — `'success'` and `'failed'` remain
valid and no data conversion is needed.
"""
from typing import Sequence, Union

from alembic import op

revision: str = "0010"
down_revision: Union[str, None] = "0009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint(
        "ck_tryon_runs_status",
        "tryon_runs",
        type_="check",
    )
    op.create_check_constraint(
        "ck_tryon_runs_status",
        "tryon_runs",
        "status IN ('pending','success','failed')",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_tryon_runs_status",
        "tryon_runs",
        type_="check",
    )
    op.create_check_constraint(
        "ck_tryon_runs_status",
        "tryon_runs",
        "status IN ('success','failed')",
    )
