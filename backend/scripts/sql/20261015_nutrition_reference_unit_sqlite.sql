-- 20261015 营养基准单位加宽（SQLite）
-- nutrition_data.reference_unit 不再只有 g/mL：可以是原料自定义单位名（如「袋」，
-- 由实体单位覆盖折算成克）。名称宽度与 units.name / entity_unit_overrides.unit_name 对齐（50）。
-- SQLite 不校验 VARCHAR 长度，字段定义保持与模型一致即可（重建表代价无必要）。

-- 无需实际变更：SQLite 无长度语义。下列语句仅用于核对当前定义。
SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'nutrition_data';

-- 如确需与模型定义完全一致（旧库由早期脚本建表），可重建表：
-- 1) 新建同结构表 nutrition_data_new（reference_unit VARCHAR(50)）；
-- 2) INSERT INTO nutrition_data_new SELECT * FROM nutrition_data;
-- 3) DROP TABLE nutrition_data; ALTER TABLE nutrition_data_new RENAME TO nutrition_data;
-- 注意重建表需同步迁移索引与外键引用。

-- 回滚：无（长度语义在 SQLite 上不生效）。
