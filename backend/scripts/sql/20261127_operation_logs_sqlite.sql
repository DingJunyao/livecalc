-- 20261127 operation_logs 补齐（SQLite）
-- 背景：operation_logs 早在迁移 20260320_0001 中定义，但旧库若从未创建该表
-- （历史原因是模型未被 app/models/__init__.py 注册，create_all 不会建它），
-- 账号注销接口会执行 DELETE FROM operation_logs 而报 "no such table"。
-- 本脚本幂等（IF NOT EXISTS），可在既有库上安全重复执行。
-- 验证：SELECT name FROM sqlite_master WHERE type='table' AND name='operation_logs';
--       PRAGMA index_list('operation_logs');
-- 回滚：DROP TABLE IF EXISTS operation_logs;
-- 说明：正常部署优先「重启后端」（启动时 create_all 会补建缺失表）或 alembic upgrade head；
--       本脚本用于无法重启/无 alembic 的既有安装。

CREATE TABLE IF NOT EXISTS operation_logs (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER NOT NULL,
    user_id INTEGER,
    old_data JSON,
    new_data JSON,
    changed_fields JSON,
    description TEXT,
    ip_address VARCHAR(50),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX IF NOT EXISTS ix_operation_logs_id ON operation_logs (id);
CREATE INDEX IF NOT EXISTS ix_operation_logs_action ON operation_logs (action);
CREATE INDEX IF NOT EXISTS ix_operation_logs_table_name ON operation_logs (table_name);
CREATE INDEX IF NOT EXISTS ix_operation_logs_record_id ON operation_logs (record_id);
CREATE INDEX IF NOT EXISTS ix_operation_logs_user_id ON operation_logs (user_id);
CREATE INDEX IF NOT EXISTS ix_operation_logs_created_at ON operation_logs (created_at);
