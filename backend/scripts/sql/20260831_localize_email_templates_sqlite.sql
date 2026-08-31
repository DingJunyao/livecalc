-- Localized email templates (SQLite)
-- Rebuild the table to remove the key autoindex introduced by the old UNIQUE key.
CREATE TABLE email_templates_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key VARCHAR(50) NOT NULL,
    locale VARCHAR(10) NOT NULL DEFAULT 'zh-CN',
    name VARCHAR(100) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    body_html TEXT NOT NULL,
    description VARCHAR(500) DEFAULT '',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_email_templates_key_locale UNIQUE (key, locale)
);

INSERT INTO email_templates_new
    (id, key, locale, name, subject, body_html, description, updated_at)
SELECT id, key, 'zh-CN', name, subject, body_html, description, updated_at
FROM email_templates;

DROP TABLE email_templates;
ALTER TABLE email_templates_new RENAME TO email_templates;
CREATE INDEX ix_email_templates_key ON email_templates (key);
