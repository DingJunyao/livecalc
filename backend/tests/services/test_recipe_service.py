import pytest
from datetime import datetime
from decimal import Decimal
from app.services.recipe_service import _get_price_records_for_date, _ppgs_to_range


def test_get_price_records_for_date():
    """测试获取指定日期的价格记录"""
    # 注意：这个测试需要数据库和测试数据
    # 在集成测试中运行，或者使用 pytest fixtures
    pass


def test_ppgs_to_range_normal():
    assert _ppgs_to_range([Decimal("0.01"), Decimal("0.03"), Decimal("0.02")]) == (
        Decimal("0.01"), Decimal("0.03"), Decimal("0.02")
    )


def test_ppgs_to_range_filters_dirty():
    # 0/负/None 不进极值
    r = _ppgs_to_range([Decimal("0"), Decimal("-1"), None, Decimal("0.05")])
    assert r == (Decimal("0.05"), Decimal("0.05"), Decimal("0.05"))


def test_ppgs_to_range_empty():
    assert _ppgs_to_range([]) is None
    assert _ppgs_to_range([Decimal("0"), None]) is None


def test_ppgs_to_range_avg_within_min_max():
    r = _ppgs_to_range([Decimal("1"), Decimal("2"), Decimal("3"), Decimal("4")])
    mn, mx, av = r
    assert mn <= av <= mx  # avg=2.5 ∈ [1,4]
