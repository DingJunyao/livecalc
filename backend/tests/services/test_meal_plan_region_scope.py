"""试算成本按计算范围（地区子树）过滤的回归测试。

复现线上问题：用户把数据范围从「全部」缩回「城市」后，试算的成本完全不随
范围变化——根因是 meal_plan_service 三条成本链路（菜谱 / 原料 / 商品）都没有
透传 resolve_region_param 的地区过滤。修复后 evaluate 与 cost-trend 都要按
会话 X-Region 覆盖 / 用户默认计算范围过滤价格记录。

数据布局（每个测试自建、finally 清理；共享内存库多测试共存）：
  国家 TCN → 省份 TP → 城市A / 城市B / 城市C（无商家）
  商家 mA 在城市A、商家 mB 在城市B；同一商品两条记录：
  mA 便宜（10 元/500g，较早）、mB 贵（100 元/500g，较晚）。
"""
import asyncio
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from types import SimpleNamespace
from conftest import FakeUser

# mA 记录：10 元 / 500 g；mB 记录：100 元 / 500 g
PRICE_A = 10.0
PRICE_B = 100.0
STD_QTY = 500


def _build_scope_fixture(db_session):
    """建 地区链 + 两地商家 + 商品两条异地记录。返回供建条目与清理用的句柄。"""
    from app.models.administrative_region import AdministrativeRegion
    from app.models.merchant import Merchant
    from app.models.nutrition import Ingredient
    from app.models.product import ProductRecord
    from app.models.product_entity import Product
    from app.models.unit import Unit

    suffix = uuid.uuid4().hex[:8]
    country = AdministrativeRegion(
        code=f"TCN-{suffix}", name=f"测试国家-{suffix}", level=0,
        iso_country="TC", path=f"TCN{suffix}", is_active=True,
    )
    db_session.add(country)
    db_session.flush()
    province = AdministrativeRegion(
        code=f"TP-{suffix}", name=f"测试省-{suffix}", level=1,
        parent_id=country.id, path=f"{country.path}/TP{suffix}", is_active=True,
    )
    db_session.add(province)
    db_session.flush()
    cities = {}
    for key in ("A", "B", "C"):
        city = AdministrativeRegion(
            code=f"TC{key}-{suffix}", name=f"测试城市{key}-{suffix}", level=2,
            parent_id=province.id, path=f"{province.path}/TC{key}{suffix}",
            is_active=True,
        )
        db_session.add(city)
        cities[key] = city
    db_session.flush()

    merchant_a = Merchant(name=f"商家A-{suffix}", region_id=cities["A"].id)
    merchant_b = Merchant(name=f"商家B-{suffix}", region_id=cities["B"].id)
    db_session.add_all([merchant_a, merchant_b])
    db_session.flush()

    gram = Unit(
        name=f"克-{suffix}", abbreviation="g", unit_type="mass",
        si_factor=0.001, is_active=True,
    )
    ingredient = Ingredient(
        name=f"测试原料-{suffix}", ai_inferred=False, is_imported=False,
        is_merged=False, is_active=True,
    )
    db_session.add_all([gram, ingredient])
    db_session.flush()
    product = Product(
        name=f"测试商品-{suffix}", ingredient_id=ingredient.id,
        price_weight=50, is_active=True,
    )
    db_session.add(product)
    db_session.flush()

    now = datetime.now(timezone.utc)
    record_a = ProductRecord(
        user_id=FakeUser.id, product_id=product.id, product_name=product.name,
        merchant_id=merchant_a.id, price=PRICE_A,
        original_quantity=STD_QTY, original_unit_id=gram.id,
        standard_quantity=STD_QTY, standard_unit_id=gram.id,
        recorded_at=now - timedelta(days=2), is_active=True,
    )
    record_b = ProductRecord(
        user_id=FakeUser.id, product_id=product.id, product_name=product.name,
        merchant_id=merchant_b.id, price=PRICE_B,
        original_quantity=STD_QTY, original_unit_id=gram.id,
        standard_quantity=STD_QTY, standard_unit_id=gram.id,
        recorded_at=now - timedelta(days=1), is_active=True,
    )
    db_session.add_all([record_a, record_b])
    db_session.commit()

    return {
        "suffix": suffix,
        "country": country, "province": province, "cities": cities,
        "merchant_a": merchant_a, "merchant_b": merchant_b,
        "gram": gram, "ingredient": ingredient, "product": product,
        "record_a": record_a, "record_b": record_b,
    }


