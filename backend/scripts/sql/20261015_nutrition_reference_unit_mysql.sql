-- 20261015 营养基准单位加宽（MySQL）
-- nutrition_data.reference_unit 不再只有 g/mL：可以是原料自定义单位名（如「袋」，
-- 由实体单位覆盖折算成克）。名称宽度与 units.name / entity_unit_overrides.unit_name 对齐（50）。

ALTER TABLE nutrition_data
    MODIFY COLUMN reference_unit VARCHAR(50) NOT NULL DEFAULT 'g';

-- 回滚：
-- ALTER TABLE nutrition_data
--     MODIFY COLUMN reference_unit VARCHAR(10) NOT NULL DEFAULT 'g';
