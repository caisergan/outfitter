"""Allow 'pending' status on tryon_runs

Revision ID: 0012
Revises: 0011
Create Date: 2026-04-30

Extends the status check constraint to permit `'pending'` so the async
generate flow can persist a row before kicking off the long-running codex
call. Existing rows are unaffected — `'success'` and `'failed'` remain
valid and no data conversion is needed.

Sequenced AFTER 0011 (playground -> tryon rename) so deployments that
sit at 0009 (i.e. never applied the legacy 0010 status update) operate
on the renamed `tryon_runs` table. Fresh DBs created by the rewritten
0008 already have `tryon_runs`, and 0011 is a no-op for them, so the
chain works in both cases.
"""
from typing import Sequence, Union

from alembic import op

revision: str = "0012"
down_revision: Union[str, None] = "0011"
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
