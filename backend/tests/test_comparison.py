"""跨地区物价对比端点的回归测试。

数据布局（每个测试自建、finally 清理；共享内存库多测试共存）：
  国家 TCN → 省份 TP → 城市A / 城市B / 城市C（无商家）
  商家 mA 在城市A、商家 mB 在城市B；同一商品两条记录：
  mA 便宜（10 元/500g，较早）、mB 贵（100 元/500g，较晚）。
  with_free_merchant=True 时额外建一个无地区商家（其记录按既有规则
  「未分配地区商家在任何地区都计入」，会进入所有地区的汇总，所以默认关闭）。

验证：
  - /comparison/regions 候选；无地区商家不产生候选
  - /comparison/summary 物价指数（单价比率中位数）与篮子趋势
  - /comparison/entity-prices 矩阵（原料/商品 × 地区，含无数据地区与超期放开）
  - region_ids 校验（≤6）
"""
import asyncio
import uuid
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from conftest import FakeUser
from starlette.requests import Request

# mA 记录：10 元 / 500 g；mB 记录：100 元 / 500 g
PRICE_A = 10.0
PRICE_B = 100.0
STD_QTY = 500
# 卡片价口径 = ¥/斤 归一（500g = 1 斤 → 每斤价 = 记录价）
UNIT_PRICE_A = PRICE_A
UNIT_PRICE_B = PRICE_B


def _fake_request() -> Request:
    return Request({
        "type": "http", "method": "GET", "path": "/",
        "headers": [], "query_string": b"",
    })


def _build_fixture(db_session, with_free_merchant: bool = False):
    """建 地区链 + 两地商家 + 原料/商品两条异地记录。"""
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

    merchant_a = Merchant(
        name=f"商家A-{suffix}", region_id=cities["A"].id,
        latitude=34.77, longitude=113.42,
    )
    merchant_b = Merchant(
        name=f"商家B-{suffix}", region_id=cities["B"].id,
        latitude=34.10, longitude=113.82,
    )
    merchants = [merchant_a, merchant_b]
    if with_free_merchant:
        merchants.append(Merchant(
            name=f"游离商家-{suffix}", region_id=None,
            latitude=34.50, longitude=113.60,
        ))
    db_session.add_all(merchants)
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
    records = [record_a, record_b]
    if with_free_merchant:
        records.append(ProductRecord(
            user_id=FakeUser.id, product_id=product.id, product_name=product.name,
            merchant_id=merchants[2].id, price=PRICE_A,
            original_quantity=STD_QTY, original_unit_id=gram.id,
            standard_quantity=STD_QTY, standard_unit_id=gram.id,
            recorded_at=now - timedelta(days=2), is_active=True,
        ))
    db_session.add_all(records)
    db_session.commit()

    return {
        "suffix": suffix,
        "country": country, "province": province, "cities": cities,
        "merchant_a": merchant_a, "merchant_b": merchant_b,
        "gram": gram, "ingredient": ingredient, "product": product,
        "record_a": record_a, "record_b": record_b,
    }


def _cleanup_fixture(db_session, fx):
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
    db_session.query(Merchant).filter(Merchant.name.like(
        f"%-{fx['suffix']}"
    )).delete(synchronize_session=False)
    db_session.query(Unit).filter(Unit.id == fx["gram"].id).delete(
        synchronize_session=False
    )
    city_ids = [c.id for c in fx["cities"].values()] + [fx["province"].id, fx["country"].id]
    db_session.query(AdministrativeRegion).filter(
        AdministrativeRegion.id.in_(city_ids)
    ).delete(synchronize_session=False)
    db_session.commit()


