-- 20261004 product_records 查询性能索引（MySQL）
-- 价格查询热点：WHERE product_id = ? AND recorded_at <= ? ORDER BY recorded_at
-- MySQL 8.0 不支持 CREATE INDEX IF NOT EXISTS，重复执行会报 1061（Duplicate key name），可忽略。
CREATE INDEX ix_product_records_product_recorded
    ON product_records (product_id, recorded_at);
