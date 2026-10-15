-- 20261015 每日推荐「父表 + 子表」与 AI 策略层（MySQL）

ALTER TABLE daily_recommendations
    ADD COLUMN reason TEXT NULL,
    ADD COLUMN preference VARCHAR(200) NULL,
    ADD COLUMN source VARCHAR(20) NOT NULL DEFAULT 'rule',
    ADD COLUMN refresh_count INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS daily_recommendation_items (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    recommendation_id INTEGER NOT NULL,
    recipe_id INTEGER NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    role VARCHAR(20) NOT NULL DEFAULT 'main',
    reason TEXT NULL,
    INDEX ix_daily_recommendation_items_recommendation_id (recommendation_id),
    INDEX ix_daily_recommendation_items_recipe_id (recipe_id),
    CONSTRAINT fk_dri_recommendation FOREIGN KEY (recommendation_id) REFERENCES daily_recommendations(id),
    CONSTRAINT fk_dri_recipe FOREIGN KEY (recipe_id) REFERENCES recipes(id)
);

INSERT INTO daily_recommendation_items (recommendation_id, recipe_id, sort_order, role)
    SELECT id, recipe_id, 0, 'staple' FROM daily_recommendations
    WHERE recipe_id IS NOT NULL;

ALTER TABLE daily_recommendations DROP COLUMN recipe_id;

CREATE TABLE IF NOT EXISTS user_ai_settings (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    method VARCHAR(20) NULL,
    provider VARCHAR(20) NULL,
    base_url VARCHAR(200) NULL,
    api_key_enc VARCHAR(500) NULL,
    model VARCHAR(100) NULL,
    daily_ai_limit_override INTEGER NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_user_ai_settings_user (user_id),
    INDEX ix_user_ai_settings_user_id (user_id),
    CONSTRAINT fk_uas_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS ai_usage_events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    scope VARCHAR(40) NOT NULL,
    method VARCHAR(20) NOT NULL,
    provider VARCHAR(20) NULL,
    status VARCHAR(20) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX ix_ai_usage_events_user_id (user_id),
    INDEX ix_ai_usage_events_created_at (created_at),
    CONSTRAINT fk_aue_user FOREIGN KEY (user_id) REFERENCES users(id)
);
