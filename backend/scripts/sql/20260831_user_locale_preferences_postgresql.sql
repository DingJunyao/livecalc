-- User locale preferences (PostgreSQL)
ALTER TABLE users ADD COLUMN IF NOT EXISTS locale VARCHAR(10);
ALTER TABLE users ADD COLUMN IF NOT EXISTS format_locale VARCHAR(10);
