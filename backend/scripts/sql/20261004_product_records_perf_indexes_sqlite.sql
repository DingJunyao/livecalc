-- 20261004 product_records 查询性能索引（SQLite）
-- 价格查询热点：WHERE product_id = ? AND recorded_at <= ? ORDER BY recorded_at
CREATE INDEX IF NOT EXISTS ix_product_records_product_recorded
    ON product_records (product_id, recorded_at);
