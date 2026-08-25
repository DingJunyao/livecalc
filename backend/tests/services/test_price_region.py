"""地区过滤与快照折算测试。"""
from decimal import Decimal
from app.services.price_region import record_price_in_user_currency

def test_record_price_factor():
    class R:
        price = Decimal("10")
        exchange_rate = Decimal("7.8")
    assert record_price_in_user_currency(R()) == Decimal("78")

def test_record_price_factor_none_is_one():
    class R:
        price = Decimal("10")
        exchange_rate = None
    assert record_price_in_user_currency(R()) == Decimal("10")
