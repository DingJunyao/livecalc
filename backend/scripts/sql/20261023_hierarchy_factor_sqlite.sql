-- SQLite（正式库，不使用 Alembic）：层级关系换算系数（替代/回退折算）
-- 执行前请备份数据库；可重复执行（列存在时跳过由调用方判断，SQLite 无 ADD COLUMN IF NOT EXISTS）。
-- 语义：factor_parent_quantity [factor_parent_unit] 父 = factor_child_quantity [factor_child_unit] 子
--       NULL = 1:1（与历史行为一致）。例：1 kg 干(父) = 3 kg 鲜(子)。
-- 验证：PRAGMA table_info(ingredient_hierarchies);  -- 应看到 4 个 factor_* 列
-- 回滚（确认无数据依赖后）：
--   ALTER TABLE ingredient_hierarchies DROP COLUMN factor_parent_quantity;
--   ALTER TABLE ingredient_hierarchies DROP COLUMN factor_parent_unit;
--   ALTER TABLE ingredient_hierarchies DROP COLUMN factor_child_quantity;
--   ALTER TABLE ingredient_hierarchies DROP COLUMN factor_child_unit;

ALTER TABLE ingredient_hierarchies ADD COLUMN factor_parent_quantity NUMERIC(15, 6);
ALTER TABLE ingredient_hierarchies ADD COLUMN factor_parent_unit VARCHAR(50);
ALTER TABLE ingredient_hierarchies ADD COLUMN factor_child_quantity NUMERIC(15, 6);
ALTER TABLE ingredient_hierarchies ADD COLUMN factor_child_unit VARCHAR(50);
