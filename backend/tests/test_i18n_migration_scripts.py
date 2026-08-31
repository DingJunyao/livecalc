from pathlib import Path


ROOT = Path(__file__).parents[1] / "scripts" / "sql"


def test_user_locale_migration_and_sql_scripts_are_present():
    revision = (
        Path(__file__).parents[1]
        / "alembic"
        / "versions"
        / "20260831_0001_add_user_locale_preferences.py"
    ).read_text(encoding="utf-8")
    assert 'revision: str = "20260831_0001"' in revision
    assert 'down_revision: Union[str, None] = "20260821_0001"' in revision
    assert 'sa.Column("locale"' in revision
    assert 'sa.Column("format_locale"' in revision

    for suffix in ("sqlite", "mysql", "postgresql"):
        sql = (ROOT / f"20260831_user_locale_preferences_{suffix}.sql").read_text(
            encoding="utf-8"
        )
        assert "locale VARCHAR(10)" in sql
        assert "format_locale VARCHAR(10)" in sql
