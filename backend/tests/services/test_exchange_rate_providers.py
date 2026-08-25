"""汇率 provider 解析测试（mock httpx，不发真实网络）。"""
import httpx
import pytest

from app.services.exchange_rate_providers import get_provider

# v1 /latest 风格：dict，含 rates 映射
V1_PAYLOAD = {
    "amount": 1.0,
    "base": "EUR",
    "date": "2026-08-24",
    "rates": {"AUD": 1.6287, "CNY": 7.8414, "USD": 1.08},
}

# v2 /rates 风格：按币种平铺的数组（部分币种日期滞后一天）
V2_PAYLOAD = [
    {"date": "2026-08-25", "base": "EUR", "quote": "AED", "rate": 4.2903},
    {"date": "2026-08-24", "base": "EUR", "quote": "AUD", "rate": 1.6287},
    {"date": "2026-08-25", "base": "EUR", "quote": "CNY", "rate": 7.8414},
    {"date": "2026-08-25", "base": "EUR", "quote": "USD", "rate": 1.08},
]


@pytest.fixture()
def provider():
    return get_provider("frankfurter")


def _mock_payload(monkeypatch, payload):
    class _Resp:
        def raise_for_status(self):
            pass

        def json(self):
            return payload

    monkeypatch.setattr(httpx, "get", lambda *args, **kwargs: _Resp())


def test_fetch_v1_dict_payload(provider, monkeypatch):
    _mock_payload(monkeypatch, V1_PAYLOAD)
    out = provider.fetch("https://api.frankfurter.dev", "EUR")
    assert out["base"] == "EUR"
    assert out["date"] == "2026-08-24"
    assert out["rates"] == {"AUD": 1.6287, "CNY": 7.8414, "USD": 1.08}


def test_fetch_v2_list_payload(provider, monkeypatch):
    """v2 /rates 数组响应应被转成 {base, date, rates} dict（回归：list indices 报错）。"""
    _mock_payload(monkeypatch, V2_PAYLOAD)
    out = provider.fetch("https://api.frankfurter.dev", "EUR")
    assert out["base"] == "EUR"
    # 多个日期时取最新日期
    assert out["date"] == "2026-08-25"
    assert out["rates"] == {"AED": 4.2903, "AUD": 1.6287, "CNY": 7.8414, "USD": 1.08}


def test_fetch_v2_list_trailing_slash_base_url(provider, monkeypatch):
    """base_url 带尾斜杠时也能拼接出正确 URL。"""
    captured = {}

    class _Resp:
        def raise_for_status(self):
            pass

        def json(self):
            return V2_PAYLOAD

    def fake_get(url, **kwargs):
        captured["url"] = url
        return _Resp()

    monkeypatch.setattr(httpx, "get", fake_get)
    out = provider.fetch("https://api.frankfurter.dev/", "EUR")
    assert captured["url"] == "https://api.frankfurter.dev/v2/rates?base=EUR"
    assert out["rates"]["CNY"] == 7.8414
