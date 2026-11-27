-- 20261127 operation_logs 补齐（MySQL）
-- 背景：operation_logs 早在迁移 20260320_0001 中定义，但旧库若从未创建该表，
-- 账号注销接口执行 DELETE FROM operation_logs 会失败。
-- 本脚本幂等（CREATE TABLE IF NOT EXISTS）；若表已存在但缺索引，请按注释里的
-- ALTER 语句手工补齐（MySQL 的 ADD INDEX 不支持 IF NOT EXISTS）。
-- 验证：SHOW CREATE TABLE operation_logs;
-- 回滚：DROP TABLE IF EXISTS operation_logs;
-- 说明：正常部署优先「重启后端」（create_all 会补建缺失表）或 alembic upgrade head。

CREATE TABLE IF NOT EXISTS operation_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER NOT NULL,
    user_id INTEGER NULL,
    old_data JSON NULL,
    new_data JSON NULL,
    changed_fields JSON NULL,
    description TEXT NULL,
    ip_address VARCHAR(50) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX ix_operation_logs_action (action),
    INDEX ix_operation_logs_table_name (table_name),
    INDEX ix_operation_logs_record_id (record_id),
    INDEX ix_operation_logs_user_id (user_id),
    INDEX ix_operation_logs_created_at (created_at),
    CONSTRAINT fk_operation_logs_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 表已存在但缺索引时（逐条执行，报 Duplicate key name 说明已存在）：
-- ALTER TABLE operation_logs ADD INDEX ix_operation_logs_action (action);
-- ALTER TABLE operation_logs ADD INDEX ix_operation_logs_table_name (table_name);
-- ALTER TABLE operation_logs ADD INDEX ix_operation_logs_record_id (record_id);
-- ALTER TABLE operation_logs ADD INDEX ix_operation_logs_user_id (user_id);
-- ALTER TABLE operation_logs ADD INDEX ix_operation_logs_created_at (created_at);
