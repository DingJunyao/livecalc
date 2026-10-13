-- 20261013 回填 product_records.product_name（SQLite）
-- 背景：product_records.product_name 是写入时的商品名快照列，价格列表/详情/历史/
-- 商家价格都直接读它。商品改名后快照不会自动更新（历史遗留数据里已有不一致行）。
-- 代码侧已在商品改名/合并时同步该列；本脚本用于把**存量**不一致行对齐到商品现名。
--
-- 幂等：可反复执行，第二次起影响 0 行。
-- 执行前建议先看看影响范围：
--   SELECT COUNT(*) FROM product_records pr JOIN products p ON p.id = pr.product_id
--   WHERE p.name IS NOT NULL AND pr.product_name <> p.name;

UPDATE product_records
SET product_name = (
    SELECT p.name FROM products p WHERE p.id = product_records.product_id
)
WHERE EXISTS (
    SELECT 1 FROM products p
    WHERE p.id = product_records.product_id
      AND p.name IS NOT NULL
      AND p.name <> product_records.product_name
);

-- 执行后应返回 0：
--   SELECT COUNT(*) FROM product_records pr JOIN products p ON p.id = pr.product_id
--   WHERE p.name IS NOT NULL AND pr.product_name <> p.name;
--
-- 回滚：快照列没有历史值可恢复（这正是被修正的脏数据），如需保留旧值请先备份：
--   CREATE TABLE product_records_name_backup AS
--   SELECT id, product_name FROM product_records;
