-- 20261015 meal_plans 试算方案（SQLite）
-- 新装库由启动 create_all 自动建；存量库可手工执行（全 IF NOT EXISTS / 可重复执行）。

CREATE TABLE IF NOT EXISTS meal_plans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    name VARCHAR(120) NOT NULL,
    kind VARCHAR(10) NOT NULL DEFAULT 'meal',
    note VARCHAR(200) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER NULL,
    updated_by INTEGER NULL,
    is_active BOOLEAN NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS ix_meal_plans_user_id ON meal_plans (user_id);

CREATE TABLE IF NOT EXISTS meal_plan_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL REFERENCES meal_plans(id),
    "group" VARCHAR(20) NOT NULL DEFAULT 'other',
    item_type VARCHAR(20) NOT NULL,
    recipe_id INTEGER NULL REFERENCES recipes(id),
    ingredient_id INTEGER NULL REFERENCES ingredients(id),
    product_id INTEGER NULL REFERENCES products(id),
    servings NUMERIC(6,2) NULL,
    quantity NUMERIC(12,4) NULL,
    unit_id INTEGER NULL REFERENCES units(id),
    sort_order INTEGER NOT NULL DEFAULT 0,
    note VARCHAR(200) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER NULL,
    updated_by INTEGER NULL,
    is_active BOOLEAN NOT NULL DEFAULT 1,
    CONSTRAINT ck_meal_plan_item_type CHECK (
        (item_type = 'recipe' AND recipe_id IS NOT NULL AND ingredient_id IS NULL AND product_id IS NULL) OR
        (item_type = 'ingredient' AND ingredient_id IS NOT NULL AND recipe_id IS NULL AND product_id IS NULL) OR
        (item_type = 'product' AND product_id IS NOT NULL AND recipe_id IS NULL AND ingredient_id IS NULL)
    )
);
CREATE INDEX IF NOT EXISTS ix_meal_plan_items_plan_id ON meal_plan_items (plan_id);

-- daily_recommendations 回链方案（source='plan'）
ALTER TABLE daily_recommendations ADD COLUMN plan_id INTEGER NULL REFERENCES meal_plans(id);

-- 回滚：
-- ALTER TABLE daily_recommendations DROP COLUMN plan_id;
-- DROP TABLE meal_plan_items;
-- DROP TABLE meal_plans;
