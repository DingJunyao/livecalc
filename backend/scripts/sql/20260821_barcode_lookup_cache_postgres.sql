CREATE TABLE barcode_lookup_cache (
    barcode VARCHAR(50) NOT NULL,
    payload TEXT NOT NULL,
    source VARCHAR(100) NOT NULL,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT barcode_lookup_cache_pkey PRIMARY KEY (barcode)
);

CREATE INDEX ix_barcode_lookup_cache_expires_at
    ON barcode_lookup_cache (expires_at);

-- DROP TABLE barcode_lookup_cache;
