-- MySQL（正式库，不使用 Alembic）：层级关系换算系数（替代/回退折算）
-- 执行前请备份数据库。
-- 语义：factor_parent_quantity [factor_parent_unit] 父 = factor_child_quantity [factor_child_unit] 子
--       NULL = 1:1（与历史行为一致）。例：1 kg 干(父) = 3 kg 鲜(子)。
-- 验证：SHOW COLUMNS FROM ingredient_hierarchies LIKE 'factor_%';
-- 回滚（确认无数据依赖后）：
--   ALTER TABLE ingredient_hierarchies
--     DROP COLUMN factor_parent_quantity,
--     DROP COLUMN factor_parent_unit,
--     DROP COLUMN factor_child_quantity,
--     DROP COLUMN factor_child_unit;

ALTER TABLE ingredient_hierarchies
    ADD COLUMN factor_parent_quantity DECIMAL(15, 6) NULL,
    ADD COLUMN factor_parent_unit VARCHAR(50) NULL,
    ADD COLUMN factor_child_quantity DECIMAL(15, 6) NULL,
    ADD COLUMN factor_child_unit VARCHAR(50) NULL;
