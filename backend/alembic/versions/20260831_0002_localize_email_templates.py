"""Localize email templates.

Revision ID: 20260831_0002
Revises: 20260831_0001
Create Date: 2026-08-31
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "20260831_0002"
down_revision: Union[str, None] = "20260831_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_SQLITE_UPGRADE = """
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
"""


_SQLITE_DOWNGRADE = """
CREATE TABLE email_templates_old (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    body_html TEXT NOT NULL,
    description VARCHAR(500) DEFAULT '',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO email_templates_old
    (id, key, name, subject, body_html, description, updated_at)
SELECT id, key, name, subject, body_html, description, updated_at
FROM email_templates
WHERE locale = 'zh-CN';
DROP TABLE email_templates;
ALTER TABLE email_templates_old RENAME TO email_templates;
"""


def upgrade() -> None:
    dialect = op.get_bind().dialect.name

    if dialect == "sqlite":
        op.execute(_SQLITE_UPGRADE)
        return

    with op.batch_alter_table("email_templates") as batch_op:
        batch_op.add_column(
            sa.Column("locale", sa.String(length=10), nullable=False, server_default="zh-CN")
        )

    if dialect == "mysql":
        op.execute("ALTER TABLE email_templates DROP INDEX `key`")
    elif dialect == "postgresql":
        op.drop_constraint("email_templates_key_key", "email_templates", type_="unique")
    else:
        raise RuntimeError(f"Unsupported email_templates dialect: {dialect}")

    with op.batch_alter_table("email_templates") as batch_op:
        batch_op.create_unique_constraint(
            "uq_email_templates_key_locale", ["key", "locale"]
        )


def downgrade() -> None:
    dialect = op.get_bind().dialect.name

    if dialect == "sqlite":
        op.execute(_SQLITE_DOWNGRADE)
        return

    op.execute("DELETE FROM email_templates WHERE locale <> 'zh-CN'")
    with op.batch_alter_table("email_templates") as batch_op:
        batch_op.drop_constraint("uq_email_templates_key_locale", type_="unique")
        batch_op.drop_column("locale")
        batch_op.create_unique_constraint(None, ["key"])
