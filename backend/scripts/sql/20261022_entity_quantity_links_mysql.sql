-- MySQL（正式库，不使用 Alembic）：商品/原料两两数量关联
-- 执行前请备份数据库；脚本可重复执行（表 IF NOT EXISTS）。
-- 验证：
--   SHOW COLUMNS FROM entity_quantity_links;
--   SHOW INDEX FROM entity_quantity_links;
-- 回滚（确认无数据/已备份后再执行）：
--   DROP TABLE IF EXISTS entity_quantity_links;

CREATE TABLE IF NOT EXISTS entity_quantity_links (
    id INT NOT NULL AUTO_INCREMENT,
    from_type VARCHAR(20) NOT NULL,
    from_id INT NOT NULL,
    from_quantity DECIMAL(15, 6) NOT NULL DEFAULT 1,
    from_unit VARCHAR(50) NOT NULL,
    to_type VARCHAR(20) NOT NULL,
    to_id INT NOT NULL,
    to_quantity DECIMAL(15, 6) NOT NULL DEFAULT 1,
    to_unit VARCHAR(50) NOT NULL,
    note VARCHAR(200) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT NULL,
    updated_by INT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    INDEX ix_entity_quantity_links_from_type (from_type),
    INDEX ix_entity_quantity_links_to_type (to_type),
    INDEX ix_entity_quantity_link_from (from_type, from_id),
    INDEX ix_entity_quantity_link_to (to_type, to_id),
    INDEX ix_entity_quantity_link_from_active (from_type, from_id, is_active),
    INDEX ix_entity_quantity_link_to_active (to_type, to_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
