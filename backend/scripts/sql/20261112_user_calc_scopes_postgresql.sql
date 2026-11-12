-- 20261112 user_calc_scopes + users.default_calc_scope_id（PostgreSQL，与 PostGIS 无关）
-- 用户自定义计算范围（多地区组合）：名称 + region_ids（administrative_regions.id 列表，
-- 层级可混合）。users.default_calc_scope_id 指向本表作为默认计算范围，
-- 与既有 users.default_calc_scope 层级档位互斥写入（设一方清另一方）。
-- 验证：SELECT column_name FROM information_schema.columns WHERE table_name='users' AND column_name='default_calc_scope_id';
--       \d user_calc_scopes
-- 回滚（确认无数据依赖后）：
--   ALTER TABLE users DROP COLUMN IF EXISTS default_calc_scope_id;
--   DROP TABLE IF EXISTS user_calc_scopes;

BEGIN;

CREATE TABLE IF NOT EXISTS user_calc_scopes (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    region_ids JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT uq_user_calc_scopes UNIQUE (user_id, name)
);

CREATE INDEX IF NOT EXISTS ix_user_calc_scopes_user_id ON user_calc_scopes (user_id);

ALTER TABLE users ADD COLUMN IF NOT EXISTS default_calc_scope_id INTEGER REFERENCES user_calc_scopes(id);

COMMIT;
