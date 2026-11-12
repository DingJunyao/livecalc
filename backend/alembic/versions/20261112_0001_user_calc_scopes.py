"""用户自定义计算范围（多地区组合）

语义：user_calc_scopes 表 = 名称 + region_ids（JSON，administrative_regions.id
列表，层级可混合，如一个县 + 一个地级市）；users.default_calc_scope_id 指向
本表作为默认计算范围，与既有 default_calc_scope 层级档位互斥写入。
计算按各地区子树并集过滤（app/services/price_region.py）。

配套 SQL 脚本（按引擎）：
  backend/scripts/sql/20261112_user_calc_scopes_{sqlite,mysql,postgresql}.sql

Revision ID: 20261112_0001
Revises: 20261023_0001
Create Date: 2026-11-12
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20261112_0001"
down_revision: Union[str, None] = "20261023_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = "user_calc_scopes"
USER_COLUMN = "default_calc_scope_id"


def _table_exists(bind) -> bool:
    inspector = sa.inspect(bind)
    return TABLE in inspector.get_table_names()


def _user_columns(bind) -> set:
    inspector = sa.inspect(bind)
    return {c["name"] for c in inspector.get_columns("users")}


def upgrade() -> None:
    if not _table_exists(op.get_bind()):
        op.create_table(
            TABLE,
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, index=True),
            sa.Column("name", sa.String(length=100), nullable=False),
            sa.Column("region_ids", sa.JSON(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
            sa.UniqueConstraint("user_id", "name", name="uq_user_calc_scopes"),
        )
        op.create_index("ix_user_calc_scopes_user_id", TABLE, ["user_id"])

    existing = _user_columns(op.get_bind())
    if USER_COLUMN not in existing:
        op.add_column(
            "users",
            sa.Column(USER_COLUMN, sa.Integer(), sa.ForeignKey(f"{TABLE}.id"), nullable=True),
        )


def downgrade() -> None:
    existing = _user_columns(op.get_bind())
    if USER_COLUMN in existing:
        op.drop_column("users", USER_COLUMN)

    if _table_exists(op.get_bind()):
        op.drop_table(TABLE)
