-- 20261112 user_calc_scopes + users.default_calc_scope_id（SQLite）
-- 用户自定义计算范围（多地区组合）：名称 + region_ids（administrative_regions.id 列表，
-- 层级可混合）。users.default_calc_scope_id 指向本表作为默认计算范围，
-- 与既有 users.default_calc_scope 层级档位互斥写入（设一方清另一方）。
-- 执行前请备份数据库；表可重复执行（IF NOT EXISTS），加列需调用方判断列是否已存在。
-- 验证：SELECT sql FROM sqlite_master WHERE name IN ('user_calc_scopes','users');
--       PRAGMA table_info(users);  -- 应看到 default_calc_scope_id 列
-- 回滚（确认无数据依赖后）：
--   ALTER TABLE users DROP COLUMN default_calc_scope_id;  -- 需 12 步重建法（表级 FK），见 agent_doc
--   DROP TABLE IF EXISTS user_calc_scopes;

CREATE TABLE IF NOT EXISTS user_calc_scopes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    region_ids JSON NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME,
    CONSTRAINT uq_user_calc_scopes UNIQUE (user_id, name)
);

CREATE INDEX IF NOT EXISTS ix_user_calc_scopes_user_id ON user_calc_scopes (user_id);

-- users 表加列（SQLite ADD COLUMN 支持 REFERENCES 子句；若列已存在请跳过本行）
ALTER TABLE users ADD COLUMN default_calc_scope_id INTEGER REFERENCES user_calc_scopes(id);
