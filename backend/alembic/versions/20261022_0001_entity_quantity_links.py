"""entity_quantity_links：商品/原料两两数量关联

一条关联即一句等式：
  from_quantity [from_unit] of from_entity = to_quantity [to_unit] of to_entity

不合并商品/原料，不引入基准/成员/组；仅用于单位折克与缺价折算。

配套 SQL 脚本（按引擎）：
  backend/scripts/sql/20261022_entity_quantity_links_{sqlite,mysql,postgresql}.sql

Revision ID: 20261022_0001
Revises: 20261015_0003
Create Date: 2026-10-22
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20261022_0001"
down_revision: Union[str, None] = "20261015_0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = "entity_quantity_links"


def _has_table(name: str) -> bool:
    return name in sa.inspect(op.get_bind()).get_table_names()


def upgrade() -> None:
    if _has_table(TABLE):
        return
    op.create_table(
        TABLE,
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("from_type", sa.String(20), nullable=False),
        sa.Column("from_id", sa.Integer(), nullable=False),
        sa.Column("from_quantity", sa.Numeric(15, 6), nullable=False, server_default="1"),
        sa.Column("from_unit", sa.String(50), nullable=False),
        sa.Column("to_type", sa.String(20), nullable=False),
        sa.Column("to_id", sa.Integer(), nullable=False),
        sa.Column("to_quantity", sa.Numeric(15, 6), nullable=False, server_default="1"),
        sa.Column("to_unit", sa.String(50), nullable=False),
        sa.Column("note", sa.String(200), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=True),
        sa.Column("created_by", sa.Integer(), nullable=True),
        sa.Column("updated_by", sa.Integer(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )
    op.create_index("ix_entity_quantity_links_from_type", TABLE, ["from_type"])
    op.create_index("ix_entity_quantity_links_to_type", TABLE, ["to_type"])
    op.create_index("ix_entity_quantity_link_from", TABLE, ["from_type", "from_id"])
    op.create_index("ix_entity_quantity_link_to", TABLE, ["to_type", "to_id"])
    op.create_index(
        "ix_entity_quantity_link_from_active",
        TABLE, ["from_type", "from_id", "is_active"],
    )
    op.create_index(
        "ix_entity_quantity_link_to_active",
        TABLE, ["to_type", "to_id", "is_active"],
    )


def downgrade() -> None:
    if _has_table(TABLE):
        op.drop_table(TABLE)
