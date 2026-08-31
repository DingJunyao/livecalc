-- User locale preferences (SQLite)
ALTER TABLE users ADD COLUMN locale VARCHAR(10);
ALTER TABLE users ADD COLUMN format_locale VARCHAR(10);
