"""CLDR-backed display names for built-in currency and region catalogs."""

from babel import Locale
from babel.numbers import get_currency_name

from app.services.currency_seed import CURRENCIES, CURRENCY_NAMES


_BABEL_LOCALES = {"zh-CN": "zh_CN", "en-US": "en_US", "ar": "ar"}


def currency_display_name(code: str, stored_name: str, locale: str) -> str:
    default_name = CURRENCY_NAMES.get(code, CURRENCIES.get(code, {}).get("name", code))
    if stored_name and stored_name not in (code, default_name):
        return stored_name
    try:
        return get_currency_name(code, locale=_BABEL_LOCALES[locale])
    except Exception:
        return stored_name or code


def region_display_name(region, locale: str) -> str:
    if region.level == 0 and region.iso_country:
        try:
            return Locale(_BABEL_LOCALES[locale]).territories.get(
                region.iso_country, region.name
            )
        except Exception:
            return region.name
    if locale.startswith("zh"):
        return region.name
    return region.name_en or region.name
