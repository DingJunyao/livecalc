"""Locale primitives for backend internationalization."""

from __future__ import annotations

import gettext
from functools import lru_cache
from pathlib import Path

from fastapi import Request

DEFAULT_LOCALE = "zh-CN"
SUPPORTED_LOCALES = frozenset({"zh-CN", "en-US", "ar"})
FORMAT_LOCALES = frozenset(
    {
        "zh-CN",
        "zh-TW",
        "en-US",
        "en-GB",
        "ja-JP",
        "de-DE",
        "id-ID",
        "ar",
        "ar-EG",
    }
)

_EXACT_LOCALES = {
    "zh-cn": "zh-CN",
    "zh-hans-cn": "zh-CN",
    "en-us": "en-US",
    "ar": "ar",
}
_LANGUAGE_FALLBACKS = {
    "zh": "zh-CN",
    "zh-hans": "zh-CN",
    "en": "en-US",
    "ar": "ar",
}
_LOCALE_STATE_KEY = "locale"
_LOCALE_DIR = Path(__file__).resolve().parents[1] / "locales"


def normalize_locale(value: str | None) -> str | None:
    """Return a supported locale, or None when no supported match exists."""
    if value is None:
        return None

    normalized = value.strip().lower()
    if not normalized:
        return None

    locale = _EXACT_LOCALES.get(normalized)
    if locale is None and "-" not in normalized:
        locale = _LANGUAGE_FALLBACKS.get(normalized)
    return locale if locale in SUPPORTED_LOCALES else None


def parse_accept_language(value: str | None) -> list[str]:
    """Parse an Accept-Language header in quality/original-order precedence."""
    if not value:
        return []

    parsed: list[tuple[float, int, str]] = []
    for index, item in enumerate(value.split(",")):
        parts = item.split(";")
        tag = parts[0].strip()
        if not tag:
            continue

        quality = 1.0
        for parameter in parts[1:]:
            key, separator, parameter_value = parameter.strip().partition("=")
            if separator and key.strip().lower() == "q":
                try:
                    quality = float(parameter_value.strip())
                except ValueError:
                    quality = 0.0
                break

        locale = normalize_locale(tag)
        if locale is not None:
            parsed.append((quality, index, locale))

    locales: list[str] = []
    seen: set[str] = set()
    for _, _, locale in sorted(parsed, key=lambda entry: (-entry[0], entry[1])):
        if locale not in seen:
            seen.add(locale)
            locales.append(locale)
    return locales


def request_locale(request: Request) -> str:
    stored = getattr(request.state, _LOCALE_STATE_KEY, None)
    locale = normalize_locale(stored)
    if locale is not None:
        return locale

    header = request.headers.get("accept-language")
    for locale in parse_accept_language(header):
        if locale in SUPPORTED_LOCALES:
            return locale
    return DEFAULT_LOCALE


def set_request_locale(request: Request, locale: str | None) -> None:
    normalized = normalize_locale(locale)
    setattr(request.state, _LOCALE_STATE_KEY, normalized)


@lru_cache(maxsize=None)
def _translation(locale: str) -> gettext.NullTranslations:
    language = locale.replace("-", "_")
    return gettext.translation(
        "messages",
        localedir=str(_LOCALE_DIR),
        languages=[language],
        fallback=True,
    )


def translate(text: str, locale: str = DEFAULT_LOCALE) -> str:
    normalized = normalize_locale(locale) or DEFAULT_LOCALE
    return _translation(normalized).gettext(text)


def translate_format(text: str, locale: str, /, **params: object) -> str:
    return translate(text, locale).format(**params)
