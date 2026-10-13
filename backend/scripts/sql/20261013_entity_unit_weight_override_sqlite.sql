-- 20261013 entity_unit_overrides 新增 weight_unit_override_id（SQLite）
-- 语义：自定义单位的「单个重量」可以以同一实体的另一个自定义单位为量纲（嵌套）：
--   1箱 = 12 盒（weight_per_unit=12，weight_unit_override_id 指向「盒」）
--   1盒 = 220 mL（weight_per_unit=220，weight_unit_id 指向 mL）
-- 故意不加自引用外键：软删 + 导出导入重排 id，引用完整性由应用层校验。
-- SQLite 的 ADD COLUMN 不支持 IF NOT EXISTS；重复执行会报 duplicate column name，
-- 可忽略。SQLite 3.35+ 支持 DROP COLUMN 回滚。

ALTER TABLE entity_unit_overrides ADD COLUMN weight_unit_override_id INTEGER NULL;

CREATE INDEX IF NOT EXISTS ix_entity_unit_overrides_weight_unit_override_id
    ON entity_unit_overrides (weight_unit_override_id);

-- 回滚：
-- DROP INDEX IF EXISTS ix_entity_unit_overrides_weight_unit_override_id;
-- ALTER TABLE entity_unit_overrides DROP COLUMN weight_unit_override_id;
