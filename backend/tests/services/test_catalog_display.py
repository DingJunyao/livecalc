from types import SimpleNamespace

from app.services.catalog_display import currency_display_name, region_display_name


def test_currency_display_name_translates_builtin_catalog():
    assert currency_display_name("USD", "美元", "en-US") == "US Dollar"
    assert currency_display_name("USD", "美元", "ar") == "دولار أمريكي"
    assert currency_display_name("USD", "My custom dollar", "ar") == "My custom dollar"


def test_region_display_name_uses_babel_for_countries_and_name_en_for_subdivisions():
    country = SimpleNamespace(level=0, iso_country="CN", name="中国", name_en=None)
    subdivision = SimpleNamespace(level=2, iso_country="CN", name="北京市", name_en="Beijing")

    assert region_display_name(country, "en-US") == "China"
    assert region_display_name(subdivision, "ar") == "Beijing"
    assert region_display_name(subdivision, "zh-CN") == "北京市"
