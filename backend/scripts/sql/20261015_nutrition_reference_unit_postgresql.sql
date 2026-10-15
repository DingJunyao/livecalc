-- 20261015 营养基准单位加宽（PostgreSQL，与 PostGIS 无关）
-- nutrition_data.reference_unit 不再只有 g/mL：可以是原料自定义单位名（如「袋」，
-- 由实体单位覆盖折算成克）。名称宽度与 units.name / entity_unit_overrides.unit_name 对齐（50）。
-- 加宽 VARCHAR 在 PG 上是纯元数据变更，不重写堆表。

ALTER TABLE nutrition_data
    ALTER COLUMN reference_unit TYPE VARCHAR(50);

-- 回滚（若已存在超 10 字符的值会失败，需先清理）：
-- ALTER TABLE nutrition_data
--     ALTER COLUMN reference_unit TYPE VARCHAR(10);
