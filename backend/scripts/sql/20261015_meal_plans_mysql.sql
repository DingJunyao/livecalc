-- 20261015 meal_plans 试算方案（MySQL）

CREATE TABLE IF NOT EXISTS meal_plans (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    name VARCHAR(120) NOT NULL,
    kind VARCHAR(10) NOT NULL DEFAULT 'meal',
    note VARCHAR(200) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INTEGER NULL,
    updated_by INTEGER NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    INDEX ix_meal_plans_user_id (user_id),
    CONSTRAINT fk_meal_plans_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS meal_plan_items (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_id INTEGER NOT NULL,
    `group` VARCHAR(20) NOT NULL DEFAULT 'other',
    item_type VARCHAR(20) NOT NULL,
    recipe_id INTEGER NULL,
    ingredient_id INTEGER NULL,
    product_id INTEGER NULL,
    servings DECIMAL(6,2) NULL,
    quantity DECIMAL(12,4) NULL,
    unit_id INTEGER NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    note VARCHAR(200) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INTEGER NULL,
    updated_by INTEGER NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    INDEX ix_meal_plan_items_plan_id (plan_id),
    CONSTRAINT fk_mpi_plan FOREIGN KEY (plan_id) REFERENCES meal_plans(id),
    CONSTRAINT fk_mpi_recipe FOREIGN KEY (recipe_id) REFERENCES recipes(id),
    CONSTRAINT fk_mpi_ingredient FOREIGN KEY (ingredient_id) REFERENCES ingredients(id),
    CONSTRAINT fk_mpi_product FOREIGN KEY (product_id) REFERENCES products(id),
    CONSTRAINT fk_mpi_unit FOREIGN KEY (unit_id) REFERENCES units(id),
    CONSTRAINT ck_meal_plan_item_type CHECK (
        (item_type = 'recipe' AND recipe_id IS NOT NULL AND ingredient_id IS NULL AND product_id IS NULL) OR
        (item_type = 'ingredient' AND ingredient_id IS NOT NULL AND recipe_id IS NULL AND product_id IS NULL) OR
        (item_type = 'product' AND product_id IS NOT NULL AND recipe_id IS NULL AND ingredient_id IS NULL)
    )
);

ALTER TABLE daily_recommendations
    ADD COLUMN plan_id INTEGER NULL,
    ADD CONSTRAINT fk_dr_plan FOREIGN KEY (plan_id) REFERENCES meal_plans(id);
