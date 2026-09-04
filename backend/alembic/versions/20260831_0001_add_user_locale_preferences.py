"""Add user locale preferences.

Revision ID: 20260831_0001
Revises: 20260821_0001
Create Date: 2026-08-31
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "20260831_0001"
down_revision: Union[str, None] = "20260821_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("locale", sa.String(length=10), nullable=True))
    op.add_column(
        "users", sa.Column("format_locale", sa.String(length=10), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("users", "format_locale")
    op.drop_column("users", "locale")
