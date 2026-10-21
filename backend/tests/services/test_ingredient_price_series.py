"""原料逐日折算价序列：与菜谱成本同一降级链（direct → fallback → ...）。"""
from decimal import Decimal
from types import SimpleNamespace

from app.services import recipe_service


class _FakeDb:
    def get(self, model, ident):
        return SimpleNamespace(id=ident, name="酱油")


def test_series_uses_fallback_when_no_direct_price(monkeypatch):
    calls = {"fallback": 0}

    def _no_direct(*args, **kwargs):
        return None

    def _fallback(*args, **kwargs):
        calls["fallback"] += 1
        return Decimal("0.01"), Decimal("0.03"), Decimal("0.02"), "酱油 → 生抽"

    monkeypatch.setattr(recipe_service, "_direct_cost_range_ppg", _no_direct)
    monkeypatch.setattr(recipe_service, "_fallback_cost_range_ppg", _fallback)

    series = recipe_service.calculate_ingredient_price_series(
        _FakeDb(), 51, 1, days=2, tz="UTC",
    )

    assert len(series) == 2
    assert calls["fallback"] == 2
    for point in series:
        assert point["source"] == "fallback"
        assert point["chain"] == "酱油 → 生抽"
        assert point["avg_ppg"] == 0.02
        assert point["min_ppg"] == 0.01
        assert point["max_ppg"] == 0.03


def test_series_short_circuits_on_direct(monkeypatch):
    calls = {"fallback": 0}

    def _direct(*args, **kwargs):
        return Decimal("0.02"), Decimal("0.04"), Decimal("0.03")

    def _fallback(*args, **kwargs):
        calls["fallback"] += 1
        return Decimal("0.05"), Decimal("0.06"), Decimal("0.055"), "不应使用"

    monkeypatch.setattr(recipe_service, "_direct_cost_range_ppg", _direct)
    monkeypatch.setattr(recipe_service, "_fallback_cost_range_ppg", _fallback)

    series = recipe_service.calculate_ingredient_price_series(
        _FakeDb(), 14, 1, days=1, tz="UTC",
    )

    assert len(series) == 1
    assert series[0]["source"] == "direct"
    assert series[0]["avg_ppg"] == 0.03
    assert calls["fallback"] == 0
