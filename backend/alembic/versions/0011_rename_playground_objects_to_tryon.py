"""Rename persisted playground objects to tryon

Revision ID: 0011
Revises: 0010
Create Date: 2026-04-30
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0011"
down_revision: Union[str, None] = "0010"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_table(name: str) -> bool:
    return name in sa.inspect(op.get_bind()).get_table_names()


def _has_check_constraint(table_name: str, constraint_name: str) -> bool:
    return any(
        c.get("name") == constraint_name
        for c in sa.inspect(op.get_bind()).get_check_constraints(table_name)
    )


def _has_index(table_name: str, index_name: str) -> bool:
    return any(
        i.get("name") == index_name
        for i in sa.inspect(op.get_bind()).get_indexes(table_name)
    )


def _is_postgres() -> bool:
    return op.get_bind().dialect.name == "postgresql"


def upgrade() -> None:
    if _has_table("playground_runs") and not _has_table("tryon_runs"):
        op.rename_table("playground_runs", "tryon_runs")

    if (
        _is_postgres()
        and _has_table("tryon_runs")
        and _has_check_constraint("tryon_runs", "ck_playground_runs_status")
    ):
        op.execute(
            "ALTER TABLE tryon_runs "
            "RENAME CONSTRAINT ck_playground_runs_status TO ck_tryon_runs_status"
        )
    if (
        _is_postgres()
        and _has_table("tryon_runs")
        and _has_index("tryon_runs", "ix_playground_runs_user_id_created_at")
    ):
        op.execute(
            "ALTER INDEX IF EXISTS ix_playground_runs_user_id_created_at "
            "RENAME TO ix_tryon_runs_user_id_created_at"
        )

    if _has_table("saved_outfits"):
        if _is_postgres():
            op.drop_constraint(
                "ck_saved_outfits_source",
                "saved_outfits",
                type_="check",
            )
        op.execute(
            sa.text("UPDATE saved_outfits SET source = 'tryon' WHERE source = 'playground'")
        )
        if _is_postgres():
            op.create_check_constraint(
                "ck_saved_outfits_source",
                "saved_outfits",
                "source IN ('tryon', 'assistant')",
            )


def downgrade() -> None:
    if _has_table("saved_outfits"):
        if _is_postgres():
            op.drop_constraint(
                "ck_saved_outfits_source",
                "saved_outfits",
                type_="check",
            )
        op.execute(
            sa.text("UPDATE saved_outfits SET source = 'playground' WHERE source = 'tryon'")
        )
        if _is_postgres():
            op.create_check_constraint(
                "ck_saved_outfits_source",
                "saved_outfits",
                "source IN ('playground', 'assistant')",
            )

    if (
        _is_postgres()
        and _has_table("tryon_runs")
        and _has_check_constraint("tryon_runs", "ck_tryon_runs_status")
    ):
        op.execute(
            "ALTER TABLE tryon_runs "
            "RENAME CONSTRAINT ck_tryon_runs_status TO ck_playground_runs_status"
        )
    if (
        _is_postgres()
        and _has_table("tryon_runs")
        and _has_index("tryon_runs", "ix_tryon_runs_user_id_created_at")
    ):
        op.execute(
            "ALTER INDEX IF EXISTS ix_tryon_runs_user_id_created_at "
            "RENAME TO ix_playground_runs_user_id_created_at"
        )

    if _has_table("tryon_runs") and not _has_table("playground_runs"):
        op.rename_table("tryon_runs", "playground_runs")
