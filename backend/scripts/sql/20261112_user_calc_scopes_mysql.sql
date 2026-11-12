-- 20261112 user_calc_scopes + users.default_calc_scope_id（MySQL）
-- 用户自定义计算范围（多地区组合）：名称 + region_ids（administrative_regions.id 列表，
-- 层级可混合）。users.default_calc_scope_id 指向本表作为默认计算范围，
-- 与既有 users.default_calc_scope 层级档位互斥写入（设一方清另一方）。
-- 可重复执行由调用方判断（MySQL 无 IF NOT EXISTS 用于 ADD COLUMN）。
-- 验证：SHOW COLUMNS FROM users LIKE 'default_calc_scope_id';
--       SHOW CREATE TABLE user_calc_scopes;
-- 回滚（确认无数据依赖后）：
--   ALTER TABLE users DROP FOREIGN KEY fk_users_calc_scope, DROP COLUMN default_calc_scope_id;
--   DROP TABLE IF EXISTS user_calc_scopes;

CREATE TABLE IF NOT EXISTS user_calc_scopes (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    region_ids JSON NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_calc_scopes UNIQUE (user_id, name),
    INDEX ix_user_calc_scopes_user_id (user_id),
    CONSTRAINT fk_user_calc_scopes_user FOREIGN KEY (user_id) REFERENCES users(id)
);

-- users 表加列 + 外键（若列已存在请跳过两行）
ALTER TABLE users ADD COLUMN default_calc_scope_id INTEGER NULL;
ALTER TABLE users ADD CONSTRAINT fk_users_calc_scope FOREIGN KEY (default_calc_scope_id) REFERENCES user_calc_scopes(id);
