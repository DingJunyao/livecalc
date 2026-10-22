"""原料逐日折算价序列：与菜谱成本同一降级链（direct → fallback → ...）。"""
from datetime import date, datetime
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


def test_contains_band_uses_cross_child_extremes(monkeypatch):
    """从属聚合的区间取「跨子食材极值」，平均值仍按 strength 加权。

    回归：旧实现把各子食材 min/max 再加权，子食材只有单一价时 min==max，
    区间塌缩成一条线（猪肉只有 11.85 一个值、没有区间可看）。
    """
    parent = SimpleNamespace(id=9, name="猪肉")
    child_a = SimpleNamespace(id=1, name="五花肉")
    child_b = SimpleNamespace(id=2, name="肋排")
    edges = [
        SimpleNamespace(child=child_a, child_id=1, strength=80),
        SimpleNamespace(child=child_b, child_id=2, strength=20),
    ]
    ranges = {
        1: (Decimal("0.010"), Decimal("0.012"), Decimal("0.011")),
        2: (Decimal("0.030"), Decimal("0.032"), Decimal("0.031")),
    }

    monkeypatch.setattr(
        recipe_service, "_hierarchy_edges", lambda *args, **kwargs: edges,
    )
    monkeypatch.setattr(
        recipe_service,
        "_get_child_price_per_gram_range",
        lambda db, ing, *args, **kwargs: ranges[ing.id],
    )

    mn, mx, av, chain = recipe_service._contains_cost_range_ppg(
        None, parent, 1, None, tz="UTC",
    )

    # 区间跨子食材：min 取最便宜子食材的下沿，max 取最贵子食材的上沿
    assert mn == Decimal("0.010")
    assert mx == Decimal("0.032")
    # 平均值仍是 strength 加权：(0.011*80 + 0.031*20) / 100
    assert av == Decimal("0.0150")
    assert mn <= av <= mx
    assert "五花肉" in chain and "肋排" in chain


class _FakeProductQuery:
    def __init__(self, rows):
        self._rows = rows

    def filter(self, *args, **kwargs):
        return self

    def all(self):
        return self._rows


class _FakeDbWithInfo:
    info: dict = {}

    def __init__(self, product_rows):
        self._product_rows = product_rows

    def query(self, *models):
        return _FakeProductQuery(self._product_rows)


def test_relation_chain_has_no_name_match(monkeypatch):
    """「同名商品匹配」已彻底移除。

    用户反馈：鸡胸肉（原料）不该命中别的原料下「鸡胸肉肠」的商品。
    现在降级链只有 fallback → recipe → contains；函数本身也已删除。
    """
    assert not hasattr(recipe_service, "_name_match_cost_range_ppg")

    for name in (
        "_fallback_cost_range_ppg",
        "_get_cost_from_recipe_range",
        "_contains_cost_range_ppg",
    ):
        monkeypatch.setattr(recipe_service, name, lambda *a, **k: None)

    result = recipe_service._relation_cost_range_ppg(
        _FakeDb(),
        SimpleNamespace(id=97, name="胡萝卜"),
        1,
        datetime(2026, 10, 21, 3, 0),
        tz="UTC",
    )
    assert result is None


def test_prefer_relations_when_direct_is_stale(monkeypatch):
    """直接价超期时，开启「超期优先替代/从属」应改走关系折算，并保留原直接价。

    回归：食用油有 6 月的一条直接记录（>30 天）→ 默认仍用直接价；
    开启开关后应使用从属聚合（植物油/猪油…），并带回 direct_ppg / direct_stale。
    """
    monkeypatch.setattr(
        recipe_service,
        "_direct_cost_range_ppg",
        lambda *args, **kwargs: (Decimal("0.01"), Decimal("0.01"), Decimal("0.01")),
    )
    monkeypatch.setattr(
        recipe_service,
        "_direct_latest_record_day",
        lambda *args, **kwargs: date(2026, 1, 1),
    )
    monkeypatch.setattr(
        recipe_service,
        "_relation_cost_range_ppg",
        lambda *args, **kwargs: (
            (Decimal("0.02"), Decimal("0.03"), Decimal("0.025")),
            "contains_aggregation",
            "食用油 ← 子食材(植物油, 猪油)",
        ),
    )

    # 默认（关闭）：直接价优先
    plain = recipe_service.calculate_ingredient_price_series(
        _FakeDb(), 3, 1, days=1, tz="UTC",
    )
    assert plain[0]["source"] == "direct"
    assert plain[0]["direct_stale"] is False
    assert plain[0]["direct_ppg"] is None

    # 开启：关系折算优先，并标记直接价超期
    preferred = recipe_service.calculate_ingredient_price_series(
        _FakeDb(), 3, 1, days=1, tz="UTC", prefer_relations_when_stale=True,
    )
    assert preferred[0]["source"] == "contains_aggregation"
    assert preferred[0]["chain"] == "食用油 ← 子食材(植物油, 猪油)"
    assert preferred[0]["avg_ppg"] == 0.025
    assert preferred[0]["direct_stale"] is True
    assert preferred[0]["direct_ppg"] == 0.01