def _cleanup_scope_fixture(db_session, fx):
    from app.models.administrative_region import AdministrativeRegion
    from app.models.merchant import Merchant
    from app.models.nutrition import Ingredient
    from app.models.product import ProductRecord
    from app.models.product_entity import Product
    from app.models.unit import Unit

    db_session.query(ProductRecord).filter(
        ProductRecord.product_id == fx["product"].id
    ).delete(synchronize_session=False)
    db_session.query(Product).filter(Product.id == fx["product"].id).delete(
        synchronize_session=False
    )
    db_session.query(Ingredient).filter(Ingredient.id == fx["ingredient"].id).delete(
        synchronize_session=False
    )
    db_session.query(Merchant).filter(Merchant.id.in_(
        [fx["merchant_a"].id, fx["merchant_b"].id]
    )).delete(synchronize_session=False)
    db_session.query(Unit).filter(Unit.id == fx["gram"].id).delete(
        synchronize_session=False
    )
    city_ids = [c.id for c in fx["cities"].values()] + [fx["province"].id, fx["country"].id]
    db_session.query(AdministrativeRegion).filter(
        AdministrativeRegion.id.in_(city_ids)
    ).delete(synchronize_session=False)
    db_session.commit()


def _evaluate(db_session, item):
    from app.services.meal_plan_service import evaluate_items

    return asyncio.run(evaluate_items(db_session, FakeUser(), [item]))


def _with_session_region(region_id):
    """会话地区覆盖上下文（模拟 X-Region 头），用完必须 reset。"""
    from app.services.session_context import reset_session_region, set_session_region

    set_session_region(region_id)
    return reset_session_region


def test_evaluate_product_item_respects_region_scope(db_session):
    """商品条目：城市A 范围取本地记录，全部地区取最新记录（mB 的贵价）。"""
    fx = _build_scope_fixture(db_session)
    item = {
        "group": "dinner", "item_type": "product",
        "product_id": fx["product"].id, "quantity": STD_QTY,
        "unit_id": fx["gram"].id,
    }
    try:
        reset = _with_session_region(fx["cities"]["A"].id)
        try:
            cost_city_a = _evaluate(db_session, item)["items"][0]["cost"]
        finally:
            reset()

        reset = _with_session_region(fx["cities"]["B"].id)
        try:
            cost_city_b = _evaluate(db_session, item)["items"][0]["cost"]
        finally:
            reset()

        # 会话「全部地区」（显式覆盖 None）：取最新记录 = mB 的贵价
        reset = _with_session_region(None)
        try:
            cost_all = _evaluate(db_session, item)["items"][0]["cost"]
        finally:
            reset()
    finally:
        _cleanup_scope_fixture(db_session, fx)

    assert cost_city_a == pytest.approx(PRICE_A)
    assert cost_city_b == pytest.approx(PRICE_B)
    assert cost_all == pytest.approx(PRICE_B)


def test_evaluate_uses_user_default_calc_scope_without_session_override(db_session):
    """无会话覆盖时走用户默认计算范围（region=城市A + scope=city → 取本地价）。"""
    fx = _build_scope_fixture(db_session)
    item = {
        "group": "dinner", "item_type": "product",
        "product_id": fx["product"].id, "quantity": STD_QTY,
        "unit_id": fx["gram"].id,
    }

    class ScopedUser(FakeUser):
        region_id = None  # 测试内赋值为城市A id
        default_calc_scope = "city"

    ScopedUser.region_id = fx["cities"]["A"].id
    try:
        from app.services.meal_plan_service import evaluate_items

        payload = asyncio.run(evaluate_items(db_session, ScopedUser(), [item]))
        cost_default = payload["items"][0]["cost"]
    finally:
        _cleanup_scope_fixture(db_session, fx)

    assert cost_default == pytest.approx(PRICE_A)


