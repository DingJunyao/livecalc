-- PostgreSQL: 商品/原料两两数量关联
CREATE TABLE IF NOT EXISTS entity_quantity_links (
    id SERIAL PRIMARY KEY,
    from_type VARCHAR(20) NOT NULL,
    from_id INTEGER NOT NULL,
    from_quantity NUMERIC(15, 6) NOT NULL DEFAULT 1,
    from_unit VARCHAR(50) NOT NULL,
    to_type VARCHAR(20) NOT NULL,
    to_id INTEGER NOT NULL,
    to_quantity NUMERIC(15, 6) NOT NULL DEFAULT 1,
    to_unit VARCHAR(50) NOT NULL,
    note VARCHAR(200),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER,
    updated_by INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT true
);
CREATE INDEX IF NOT EXISTS ix_entity_quantity_links_from_type ON entity_quantity_links (from_type);
CREATE INDEX IF NOT EXISTS ix_entity_quantity_links_to_type ON entity_quantity_links (to_type);
CREATE INDEX IF NOT EXISTS ix_entity_quantity_link_from ON entity_quantity_links (from_type, from_id);
CREATE INDEX IF NOT EXISTS ix_entity_quantity_link_to ON entity_quantity_links (to_type, to_id);
CREATE INDEX IF NOT EXISTS ix_entity_quantity_link_from_active ON entity_quantity_links (from_type, from_id, is_active);
CREATE INDEX IF NOT EXISTS ix_entity_quantity_link_to_active ON entity_quantity_links (to_type, to_id, is_active);
