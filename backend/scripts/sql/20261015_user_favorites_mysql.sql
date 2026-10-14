-- 20261015 user_favorites（MySQL）
-- 三类实体的收藏（原料/商品/菜谱）；商家收藏沿用 user_merchant_favorites。
-- 纯链接表：取消收藏=物理删除。entity_id 多态，不加跨表外键（软删 + 导入重排 id）。

CREATE TABLE IF NOT EXISTS user_favorites (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    entity_type VARCHAR(20) NOT NULL,
    entity_id INTEGER NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_favorites UNIQUE (user_id, entity_type, entity_id),
    INDEX ix_user_favorites_user_id (user_id),
    INDEX ix_user_favorites_entity_id (entity_id),
    CONSTRAINT fk_user_favorites_user FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 回滚：
-- DROP TABLE IF EXISTS user_favorites;
