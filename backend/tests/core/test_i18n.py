from fastapi import Request
from app.core.i18n import (
    DEFAULT_LOCALE,
    FORMAT_LOCALES,
    SUPPORTED_LOCALES,
    parse_accept_language,
    request_locale,
    set_request_locale,
    translate,
    translate_format,
)


def test_locale_constants_match_spec():
    assert SUPPORTED_LOCALES == {"zh-CN", "en-US", "ar"}
    assert FORMAT_LOCALES == {
        "zh-CN",
        "zh-TW",
        "en-US",
        "en-GB",
        "ja-JP",
        "de-DE",
        "id-ID",
        "ar-EG",
    }
    assert DEFAULT_LOCALE == "zh-CN"


def test_accept_language_is_sorted_by_quality_and_normalized():
    header = "fr-FR;q=0.5,ar;q=0.9,en-US;q=1,zh;q=0.8"
    assert parse_accept_language(header) == ["en-US", "ar", "zh-CN"]


def test_request_locale_uses_header_then_default():
    def request(header):
        return Request(scope={
            "type": "http",
            "headers": [(b"accept-language", header)],
            "state": {},
        })

    assert request_locale(request(b"fr-FR,en-US;q=0.8")) == "en-US"
    assert request_locale(request(b"fr-FR")) == DEFAULT_LOCALE

    stored = request(b"en-US")
    set_request_locale(stored, "ar")
    assert request_locale(stored) == "ar"


def test_translate_and_translate_format_use_catalogs():
    assert translate("服务器内部错误", "en-US") == "Internal server error"
    assert translate("服务器内部错误", "ar") == "خطأ داخلي في الخادم"
    assert translate("服务器内部错误", "zh-CN") == "服务器内部错误"
    assert translate_format("{field} 不存在", "en-US", field="region") == "region does not exist"
