"""meal_plans 试算方案（阶段 3，设计 §5.1）

meal_plans + meal_plan_items（条目三选一 CheckConstraint）；
daily_recommendations 加 plan_id（source='plan' 的方案来源餐回链）。

配套 SQL 脚本（按引擎）：
    backend/scripts/sql/20261015_meal_plans_{sqlite,mysql,postgresql}.sql

Revision ID: 20261015_0003
Revises: 20261015_0002
Create Date: 2026-10-16
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '20261015_0003'
down_revision: Union[str, None] = '20261015_0002'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

PLANS = 'meal_plans'
ITEMS = 'meal_plan_items'
PARENT = 'daily_recommendations'


def _has_table(name: str) -> bool:
    return name in sa.inspect(op.get_bind()).get_table_names()


def _has_column(table: str, column: str) -> bool:
    return column in {c['name'] for c in sa.inspect(op.get_bind()).get_columns(table)}


def upgrade() -> None:
    if not _has_table(PLANS):
        op.create_table(
            PLANS,
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
            sa.Column('name', sa.String(120), nullable=False),
            sa.Column('kind', sa.String(10), nullable=False, server_default='meal'),
            sa.Column('note', sa.String(200), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('CURRENT_TIMESTAMP'), nullable=False),
            sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('CURRENT_TIMESTAMP'), nullable=False),
            sa.Column('created_by', sa.Integer(), nullable=True),
            sa.Column('updated_by', sa.Integer(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
        )
        op.create_index('ix_meal_plans_user_id', PLANS, ['user_id'])

    if not _has_table(ITEMS):
        op.create_table(
            ITEMS,
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('plan_id', sa.Integer(), sa.ForeignKey('meal_plans.id'), nullable=False),
            sa.Column('group', sa.String(20), nullable=False, server_default='other'),
            sa.Column('item_type', sa.String(20), nullable=False),
            sa.Column('recipe_id', sa.Integer(), sa.ForeignKey('recipes.id'), nullable=True),
            sa.Column('ingredient_id', sa.Integer(), sa.ForeignKey('ingredients.id'), nullable=True),
            sa.Column('product_id', sa.Integer(), sa.ForeignKey('products.id'), nullable=True),
            sa.Column('servings', sa.Numeric(6, 2), nullable=True),
            sa.Column('quantity', sa.Numeric(12, 4), nullable=True),
            sa.Column('unit_id', sa.Integer(), sa.ForeignKey('units.id'), nullable=True),
            sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('note', sa.String(200), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('CURRENT_TIMESTAMP'), nullable=False),
            sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('CURRENT_TIMESTAMP'), nullable=False),
            sa.Column('created_by', sa.Integer(), nullable=True),
            sa.Column('updated_by', sa.Integer(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.CheckConstraint(
                "(item_type = 'recipe' AND recipe_id IS NOT NULL AND ingredient_id IS NULL AND product_id IS NULL) "
                "OR (item_type = 'ingredient' AND ingredient_id IS NOT NULL AND recipe_id IS NULL AND product_id IS NULL) "
                "OR (item_type = 'product' AND product_id IS NOT NULL AND recipe_id IS NULL AND ingredient_id IS NULL)",
                name='ck_meal_plan_item_type',
            ),
        )
        op.create_index('ix_meal_plan_items_plan_id', ITEMS, ['plan_id'])

    if not _has_column(PARENT, 'plan_id'):
        op.add_column(PARENT, sa.Column(
            'plan_id', sa.Integer(), sa.ForeignKey('meal_plans.id'), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table(PARENT) as batch:
        if _has_column(PARENT, 'plan_id'):
            batch.drop_column('plan_id')
    if _has_table(ITEMS):
        op.drop_table(ITEMS)
    if _has_table(PLANS):
        op.drop_table(PLANS)
