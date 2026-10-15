"""widen nutrition_data.reference_unit to 50

营养基准单位不再只有 g/mL：可以是原料自定义单位的名称（如「袋」，
由实体单位覆盖折算成克）。名称宽度与 units.name / entity_unit_overrides.unit_name
对齐（50），否则 PG/MySQL 上超 10 字符的单位名会写入失败。

配套 SQL 脚本（按引擎）：
    backend/scripts/sql/20261015_nutrition_reference_unit_{sqlite,mysql,postgresql}.sql

Revision ID: 20261015_0002
Revises: 20261015_0001
Create Date: 2026-10-15
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '20261015_0002'
down_revision: Union[str, None] = '20261015_0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = 'nutrition_data'
COLUMN = 'reference_unit'


def _has_table(table_name: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return table_name in insp.get_table_names()


def _current_length() -> int | None:
    insp = sa.inspect(op.get_bind())
    for column in insp.get_columns(TABLE):
        if column['name'] == COLUMN:
            length = getattr(column['type'], 'length', None)
            return length
    return None


def upgrade() -> None:
    if not _has_table(TABLE):
        return
    if _current_length() == 50:
        return
    # SQLite 无长度语义（且不支持 ALTER COLUMN），batch_alter_table 会重建表；
    # 列类型缩放宽不做数据搬迁风险操作，长度在此仅影响非 SQLite 引擎。
    with op.batch_alter_table(TABLE) as batch_op:
        batch_op.alter_column(
            COLUMN,
            existing_type=sa.String(10),
            type_=sa.String(50),
            existing_nullable=False,
        )


def downgrade() -> None:
    if not _has_table(TABLE):
        return
    with op.batch_alter_table(TABLE) as batch_op:
        batch_op.alter_column(
            COLUMN,
            existing_type=sa.String(50),
            type_=sa.String(10),
            existing_nullable=False,
        )
