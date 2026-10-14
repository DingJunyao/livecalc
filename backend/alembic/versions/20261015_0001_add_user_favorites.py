"""add user_favorites table

三类实体的收藏（原料/商品/菜谱）；商家收藏沿用 user_merchant_favorites。
纯链接表：取消收藏=物理删除。entity_id 多态，不加跨表外键（软删 + 导入重排 id），
存在性由 API 层校验。

配套 SQL 脚本（按引擎）：
    backend/scripts/sql/20261015_user_favorites_{sqlite,mysql,postgresql}.sql

Revision ID: 20261015_0001
Revises: 20261013_0001
Create Date: 2026-10-15
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '20261015_0001'
down_revision: Union[str, None] = '20261013_0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = 'user_favorites'


def _has_table(table_name: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return table_name in insp.get_table_names()


def upgrade() -> None:
    if _has_table(TABLE):
        return
    op.create_table(
        TABLE,
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('entity_type', sa.String(20), nullable=False),
        sa.Column('entity_id', sa.Integer(), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('CURRENT_TIMESTAMP'),
        ),
        sa.UniqueConstraint('user_id', 'entity_type', 'entity_id', name='uq_user_favorites'),
    )
    op.create_index('ix_user_favorites_user_id', TABLE, ['user_id'])
    op.create_index('ix_user_favorites_entity_id', TABLE, ['entity_id'])


def downgrade() -> None:
    if _has_table(TABLE):
        op.drop_table(TABLE)