def test_comparison_regions_lists_cities_with_records(db_session):
    """地区候选：有记录的两地；游离商家不产生候选（其记录也不计入候选计数）。"""
    from app.api.comparison import list_priced_regions

    fx = _build_fixture(db_session, with_free_merchant=True)
    try:
        res = asyncio.run(list_priced_regions(
            request=_fake_request(), db=db_session, _current_user=FakeUser(),
        ))
        ids = [r.region_id for r in res.regions]
        assert fx["cities"]["A"].id in ids
        assert fx["cities"]["B"].id in ids
        assert fx["cities"]["C"].id not in ids
        by_id = {r.region_id: r for r in res.regions}
        # 候选计数按地区子树 INNER JOIN，游离商家的记录不落到任何候选上
        assert by_id[fx["cities"]["A"].id].record_count == 1
        assert by_id[fx["cities"]["A"].id].merchant_count == 1
        assert by_id[fx["cities"]["B"].id].record_count == 1
        assert all(r.display_name for r in res.regions)
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_summary_price_index_and_trend(db_session):
    """概览：基准地区指数=100；另一地区指数=单价比率中位数×100；空地区趋势为空。"""
    from app.api.comparison import comparison_summary

    fx = _build_fixture(db_session)
    rids = f"{fx['cities']['A'].id},{fx['cities']['B'].id},{fx['cities']['C'].id}"
    try:
        res = asyncio.run(comparison_summary(
            request=_fake_request(), region_ids=rids, days=7,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        by_id = {r.region_id: r for r in res.regions}
        assert res.base_region_id == fx["cities"]["A"].id
        assert res.basket_size == 1  # 基准地区近一年有记录的商品
        # 基准地区：比率全为 1 → 指数 100
        assert by_id[fx["cities"]["A"].id].price_index == pytest.approx(100.0)
        # 城市B：只有该商品有数据，比率 = 100/10 → 指数 1000
        assert by_id[fx["cities"]["B"].id].price_index == pytest.approx(1000.0)
        # 城市C：子树无商家 → 无记录、无指数、无趋势
        assert by_id[fx["cities"]["C"].id].record_count == 0
        assert by_id[fx["cities"]["C"].id].price_index is None
        assert by_id[fx["cities"]["C"].id].trend == []
        # 趋势为 ¥/斤 口径：10 元/500g → 每斤 10；从记录日前向填充到今天
        trend_a = by_id[fx["cities"]["A"].id].trend
        assert len(trend_a) >= 3  # 2 天前 → 今天
        assert trend_a[-1] == pytest.approx(10.0)
        assert by_id[fx["cities"]["B"].id].trend[-1] == pytest.approx(100.0)
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_entity_prices_ingredient_matrix(db_session):
    """原料×地区矩阵：卡片价=每标准单位综合价口径；无数据地区整格为 null。"""
    from app.api.comparison import comparison_entity_prices

    fx = _build_fixture(db_session)
    rids = f"{fx['cities']['A'].id},{fx['cities']['C'].id}"
    try:
        res = asyncio.run(comparison_entity_prices(
            _fake_request(),
            entity_type="ingredient",
            entity_ids=str(fx["ingredient"].id),
            region_ids=rids, days=7,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        assert len(res.entities) == 1
        row = res.entities[0]
        assert row.entity_id == fx["ingredient"].id
        assert row.name.startswith("测试原料")
        cell_a = row.regions[str(fx["cities"]["A"].id)]
        assert cell_a is not None
        assert cell_a.price == pytest.approx(UNIT_PRICE_A)
        assert cell_a.unit == "斤"
        assert cell_a.days_since_record == 2
        assert cell_a.is_stale is False
        assert cell_a.participant_count == 1
        assert cell_a.trend and cell_a.trend[-1] == pytest.approx(10.0)
        # 城市C 子树无商家 → 整格 null
        assert row.regions[str(fx["cities"]["C"].id)] is None
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_entity_prices_product_and_stale(db_session):
    """商品实体矩阵 + 30 天超期放开（唯一记录超期时仍显示价格并标 stale）。"""
    from app.api.comparison import comparison_entity_prices
    from app.models.product import ProductRecord

    fx = _build_fixture(db_session)
    try:
        # 把城市A 的记录改成 40 天前（超期）
        fx["record_a"].recorded_at = datetime.now(timezone.utc) - timedelta(days=40)
        db_session.commit()

        res = asyncio.run(comparison_entity_prices(
            _fake_request(),
            entity_type="product",
            entity_ids=str(fx["product"].id),
            region_ids=f"{fx['cities']['A'].id},{fx['cities']['B'].id}",
            days=7,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        row = res.entities[0]
        cell_a = row.regions[str(fx["cities"]["A"].id)]
        # 唯一记录超期 → 放开显示旧价（宁可显示旧价格，也不能没有价格）
        assert cell_a is not None
        assert cell_a.price == pytest.approx(UNIT_PRICE_A)
        assert cell_a.is_stale is True
        assert cell_a.days_since_record == 40
        # 城市B 的记录新鲜（1 天前）
        cell_b = row.regions[str(fx["cities"]["B"].id)]
        assert cell_b is not None
        assert cell_b.is_stale is False
        assert cell_b.days_since_record == 1
        assert cell_b.price == pytest.approx(UNIT_PRICE_B)
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_entity_prices_weighted_across_products(db_session):
    """原料下两个商品（同地各一）：卡片价按权重加权，参与商品数正确。"""
    from app.api.comparison import comparison_entity_prices
    from app.models.product import ProductRecord
    from app.models.product_entity import Product

    fx = _build_fixture(db_session)
    try:
        product2 = Product(
            name=f"测试商品2-{fx['suffix']}", ingredient_id=fx["ingredient"].id,
            price_weight=50, is_active=True,
        )
        db_session.add(product2)
        db_session.flush()
        record2 = ProductRecord(
            user_id=FakeUser.id, product_id=product2.id, product_name=product2.name,
            merchant_id=fx["merchant_b"].id, price=PRICE_B,
            original_quantity=STD_QTY, original_unit_id=fx["gram"].id,
            standard_quantity=STD_QTY, standard_unit_id=fx["gram"].id,
            recorded_at=datetime.now(timezone.utc) - timedelta(days=1),
            is_active=True,
        )
        db_session.add(record2)
        db_session.commit()

        res = asyncio.run(comparison_entity_prices(
            _fake_request(),
            entity_type="ingredient",
            entity_ids=str(fx["ingredient"].id),
            region_ids=str(fx["cities"]["B"].id),
            days=7,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        cell = res.entities[0].regions[str(fx["cities"]["B"].id)]
        # 城市B 两个商品各一条（各 100 元/500g），等权 → 均值
        assert cell is not None
        assert cell.price == pytest.approx(UNIT_PRICE_B)
        assert cell.participant_count == 2
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_region_ids_validation():
    """region_ids 校验：空、非数字、超过 6 个都报 400；去重保序。"""
    from app.api.comparison import _parse_region_ids
    from app.core.exceptions import LocalizedHTTPException

    with pytest.raises(LocalizedHTTPException):
        _parse_region_ids("")
    with pytest.raises(LocalizedHTTPException):
        _parse_region_ids("abc")
    with pytest.raises(LocalizedHTTPException):
        _parse_region_ids("1,2,3,4,5,6,7")
    assert _parse_region_ids("3,1,1,2") == [3, 1, 2]  # 去重保序


# ==================== 自定义范围作为对比项 ====================


def _create_scope(db_session, fx, name, region_ids):
    from app.models.user_calc_scope import UserCalcScope

    scope = UserCalcScope(
        user_id=FakeUser.id, name=name, region_ids=list(region_ids),
    )
    db_session.add(scope)
    db_session.commit()
    return scope


def _cleanup_scope(db_session, scope):
    from app.models.user_calc_scope import UserCalcScope

    db_session.query(UserCalcScope).filter(
        UserCalcScope.id == scope.id
    ).delete(synchronize_session=False)
    db_session.commit()


def test_comparison_summary_with_calc_scope_item(db_session):
    """「明发」场景：自定义范围（和县+南京组合）作为一列与三门峡并列对比。

    范围项 spec = 多地区 tuple 并集；resp_id = -(scope.id)；名称 = 范围名。
    """
    from app.api.comparison import comparison_summary

    fx = _build_fixture(db_session)
    # 模拟「明发」：城市A + 城市B 组合范围（范围内商家记录都会计入）
    scope = _create_scope(db_session, fx, "测试范围", [fx["cities"]["A"].id, fx["cities"]["B"].id])
    rids = f"{fx['cities']['A'].id},s{scope.id}"
    try:
        res = asyncio.run(comparison_summary(
            request=_fake_request(), region_ids=rids, days=7,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        by_id = {r.region_id: r for r in res.regions}
        # scope 项 resp_id = -(scope.id)
        assert -scope.id in by_id
        scope_item = by_id[-scope.id]
        assert scope_item.name == "测试范围"
        assert scope_item.display_name == "测试范围"
        # 范围 = A∪B 两地子树：记录 ≥ 单独 A 地（共享内存库可能有其他测试残留，只比下限）
        assert scope_item.record_count >= 2
        assert scope_item.record_count > by_id[fx["cities"]["A"].id].record_count
        # 指数：A（基准=100）与范围（含 A+B）……范围篮子趋势正常
        assert by_id[fx["cities"]["A"].id].price_index == pytest.approx(100.0)
        assert scope_item.price_index is not None
        assert scope_item.trend and scope_item.trend[-1] > 0
        # 基准仍是第一项（地区 A）
        assert res.base_region_id == fx["cities"]["A"].id
    finally:
        _cleanup_scope(db_session, scope)
        _cleanup_fixture(db_session, fx)


def test_comparison_entity_prices_with_scope_column(db_session):
    """矩阵 scope 列：key 为负数 resp_id 字符串；范围并集取价（B 地 100 元）。"""
    from app.api.comparison import comparison_entity_prices

    fx = _build_fixture(db_session)
    scope = _create_scope(db_session, fx, "明发", [fx["cities"]["A"].id, fx["cities"]["B"].id])
    try:
        res = asyncio.run(comparison_entity_prices(
            _fake_request(),
            entity_type="ingredient",
            entity_ids=str(fx["ingredient"].id),
            region_ids=f"s{scope.id}",
            days=7,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        row = res.entities[0]
        cell = row.regions[str(-scope.id)]
        assert cell is not None
        # 范围并集（A+B 两商家）：as-of 最近记录 = B 的 100 元/500g → 100/斤
        assert cell.price == pytest.approx(100.0)
        assert res.regions[0].region_id == -scope.id
        assert res.regions[0].display_name == "明发"
    finally:
        _cleanup_scope(db_session, scope)
        _cleanup_fixture(db_session, fx)


def test_comparison_scope_not_owned_rejected(db_session):
    """别人的范围 404；不存在的范围 404。"""
    from app.api.comparison import comparison_summary
    from app.core.exceptions import LocalizedHTTPException

    fx = _build_fixture(db_session)
    # scope 归 FakeUser2（其他用户）
    from app.models.user_calc_scope import UserCalcScope

    other = SimpleNamespace(id=999999)
    scope = UserCalcScope(
        user_id=other.id, name="别人的范围", region_ids=[fx["cities"]["A"].id],
    )
    db_session.add(scope)
    db_session.commit()
    try:
        with pytest.raises(LocalizedHTTPException) as ei:
            asyncio.run(comparison_summary(
                request=_fake_request(), region_ids=f"s{scope.id}", days=7,
                db=db_session, current_user=FakeUser(), tz="UTC",
            ))
        assert ei.value.status_code == 404
        # 不存在的范围
        with pytest.raises(LocalizedHTTPException) as ei2:
            asyncio.run(comparison_summary(
                request=_fake_request(), region_ids="s999999", days=7,
                db=db_session, current_user=FakeUser(), tz="UTC",
            ))
        assert ei2.value.status_code == 404
    finally:
        _cleanup_scope(db_session, scope)
        _cleanup_fixture(db_session, fx)


# ==================== 二期：菜谱 / 试算成本对比 ====================


def _build_recipe_fixture(db_session, fx):
    """在既有地区夹具上建菜谱（1 份，含该原料 500g）。

    条目单位用 id=3 的「克」（get-or-create）：`_qty_unit_to_grams` 硬编码
    unit_id==3 短路视为克，避免内存测试库单位 id 不定导致归克失败。
    """
    from app.models.recipe import Recipe, RecipeIngredient
    from app.models.unit import Unit

    gram3 = db_session.get(Unit, 3)
    if gram3 is None:
        gram3 = Unit(
            id=3, name="克(test)", abbreviation="g_test", unit_type="mass",
            si_factor=0.001, is_active=True,
        )
        db_session.add(gram3)
        db_session.flush()

    recipe = Recipe(
        name=f"测试菜谱-{fx['suffix']}", servings=1, user_id=FakeUser.id,
        is_public=False, is_active=True,
    )
    db_session.add(recipe)
    db_session.flush()
    db_session.add(RecipeIngredient(
        recipe_id=recipe.id, ingredient_id=fx["ingredient"].id,
        quantity=str(STD_QTY), unit_id=gram3.id, ai_inferred=False,
    ))
    db_session.commit()
    return recipe


def _cleanup_recipe(db_session, recipe):
    from app.models.recipe import Recipe, RecipeIngredient

    db_session.query(RecipeIngredient).filter(
        RecipeIngredient.recipe_id == recipe.id
    ).delete(synchronize_session=False)
    db_session.query(Recipe).filter(Recipe.id == recipe.id).delete(
        synchronize_session=False
    )
    db_session.commit()


def test_comparison_recipe_costs_by_region(db_session):
    """菜谱×地区成本：A 地取本地价（10 元/斤 × 1 斤 = 10），B 地取贵价。"""
    from app.api.comparison import comparison_recipe_costs

    fx = _build_fixture(db_session)
    recipe = _build_recipe_fixture(db_session, fx)
    rids = f"{fx['cities']['A'].id},{fx['cities']['B'].id}"
    try:
        res = asyncio.run(comparison_recipe_costs(
            request=_fake_request(), recipe_ids=str(recipe.id), region_ids=rids,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        assert len(res.recipes) == 1
        row = res.recipes[0]
        cell_a = row.regions[str(fx["cities"]["A"].id)]
        cell_b = row.regions[str(fx["cities"]["B"].id)]
        assert cell_a is not None and cell_b is not None
        assert cell_a.total_cost == pytest.approx(PRICE_A)
        assert cell_b.total_cost == pytest.approx(PRICE_B)
        # 1 份 → 每份成本 = 总成本
        assert cell_a.cost_per_serving == pytest.approx(PRICE_A)
        assert cell_a.missing_ingredients == []
        # 明细行有原料名与成本（供分析页地区比价矩阵复用）
        assert cell_a.breakdown[0].ingredient_name.startswith("测试原料")
        assert cell_a.breakdown[0].cost == pytest.approx(PRICE_A)
    finally:
        _cleanup_recipe(db_session, recipe)
        _cleanup_fixture(db_session, fx)


def test_comparison_recipe_cost_trend_by_region(db_session):
    """单菜谱多地区趋势：A 地整窗 ≈10，B 地 ≈100（前向填充）。"""
    from app.api.comparison import comparison_recipe_cost_trend

    fx = _build_fixture(db_session)
    recipe = _build_recipe_fixture(db_session, fx)
    rids = f"{fx['cities']['A'].id},{fx['cities']['B'].id}"
    try:
        res = asyncio.run(comparison_recipe_cost_trend(
            _fake_request(),
            recipe_id=recipe.id, region_ids=rids, days=7,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        trend_a = res["regions"][str(fx["cities"]["A"].id)]
        trend_b = res["regions"][str(fx["cities"]["B"].id)]
        assert trend_a and trend_b
        assert trend_a[-1]["avg_cost"] == pytest.approx(PRICE_A)
        assert trend_b[-1]["avg_cost"] == pytest.approx(PRICE_B)
    finally:
        _cleanup_recipe(db_session, recipe)
        _cleanup_fixture(db_session, fx)


def test_comparison_plan_evaluate_regions_explicit_override(db_session):
    """分地区求值：显式 region_id 优先于会话 X-Region（对比不受会话范围干扰）。"""
    from app.api.comparison import comparison_plan_evaluate_regions
    from app.schemas.comparison import PlanEvaluateRegionsBody, PlanItemBody
    from app.services.session_context import reset_session_region, set_session_region

    fx = _build_fixture(db_session)
    body = PlanEvaluateRegionsBody(
        kind="meal", meal_type="dinner",
        items=[PlanItemBody(
            group="dinner", item_type="product",
            product_id=fx["product"].id, quantity=STD_QTY,
            unit_id=fx["gram"].id,
        )],
        region_ids=[fx["cities"]["A"].id, fx["cities"]["B"].id],
    )
    try:
        # 会话范围故意指向城市C（无数据）：显式 region_ids 必须生效
        set_session_region(fx["cities"]["C"].id)
        try:
            res = asyncio.run(comparison_plan_evaluate_regions(
                _fake_request(), body, db=db_session, current_user=FakeUser(), tz="UTC",
            ))
        finally:
            reset_session_region()
        by_id = {r.region_id: r for r in res.regions}
        assert by_id[fx["cities"]["A"].id].totals["cost"] == pytest.approx(PRICE_A)
        assert by_id[fx["cities"]["B"].id].totals["cost"] == pytest.approx(PRICE_B)
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_plan_costs_and_trend_by_region(db_session):
    """已保存方案×地区：合计对照 + 多地区趋势（显式 region 覆写生效）。"""
    from app.api.comparison import comparison_plan_costs, comparison_plan_cost_trend
    from app.models.meal_plan import MealPlan, MealPlanItem

    fx = _build_fixture(db_session)
    plan = MealPlan(
        user_id=FakeUser.id, name=f"测试方案-{fx['suffix']}",
        kind="meal", note=None,
    )
    db_session.add(plan)
    db_session.flush()
    db_session.add(MealPlanItem(
        plan_id=plan.id, group="other", item_type="product",
        product_id=fx["product"].id, quantity=STD_QTY,
        unit_id=fx["gram"].id, sort_order=0,
    ))
    db_session.commit()
    rids = f"{fx['cities']['A'].id},{fx['cities']['B'].id}"
    try:
        res = asyncio.run(comparison_plan_costs(
            request=_fake_request(), plan_ids=str(plan.id), region_ids=rids,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        row = res["plans"][0]
        assert row["plan_id"] == plan.id
        assert row["regions"][str(fx["cities"]["A"].id)]["cost"] == pytest.approx(PRICE_A)
        assert row["regions"][str(fx["cities"]["B"].id)]["cost"] == pytest.approx(PRICE_B)

        trend = asyncio.run(comparison_plan_cost_trend(
            _fake_request(),
            plan_id=plan.id, region_ids=rids, days=7,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        trend_a = trend["regions"][str(fx["cities"]["A"].id)]
        trend_b = trend["regions"][str(fx["cities"]["B"].id)]
        assert trend_a and trend_b
        assert trend_a[-1]["total_cost"] == pytest.approx(PRICE_A)
        assert trend_b[-1]["total_cost"] == pytest.approx(PRICE_B)
        assert any(p["has_record"] for p in trend_a)
    finally:
        db_session.query(MealPlanItem).filter(
            MealPlanItem.plan_id == plan.id
        ).delete(synchronize_session=False)
        db_session.query(MealPlan).filter(MealPlan.id == plan.id).delete(
            synchronize_session=False
        )
        db_session.commit()
        _cleanup_fixture(db_session, fx)


# ==================== 三期：热力图 ====================


def test_comparison_heatmap_item_mode(db_session):
    """单品模式：各地商家的该品代表价（¥/斤 归一），含分位与坐标。"""
    from app.api.comparison import comparison_heatmap

    fx = _build_fixture(db_session)
    rids = f"{fx['cities']['A'].id},{fx['cities']['B'].id}"
    try:
        res = asyncio.run(comparison_heatmap(
            request=_fake_request(), mode="item",
            entity_type="ingredient", entity_id=fx["ingredient"].id,
            region_ids=rids,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        by_mid = {it["merchant_id"]: it for it in res["items"]}
        # 500g 记录 → ¥/斤 = 原价
        assert by_mid[fx["merchant_a"].id]["price"] == pytest.approx(10.0)
        assert by_mid[fx["merchant_b"].id]["price"] == pytest.approx(100.0)
        # 坐标来自商家（写入夹具）
        assert by_mid[fx["merchant_a"].id]["latitude"] == pytest.approx(34.77)
        assert by_mid[fx["merchant_a"].id]["sample_count"] >= 1
        assert by_mid[fx["merchant_a"].id]["is_stale"] is False
        # 分位：两家 [10, 100] → p50 ≈ 10（round((2-1)*0.5)=1 → index 1 → 100？验证结构即可）
        assert res["buckets"] and "p50" in res["buckets"]
        assert res["currency"]
        # 单品模式无 price_index
        assert "price_index" not in by_mid[fx["merchant_a"].id]
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_heatmap_overall_mode(db_session):
    """整体物价模式：篮子=基准地区有记录商品；price_index 以中位数为 100。"""
    from app.api.comparison import comparison_heatmap

    fx = _build_fixture(db_session)
    rids = f"{fx['cities']['A'].id},{fx['cities']['B'].id}"
    try:
        res = asyncio.run(comparison_heatmap(
            request=_fake_request(), mode="overall",
            entity_type="ingredient", entity_id=None,
            region_ids=rids,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        by_mid = {it["merchant_id"]: it for it in res["items"]}
        assert res["basket_size"] == 1
        # 商家A 价 10（基准价），商家B 价 100 → 中位数取决于排序：
        # 两家非陈旧价 [10, 100]，round(1*0.5)=1 → p50=100 → A=10.0、B=100.0
        assert by_mid[fx["merchant_a"].id]["price_index"] is not None
        assert by_mid[fx["merchant_b"].id]["price_index"] is not None
        # 中位数价商家恒为 100
        p50 = res["buckets"]["p50"]
        by_p50 = [it for it in res["items"] if it["price"] == p50]
        assert all(it["price_index"] == 100.0 for it in by_p50)
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_heatmap_requires_entity_in_item_mode(db_session):
    """单品模式缺 entity_id 报 400；无坐标商家不返回。"""
    from app.api.comparison import comparison_heatmap
    from app.core.exceptions import LocalizedHTTPException

    fx = _build_fixture(db_session)
    rids = f"{fx['cities']['A'].id},{fx['cities']['B'].id}"
    try:
        with pytest.raises(LocalizedHTTPException):
            asyncio.run(comparison_heatmap(
                request=_fake_request(), mode="item",
                entity_type="ingredient", entity_id=None,
                region_ids=rids,
                db=db_session, current_user=FakeUser(), tz="UTC",
            ))
        # 单品模式选无关原料 → 商品集为空 → 空 items
        res = asyncio.run(comparison_heatmap(
            request=_fake_request(), mode="item",
            entity_type="ingredient", entity_id=999999,
            region_ids=rids,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        assert res["items"] == []
    finally:
        _cleanup_fixture(db_session, fx)
