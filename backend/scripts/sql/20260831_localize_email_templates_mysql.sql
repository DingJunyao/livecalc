-- Localized email templates (MySQL)
ALTER TABLE email_templates
    ADD COLUMN locale VARCHAR(10) NOT NULL DEFAULT 'zh-CN';

ALTER TABLE email_templates DROP INDEX `key`;

ALTER TABLE email_templates
    ADD CONSTRAINT uq_email_templates_key_locale UNIQUE (`key`, locale);
