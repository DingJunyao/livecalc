"""ingredient_hierarchies 增加可选换算系数（substitutable/fallback 折算用）

语义：factor_parent_quantity [factor_parent_unit] 父 = factor_child_quantity [factor_child_unit] 子
NULL = 1:1（与历史行为完全一致）。
例：1 kg 干香菇(父) = 3 kg 鲜香菇(子) → 子缺价时 ppg_子 = ppg_父 × 1/3

配套 SQL 脚本（按引擎）：
  backend/scripts/sql/20261023_hierarchy_factor_{sqlite,mysql,postgresql}.sql

Revision ID: 20261023_0001
Revises: 20261022_0001
Create Date: 2026-10-23
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20261023_0001"
down_revision: Union[str, None] = "20261022_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = "ingredient_hierarchies"
COLUMNS = (
    ("factor_parent_quantity", sa.Numeric(15, 6)),
    ("factor_parent_unit", sa.String(50)),
    ("factor_child_quantity", sa.Numeric(15, 6)),
    ("factor_child_unit", sa.String(50)),
)


def _existing_columns(bind) -> set:
    inspector = sa.inspect(bind)
    return {c["name"] for c in inspector.get_columns(TABLE)}


def upgrade() -> None:
    existing = _existing_columns(op.get_bind())
    for name, col_type in COLUMNS:
        if name in existing:
            continue
        op.add_column(TABLE, sa.Column(name, col_type, nullable=True))


def downgrade() -> None:
    existing = _existing_columns(op.get_bind())
    for name, _col_type in reversed(COLUMNS):
        if name in existing:
            op.drop_column(TABLE, name)
