"""Add barcode lookup cache

Revision ID: 20260821_0001
Revises: 20260806_0001
Create Date: 2026-08-21 23:00:00.000000
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "20260821_0001"
down_revision: Union[str, None] = "20260806_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "barcode_lookup_cache",
        sa.Column("barcode", sa.String(length=50), nullable=False),
        sa.Column("payload", sa.Text(), nullable=False),
        sa.Column("source", sa.String(length=100), nullable=False),
        sa.Column(
            "fetched_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("barcode"),
    )
    op.create_index(
        "ix_barcode_lookup_cache_expires_at",
        "barcode_lookup_cache",
        ["expires_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_barcode_lookup_cache_expires_at", table_name="barcode_lookup_cache"
    )
    op.drop_table("barcode_lookup_cache")
