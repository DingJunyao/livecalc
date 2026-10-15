"""recommendation items + AI policy tables

每日推荐改「父表 + 子表」：daily_recommendations 加 reason/preference/source/
refresh_count，新建 daily_recommendation_items（每道菜一行），回填旧数据后删除
父表 recipe_id（batch 模式兼容 SQLite）。
AI 使用策略层：user_ai_settings（用户级方法与 BYOK，密钥 Fernet 加密）与
ai_usage_events（用量留痕）。

配套 SQL 脚本（按引擎，供 alembic 之外的存量库手工执行）：
    backend/scripts/sql/20261015_recommendation_items_sqlite.sql

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

PARENT = 'daily_recommendations'
ITEMS = 'daily_recommendation_items'


def _has_table(name: str) -> bool:
    return name in sa.inspect(op.get_bind()).get_table_names()


def _has_column(table: str, column: str) -> bool:
    return column in {c['name'] for c in sa.inspect(op.get_bind()).get_columns(table)}


def _has_index(table: str, index: str) -> bool:
    return index in {i['name'] for i in sa.inspect(op.get_bind()).get_indexes(table)}


def upgrade() -> None:
    # 1) 父表新列
    if not _has_column(PARENT, 'reason'):
        op.add_column(PARENT, sa.Column('reason', sa.Text(), nullable=True))
    if not _has_column(PARENT, 'preference'):
        op.add_column(PARENT, sa.Column('preference', sa.String(200), nullable=True))
    if not _has_column(PARENT, 'source'):
        op.add_column(PARENT, sa.Column(
            'source', sa.String(20), nullable=False, server_default='rule'))
    if not _has_column(PARENT, 'refresh_count'):
        op.add_column(PARENT, sa.Column(
            'refresh_count', sa.Integer(), nullable=False, server_default='0'))

    # 2) 子表
    if not _has_table(ITEMS):
        op.create_table(
            ITEMS,
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('recommendation_id', sa.Integer(),
                      sa.ForeignKey('daily_recommendations.id'), nullable=False),
            sa.Column('recipe_id', sa.Integer(),
                      sa.ForeignKey('recipes.id'), nullable=False),
            sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('role', sa.String(20), nullable=False, server_default='main'),
            sa.Column('reason', sa.Text(), nullable=True),
        )
        op.create_index('ix_daily_recommendation_items_recommendation_id', ITEMS,
                        ['recommendation_id'])
        op.create_index('ix_daily_recommendation_items_recipe_id', ITEMS, ['recipe_id'])

    # 3) 回填：旧的一道菜 → 一条 item
    op.execute(
        f"INSERT INTO {ITEMS} (recommendation_id, recipe_id, sort_order, role) "
        f"SELECT id, recipe_id, 0, 'staple' FROM {PARENT} "
        f"WHERE recipe_id IS NOT NULL"
    )

    # 4) 删除父表 recipe_id（batch 模式兼容 SQLite）
    with op.batch_alter_table(PARENT) as batch:
        if _has_column(PARENT, 'recipe_id'):
            batch.drop_column('recipe_id')

    # 5) AI 策略层两表
    if not _has_table('user_ai_settings'):
        op.create_table(
            'user_ai_settings',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'),
                      nullable=False),
            sa.Column('method', sa.String(20), nullable=True),
            sa.Column('provider', sa.String(20), nullable=True),
            sa.Column('base_url', sa.String(200), nullable=True),
            sa.Column('api_key_enc', sa.String(500), nullable=True),
            sa.Column('model', sa.String(100), nullable=True),
            sa.Column('daily_ai_limit_override', sa.Integer(), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True),
                      server_default=sa.text('CURRENT_TIMESTAMP')),
            sa.Column('updated_at', sa.DateTime(timezone=True),
                      server_default=sa.text('CURRENT_TIMESTAMP')),
            sa.UniqueConstraint('user_id', name='uq_user_ai_settings_user'),
        )
        op.create_index('ix_user_ai_settings_user_id', 'user_ai_settings', ['user_id'])

    if not _has_table('ai_usage_events'):
        op.create_table(
            'ai_usage_events',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'),
                      nullable=False),
            sa.Column('scope', sa.String(40), nullable=False),
            sa.Column('method', sa.String(20), nullable=False),
            sa.Column('provider', sa.String(20), nullable=True),
            sa.Column('status', sa.String(20), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True),
                      server_default=sa.text('CURRENT_TIMESTAMP')),
        )
        op.create_index('ix_ai_usage_events_user_id', 'ai_usage_events', ['user_id'])
        op.create_index('ix_ai_usage_events_created_at', 'ai_usage_events', ['created_at'])


def downgrade() -> None:
    if _has_table('ai_usage_events'):
        op.drop_table('ai_usage_events')
    if _has_table('user_ai_settings'):
        op.drop_table('user_ai_settings')

    with op.batch_alter_table(PARENT) as batch:
        if not _has_column(PARENT, 'recipe_id'):
            batch.add_column(sa.Column('recipe_id', sa.Integer(), nullable=True))
    # 回滚数据：取每餐 sort_order=0 的菜；此前被删除的旧 recipe_id 无法完全恢复
    op.execute(
        f"UPDATE {PARENT} SET recipe_id = ("
        f"  SELECT i.recipe_id FROM {ITEMS} i"
        f"  WHERE i.recommendation_id = {PARENT}.id"
        f"  ORDER BY i.sort_order LIMIT 1)"
    )
    if _has_table(ITEMS):
        op.drop_table(ITEMS)

    with op.batch_alter_table(PARENT) as batch:
        for col in ('refresh_count', 'source', 'preference', 'reason'):
            if _has_column(PARENT, col):
                batch.drop_column(col)
