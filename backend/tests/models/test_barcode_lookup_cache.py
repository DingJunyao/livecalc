from app.core.database import Base


def test_barcode_lookup_cache_columns():
    columns = Base.metadata.tables["barcode_lookup_cache"].columns
    assert columns["barcode"].primary_key
    assert not columns["barcode"].nullable
    assert not columns["payload"].nullable
    assert not columns["source"].nullable
    assert not columns["fetched_at"].nullable
    assert not columns["expires_at"].nullable
