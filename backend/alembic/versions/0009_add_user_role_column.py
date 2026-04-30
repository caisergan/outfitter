"""Add role column to users

Revision ID: 0009
Revises: 0008
Create Date: 2026-04-30

Adds a `role` column to `users` to gate admin-only endpoints (system-prompt
edit, template/persona CRUD, save-as-template). Default 'user' so existing
rows are non-privileged. Enforced via CheckConstraint matching the existing
String + check pattern used elsewhere in the project.

Bootstrap the first admin after running this migration with:

    UPDATE users SET role = 'admin' WHERE email = 'me@example.com';
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0009"
down_revision: Union[str, None] = "0008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "role",
            sa.String(16),
            nullable=False,
            server_default="user",
        ),
    )
    op.create_check_constraint(
        "ck_users_role",
        "users",
        "role IN ('user','admin')",
    )


def downgrade() -> None:
    op.drop_constraint("ck_users_role", "users", type_="check")
    op.drop_column("users", "role")
