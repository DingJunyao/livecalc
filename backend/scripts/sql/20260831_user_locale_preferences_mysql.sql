-- User locale preferences (MySQL)
ALTER TABLE users ADD COLUMN locale VARCHAR(10) NULL;
ALTER TABLE users ADD COLUMN format_locale VARCHAR(10) NULL;
