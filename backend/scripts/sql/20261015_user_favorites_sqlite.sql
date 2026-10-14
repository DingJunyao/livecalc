-- 20261015 user_favorites（SQLite）
-- 三类实体的收藏（原料/商品/菜谱）；商家收藏沿用 user_merchant_favorites。
-- 纯链接表：取消收藏=物理删除。entity_id 多态，不加跨表外键（软删 + 导入重排 id）。

CREATE TABLE IF NOT EXISTS user_favorites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    entity_type VARCHAR(20) NOT NULL,
    entity_id INTEGER NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_favorites UNIQUE (user_id, entity_type, entity_id)
);

CREATE INDEX IF NOT EXISTS ix_user_favorites_user_id ON user_favorites (user_id);
CREATE INDEX IF NOT EXISTS ix_user_favorites_entity_id ON user_favorites (entity_id);

-- 回滚：
-- DROP TABLE IF EXISTS user_favorites;
