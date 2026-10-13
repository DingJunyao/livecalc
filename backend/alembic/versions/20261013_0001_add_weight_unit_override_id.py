"""add weight_unit_override_id to entity_unit_overrides

自定义单位的「单个重量」可以以同一实体的另一个自定义单位为量纲（嵌套）：
    1箱 = 12 盒（weight_per_unit=12, weight_unit_override_id → 盒）
    1盒 = 220 mL（weight_per_unit=220, weight_unit_id → mL）
从而 1箱 = 2640 mL，且编辑「盒」时「箱」自动跟随。

故意不加 DB 级自引用外键：软删（is_active）+ 导出导入会重排行 id，引用完整性
由应用层（proposals 执行器 validate / UnitConversionService 解析）保证，
这样三种数据库的 DDL 完全一致。

配套 SQL 脚本（按引擎）：
    backend/scripts/sql/20261013_entity_unit_weight_override_{sqlite,mysql,postgresql}.sql

Revision ID: 20261013_0001
Revises: 20261004_0001
Create Date: 2026-10-13
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20261013_0001'
down_revision: Union[str, None] = '20261004_0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = 'entity_unit_overrides'
COLUMN = 'weight_unit_override_id'
INDEX = 'ix_entity_unit_overrides_weight_unit_override_id'


def _has_column(table_name: str, column_name: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return column_name in {c['name'] for c in insp.get_columns(table_name)}


def _has_index(table_name: str, index_name: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return index_name in {i['name'] for i in insp.get_indexes(table_name)}


def upgrade() -> None:
    if not _has_column(TABLE, COLUMN):
        op.add_column(TABLE, sa.Column(COLUMN, sa.Integer(), nullable=True))
    if not _has_index(TABLE, INDEX):
        op.create_index(INDEX, TABLE, [COLUMN])


def downgrade() -> None:
    if _has_index(TABLE, INDEX):
        op.drop_index(INDEX, table_name=TABLE)
    if _has_column(TABLE, COLUMN):
        # SQLite 3.35+ 才支持 DROP COLUMN；更老的版本请手动重建表
        op.drop_column(TABLE, COLUMN)
