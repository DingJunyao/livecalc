-- 20261015 修复：daily_recommendations 删 recipe_id（SQLite 续行脚本）
-- 适用状态：已执行过 20261015_recommendation_items_sqlite.sql 的 1-3 步
-- （新列已加、items 已建并回填），但第 4 步 DROP COLUMN 因表级外键约束失败
--（SQLite 的 DROP COLUMN 移不掉「FOREIGN KEY(recipe_id) REFERENCES recipes」
--  这类表级约束子句，重解析报 unknown column "recipe_id" in foreign key definition）。
--
-- 做法：标准 12 步重建法——建新表（无 recipe_id）→ 拷贝 → 删旧表 → 改名。
-- 本脚本只执行一次；重复执行会在 CREATE TABLE 处报 duplicate（可忽略）。

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

-- 验证（应无 recipe_id，行数与重建前一致）：
-- PRAGMA table_info(daily_recommendations);
-- SELECT COUNT(*) FROM daily_recommendations;
-- SELECT COUNT(*) FROM daily_recommendation_items;
