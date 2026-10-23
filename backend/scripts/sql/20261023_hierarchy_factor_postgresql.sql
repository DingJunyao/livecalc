-- PostgreSQL（正式库，不使用 Alembic）：层级关系换算系数（替代/回退折算）
-- 执行前请备份数据库；事务包裹，可重复执行（IF NOT EXISTS）。
-- 语义：factor_parent_quantity [factor_parent_unit] 父 = factor_child_quantity [factor_child_unit] 子
--       NULL = 1:1（与历史行为一致）。例：1 kg 干(父) = 3 kg 鲜(子)。
-- 验证：
--   SELECT column_name, data_type FROM information_schema.columns
--    WHERE table_name = 'ingredient_hierarchies' AND column_name LIKE 'factor_%';
-- 回滚（确认无数据依赖后）：
--   ALTER TABLE ingredient_hierarchies
--     DROP COLUMN IF EXISTS factor_parent_quantity,
--     DROP COLUMN IF EXISTS factor_parent_unit,
--     DROP COLUMN IF EXISTS factor_child_quantity,
--     DROP COLUMN IF EXISTS factor_child_unit;
BEGIN;

ALTER TABLE ingredient_hierarchies ADD COLUMN IF NOT EXISTS factor_parent_quantity NUMERIC(15, 6);
ALTER TABLE ingredient_hierarchies ADD COLUMN IF NOT EXISTS factor_parent_unit VARCHAR(50);
ALTER TABLE ingredient_hierarchies ADD COLUMN IF NOT EXISTS factor_child_quantity NUMERIC(15, 6);
ALTER TABLE ingredient_hierarchies ADD COLUMN IF NOT EXISTS factor_child_unit VARCHAR(50);

COMMIT;
