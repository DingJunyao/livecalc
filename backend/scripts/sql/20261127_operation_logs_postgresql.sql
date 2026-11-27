-- 20261127 operation_logs 补齐（PostgreSQL；未启用 PostGIS 时同样适用）
-- 背景：operation_logs 早在迁移 20260320_0001 中定义，但旧库若从未创建该表，
-- 账号注销接口执行 DELETE FROM operation_logs 会失败（relation does not exist）。
-- 本脚本幂等（IF NOT EXISTS），可在既有库上重复执行。
-- 验证：\d operation_logs
-- 回滚：DROP TABLE IF EXISTS operation_logs;
-- 说明：正常部署优先「重启后端」（create_all 会补建缺失表）或 alembic upgrade head。

CREATE TABLE IF NOT EXISTS operation_logs (
    id SERIAL PRIMARY KEY,
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER NOT NULL,
    user_id INTEGER NULL REFERENCES users(id),
    old_data JSON,
    new_data JSON,
    changed_fields JSON,
    description TEXT,
    ip_address VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_operation_logs_action ON operation_logs (action);
CREATE INDEX IF NOT EXISTS ix_operation_logs_table_name ON operation_logs (table_name);
CREATE INDEX IF NOT EXISTS ix_operation_logs_record_id ON operation_logs (record_id);
CREATE INDEX IF NOT EXISTS ix_operation_logs_user_id ON operation_logs (user_id);
CREATE INDEX IF NOT EXISTS ix_operation_logs_created_at ON operation_logs (created_at);
