-- 20261015 每日推荐「父表 + 子表」与 AI 策略层（SQLite）
-- 存量库（未跑 alembic 的开发/部署库）可手工执行本脚本；新装库由 create_all 自动建。
-- 注意：脚本可重复执行的安全性靠人工判断（SQLite 无 IF NOT EXISTS 的 ADD COLUMN），
-- 重复执行报 duplicate column name 可忽略。

-- 1) 父表新列
ALTER TABLE daily_recommendations ADD COLUMN reason TEXT NULL;
ALTER TABLE daily_recommendations ADD COLUMN preference VARCHAR(200) NULL;
ALTER TABLE daily_recommendations ADD COLUMN source VARCHAR(20) NOT NULL DEFAULT 'rule';
ALTER TABLE daily_recommendations ADD COLUMN refresh_count INTEGER NOT NULL DEFAULT 0;

-- 2) 子表（每道菜一行）
CREATE TABLE IF NOT EXISTS daily_recommendation_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    recommendation_id INTEGER NOT NULL REFERENCES daily_recommendations(id),
    recipe_id INTEGER NOT NULL REFERENCES recipes(id),
    sort_order INTEGER NOT NULL DEFAULT 0,
    role VARCHAR(20) NOT NULL DEFAULT 'main',
    reason TEXT NULL
);
CREATE INDEX IF NOT EXISTS ix_daily_recommendation_items_recommendation_id
    ON daily_recommendation_items (recommendation_id);
CREATE INDEX IF NOT EXISTS ix_daily_recommendation_items_recipe_id
    ON daily_recommendation_items (recipe_id);

-- 3) 回填旧数据（必须先于第 4 步）
INSERT INTO daily_recommendation_items (recommendation_id, recipe_id, sort_order, role)
    SELECT id, recipe_id, 0, 'staple' FROM daily_recommendations
    WHERE recipe_id IS NOT NULL;

-- 4) 删除父表 recipe_id
-- 注意：recipe_id 是表级外键约束（FOREIGN KEY(recipe_id) REFERENCES recipes），
-- SQLite 的 DROP COLUMN 移不掉该约束子句（报 unknown column "recipe_id" in
-- foreign key definition），必须用标准 12 步重建法；若你已踩过该错，
-- 改执行 20261015_recommendation_items_sqlite_repair.sql（续行脚本）。
PRAGMA foreign_keys=OFF;
BEGIN;

CREATE TABLE daily_recommendations_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    date DATE NOT NULL,
    meal_type VARCHAR(20) NOT NULL,
    reason TEXT NULL,
    preference VARCHAR(200) NULL,
    source VARCHAR(20) NOT NULL DEFAULT 'rule',
    refresh_count INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_date_meal UNIQUE (user_id, date, meal_type)
);

INSERT INTO daily_recommendations_new
    (id, user_id, date, meal_type, reason, preference, source, refresh_count, created_at)
SELECT id, user_id, date, meal_type, reason, preference, source, refresh_count, created_at
FROM daily_recommendations;

DROP TABLE daily_recommendations;
ALTER TABLE daily_recommendations_new RENAME TO daily_recommendations;

COMMIT;
PRAGMA foreign_keys=ON;

-- 5) AI 策略层
CREATE TABLE IF NOT EXISTS user_ai_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id),
    method VARCHAR(20) NULL,
    provider VARCHAR(20) NULL,
    base_url VARCHAR(200) NULL,
    api_key_enc VARCHAR(500) NULL,
    model VARCHAR(100) NULL,
    daily_ai_limit_override INTEGER NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_user_ai_settings_user_id ON user_ai_settings (user_id);

CREATE TABLE IF NOT EXISTS ai_usage_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    scope VARCHAR(40) NOT NULL,
    method VARCHAR(20) NOT NULL,
    provider VARCHAR(20) NULL,
    status VARCHAR(20) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_ai_usage_events_user_id ON ai_usage_events (user_id);
CREATE INDEX IF NOT EXISTS ix_ai_usage_events_created_at ON ai_usage_events (created_at);

-- 回滚：见 alembic 20261015_0002.downgrade()
