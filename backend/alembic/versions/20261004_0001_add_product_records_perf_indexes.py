"""product_records 查询性能索引

为价格查询热点路径补复合索引 (product_id, recorded_at)：
成本计算/前向填充/latest-price/sparkline 均为
``WHERE product_id = ? AND recorded_at <= ? ORDER BY recorded_at``
形态，此前 product_id / recorded_at 无任何索引，全部走全表扫描。

对应 SQL 脚本：scripts/sql/20261004_product_records_perf_indexes_{sqlite,mysql,postgresql}.sql
"""
from alembic import op

revision = "20261004_0001"
down_revision = "20260831_0002"
branch_labels = None
depends_on = None

INDEX_NAME = "ix_product_records_product_recorded"


def upgrade() -> None:
    op.create_index(INDEX_NAME, "product_records", ["product_id", "recorded_at"])


def downgrade() -> None:
    op.drop_index(INDEX_NAME, table_name="product_records")
