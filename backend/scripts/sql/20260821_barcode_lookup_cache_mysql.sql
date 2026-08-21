CREATE TABLE barcode_lookup_cache (
    barcode VARCHAR(50) NOT NULL,
    payload TEXT NOT NULL,
    source VARCHAR(100) NOT NULL,
    fetched_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    PRIMARY KEY (barcode),
    KEY ix_barcode_lookup_cache_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- DROP TABLE barcode_lookup_cache;
