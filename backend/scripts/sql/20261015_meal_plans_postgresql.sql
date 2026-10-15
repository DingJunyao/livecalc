-- 20261015 meal_plans 试算方案（PostgreSQL，与 PostGIS 无关）

CREATE TABLE IF NOT EXISTS meal_plans (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    name VARCHAR(120) NOT NULL,
    kind VARCHAR(10) NOT NULL DEFAULT 'meal',
    note VARCHAR(200) NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER NULL,
    updated_by INTEGER NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX IF NOT EXISTS ix_meal_plans_user_id ON meal_plans (user_id);

CREATE TABLE IF NOT EXISTS meal_plan_items (
    id SERIAL PRIMARY KEY,
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
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER NULL,
    updated_by INTEGER NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_meal_plan_item_type CHECK (
        (item_type = 'recipe' AND recipe_id IS NOT NULL AND ingredient_id IS NULL AND product_id IS NULL) OR
        (item_type = 'ingredient' AND ingredient_id IS NOT NULL AND recipe_id IS NULL AND product_id IS NULL) OR
        (item_type = 'product' AND product_id IS NOT NULL AND recipe_id IS NULL AND ingredient_id IS NULL)
    )
);
CREATE INDEX IF NOT EXISTS ix_meal_plan_items_plan_id ON meal_plan_items (plan_id);

ALTER TABLE daily_recommendations ADD COLUMN IF NOT EXISTS plan_id INTEGER NULL REFERENCES meal_plans(id);