def test_evaluate_ingredient_item_respects_region_scope(db_session):
    """原料条目：加权价只参与范围内商家的记录（单商品两条异地记录取均值口径）。"""
    fx = _build_scope_fixture(db_session)
    item = {
        "group": "dinner", "item_type": "ingredient",
        "ingredient_id": fx["ingredient"].id, "quantity": STD_QTY,
        "unit_id": fx["gram"].id,
    }
    try:
        reset = _with_session_region(fx["cities"]["A"].id)
        try:
            cost_city_a = _evaluate(db_session, item)["items"][0]["cost"]
        finally:
            reset()

        reset = _with_session_region(fx["cities"]["B"].id)
        try:
            cost_city_b = _evaluate(db_session, item)["items"][0]["cost"]
        finally:
            reset()

        reset = _with_session_region(None)
        try:
            cost_all = _evaluate(db_session, item)["items"][0]["cost"]
        finally:
            reset()
    finally:
        _cleanup_scope_fixture(db_session, fx)

    assert cost_city_a == pytest.approx(PRICE_A)
    assert cost_city_b == pytest.approx(PRICE_B)
    # 全部地区：as-of 前向填充只取最近一天（mB）的记录
    assert cost_all == pytest.approx(PRICE_B)


def test_evaluate_recipe_item_respects_region_scope(db_session):
    """菜谱条目：成本随范围内记录变化（直接商品链路透传 region_id）。"""
    from app.models.recipe import Recipe, RecipeIngredient

    fx = _build_scope_fixture(db_session)
    recipe = Recipe(
        name=f"测试菜谱-{fx['suffix']}", servings=1, user_id=FakeUser.id,
        is_public=False, is_active=True,
    )
    db_session.add(recipe)
    db_session.flush()
    db_session.add(RecipeIngredient(
        recipe_id=recipe.id, ingredient_id=fx["ingredient"].id,
        quantity=str(STD_QTY), unit_id=fx["gram"].id, ai_inferred=False,
    ))
    db_session.commit()
    item = {
        "group": "dinner", "item_type": "recipe",
        "recipe_id": recipe.id, "servings": 1,
    }
    try:
        reset = _with_session_region(fx["cities"]["A"].id)
        try:
            cost_city_a = _evaluate(db_session, item)["items"][0]["cost"]
        finally:
            reset()

        reset = _with_session_region(fx["cities"]["B"].id)
        try:
            cost_city_b = _evaluate(db_session, item)["items"][0]["cost"]
        finally:
            reset()
    finally:
        db_session.query(RecipeIngredient).filter(
            RecipeIngredient.recipe_id == recipe.id
        ).delete(synchronize_session=False)
        db_session.query(Recipe).filter(Recipe.id == recipe.id).delete(
            synchronize_session=False
        )
        _cleanup_scope_fixture(db_session, fx)

    assert cost_city_a == pytest.approx(PRICE_A)
    assert cost_city_b == pytest.approx(PRICE_B)


def test_plan_cost_trend_respects_region_scope(db_session):
    """方案走势：范围内取价；范围下无任何记录时走势归零且无记录日。"""
    fx = _build_scope_fixture(db_session)
    plan = SimpleNamespace(items=[SimpleNamespace(
        item_type="product", product_id=fx["product"].id,
        quantity=STD_QTY, unit=None,
    )])
    try:
        reset = _with_session_region(fx["cities"]["A"].id)
        try:
            from app.services.meal_plan_service import plan_cost_trend

            trend_a = plan_cost_trend(db_session, FakeUser(), plan, days=7)
        finally:
            reset()

        reset = _with_session_region(fx["cities"]["C"].id)
        try:
            from app.services.meal_plan_service import plan_cost_trend

            trend_c = plan_cost_trend(db_session, FakeUser(), plan, days=7)
        finally:
            reset()
    finally:
        _cleanup_scope_fixture(db_session, fx)

    # 城市A：整窗前向填充本地价；两条记录的 UTC 日期 has_record
    assert all(point["total_cost"] == pytest.approx(PRICE_A) for point in trend_a)
    assert any(point["has_record"] for point in trend_a)
    # 城市C 子树没有任何商家 → 无成本、无记录日
    assert all(point["total_cost"] == pytest.approx(0.0) for point in trend_c)
    assert not any(point["has_record"] for point in trend_c)
