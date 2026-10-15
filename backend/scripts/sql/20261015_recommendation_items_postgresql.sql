-- 20261015 每日推荐「父表 + 子表」与 AI 策略层（PostgreSQL，与 PostGIS 无关）

ALTER TABLE daily_recommendations
    ADD COLUMN IF NOT EXISTS reason TEXT NULL,
    ADD COLUMN IF NOT EXISTS preference VARCHAR(200) NULL,
    ADD COLUMN IF NOT EXISTS source VARCHAR(20) NOT NULL DEFAULT 'rule',
    ADD COLUMN IF NOT EXISTS refresh_count INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS daily_recommendation_items (
    id SERIAL PRIMARY KEY,
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

INSERT INTO daily_recommendation_items (recommendation_id, recipe_id, sort_order, role)
    SELECT id, recipe_id, 0, 'staple' FROM daily_recommendations
    WHERE recipe_id IS NOT NULL
    ON CONFLICT DO NOTHING;

-- 列已确认存在（上面 IF NOT EXISTS 只对新装库跳过）；旧库直接删
ALTER TABLE daily_recommendations DROP COLUMN IF EXISTS recipe_id;

CREATE TABLE IF NOT EXISTS user_ai_settings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id),
    method VARCHAR(20) NULL,
    provider VARCHAR(20) NULL,
    base_url VARCHAR(200) NULL,
    api_key_enc VARCHAR(500) NULL,
    model VARCHAR(100) NULL,
    daily_ai_limit_override INTEGER NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_user_ai_settings_user_id ON user_ai_settings (user_id);

CREATE TABLE IF NOT EXISTS ai_usage_events (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    scope VARCHAR(40) NOT NULL,
    method VARCHAR(20) NOT NULL,
    provider VARCHAR(20) NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_ai_usage_events_user_id ON ai_usage_events (user_id);
CREATE INDEX IF NOT EXISTS ix_ai_usage_events_created_at ON ai_usage_events (created_at);
