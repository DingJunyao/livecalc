BEGIN TRANSACTION;

CREATE TABLE barcode_lookup_cache (
    barcode VARCHAR(50) NOT NULL PRIMARY KEY,
    payload TEXT NOT NULL,
    source VARCHAR(100) NOT NULL,
    fetched_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL
);

CREATE INDEX ix_barcode_lookup_cache_expires_at
    ON barcode_lookup_cache (expires_at);

COMMIT;
