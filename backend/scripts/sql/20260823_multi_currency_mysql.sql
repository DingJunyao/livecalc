-- 币种字典
CREATE TABLE IF NOT EXISTS currencies (
    code VARCHAR(3) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(10),
    decimals INTEGER NOT NULL DEFAULT 2,
    is_active TINYINT(1) NOT NULL DEFAULT 1
);

-- 每日汇率快照
CREATE TABLE IF NOT EXISTS exchange_rate_snapshots (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rate_date DATE NOT NULL,
    base_currency VARCHAR(3) NOT NULL,
    rates JSON NOT NULL,
    source VARCHAR(50),
    fetched_at DATETIME,
    CONSTRAINT uq_snapshot_date_base UNIQUE (rate_date, base_currency)
);

ALTER TABLE region_unit_settings ADD COLUMN default_currency VARCHAR(3) /* 国家/地区 → 默认币种 */;

ALTER TABLE merchants ADD COLUMN region_id INTEGER REFERENCES administrative_regions(id) /* 商家地区与默认币种 */;

CREATE INDEX ix_merchants_region_id ON merchants (region_id);
ALTER TABLE merchants ADD COLUMN default_currency VARCHAR(3);

ALTER TABLE users ADD COLUMN default_currency VARCHAR(3) /* 用户默认币种与默认计算范围 */;
ALTER TABLE users ADD COLUMN default_calc_scope VARCHAR(10);

ALTER TABLE product_records ADD COLUMN user_currency VARCHAR(3) DEFAULT 'CNY' /* 价格记录：写入时用户默认币种快照 */;

-- 币种 seed
INSERT INTO currencies (code, name, symbol, decimals) VALUES
    ('CNY', '人民币', '¥', 2),
    ('USD', '美元', '$', 2),
    ('EUR', '欧元', '€', 2),
    ('GBP', '英镑', '£', 2),
    ('JPY', '日元', '¥', 0),
    ('HKD', '港币', 'HK$', 2),
    ('KRW', '韩元', '₩', 0),
    ('SGD', '新加坡元', 'S$', 2),
    ('AUD', '澳大利亚元', 'A$', 2),
    ('CAD', '加拿大元', 'C$', 2),
    ('TWD', '新台币', 'NT$', 2),
    ('THB', '泰铢', '฿', 2),
    ('MYR', '马来西亚林吉特', 'RM', 2),
    ('VND', '越南盾', '₫', 0),
    ('RUB', '俄罗斯卢布', '₽', 2);

UPDATE region_unit_settings SET default_currency = 'CNY' WHERE region_code = 'CN' AND default_currency IS NULL /* 常见国家默认币种回填 */;
UPDATE region_unit_settings SET default_currency = 'USD' WHERE region_code = 'US' AND default_currency IS NULL;
UPDATE region_unit_settings SET default_currency = 'EUR' WHERE region_code = 'DE' AND default_currency IS NULL;
UPDATE region_unit_settings SET default_currency = 'EUR' WHERE region_code = 'FR' AND default_currency IS NULL;
UPDATE region_unit_settings SET default_currency = 'GBP' WHERE region_code = 'GB' AND default_currency IS NULL;
UPDATE region_unit_settings SET default_currency = 'JPY' WHERE region_code = 'JP' AND default_currency IS NULL;