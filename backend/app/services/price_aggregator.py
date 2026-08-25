"""价格聚合：把 ProductRecord（PRICE + PURCHASE）聚合到去标识汇总表。

汇总表不含 user_id / record_type（P2 共享转型核心：跨用户公开聚合，去标识）。
写入时（products.py create_product_record）增量调用 recompute_summary 重算对应
product×merchant 的统计；本模块只读写 ProductMerchantPriceSummary，绝不暴露用户身份。
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from sqlalchemy.orm import Session
from app.models.product import ProductRecord
from app.models.price_summary import ProductMerchantPriceSummary


def recompute_summary(db: Session, *, product_id: int, merchant_id: Optional[int]) -> None:
    """重算指定 product×merchant 的汇总行。

    聚合该 product×merchant 下所有 is_active 的 ProductRecord（PRICE + PURCHASE 一视同仁），
    不区分 user_id / record_type（去标识 + 去记录类型）。结果 upsert 进汇总表。
    merchant_id 为 None 时聚合该 product 的所有记录（无商家维度）。

    注意：汇总存的是「单位归一化单价 ¥/斤」（price × 500 / standard_quantity），
    与 nutrition.py sparkline 算法一致，确保跨单位可比。
    standard_quantity 为 0/None 时按 500（即 1 斤）兜底。
    latest-price 端点不读此汇总表，仅供未来趋势/K 线等使用。
    """
    # 拉取原始记录，在 Python 端归一化为「记录时用户币种快照」下的 ¥/斤 后再聚合
    # （pure-SQL 难以表达「standard_quantity 为 0/None 时取 500」的兜底；
    #   每条记录先按 record_price_in_user_currency 折算到用户币种，避免跨币种混算）
    q = db.query(ProductRecord).filter(
        ProductRecord.product_id == product_id,
        ProductRecord.is_active == True,  # noqa: E712
    )
    if merchant_id is not None:
        q = q.filter(ProductRecord.merchant_id == merchant_id)
    records = q.order_by(ProductRecord.recorded_at.desc()).all()

    unit_prices: list[float] = []
    recent_unit_price: Optional[float] = None
    for idx, r in enumerate(records):
        if r.price is None:
            continue
        std_qty = float(r.standard_quantity) if r.standard_quantity and float(r.standard_quantity) > 0 else 500.0
        from app.services.price_region import record_price_in_user_currency
        unit_price = float(record_price_in_user_currency(r)) * 500.0 / std_qty
        unit_prices.append(unit_price)
        # records 已按 recorded_at desc 排序，第一条有效单价即为最近价
        if idx == 0:
            recent_unit_price = unit_price

    if unit_prices:
        cnt = len(unit_prices)
        mn = min(unit_prices)
        mx = max(unit_prices)
        avg = sum(unit_prices) / cnt
    else:
        cnt = 0
        mn = mx = avg = None

    existing = db.query(ProductMerchantPriceSummary).filter_by(
        product_id=product_id, merchant_id=merchant_id
    ).first()
    if existing is None:
        existing = ProductMerchantPriceSummary(product_id=product_id, merchant_id=merchant_id)
        db.add(existing)
    existing.sample_count = cnt
    existing.min_price = mn
    existing.max_price = mx
    existing.avg_price_30d = avg
    existing.recent_price = recent_unit_price
    existing.last_updated_at = datetime.utcnow()
    db.flush()


def _recompute_summary_for_product(db: Session, *, product_id: int) -> None:
    """重算某商品下所有（product×merchant + 全局）汇总行。"""
    merchant_ids = {
        r.merchant_id
        for r in db.query(ProductRecord).filter(
            ProductRecord.product_id == product_id,
            ProductRecord.is_active == True,  # noqa: E712
        ).all()
        if r.merchant_id is not None
    }
    for mid in merchant_ids:
        recompute_summary(db, product_id=product_id, merchant_id=mid)
    recompute_summary(db, product_id=product_id, merchant_id=None)


def recompute_product_standard_quantities(db: Session, *, product_id: int) -> int:
    """按当前实体单位覆盖重算某商品价格记录的 standard_quantity / standard_unit_id。

    场景：用户为扫码新增的商品维护自定义单位（如「袋=1000g」）后，此前按默认
    100g/个 落库的价格记录仍是旧换算。本函数用最新覆盖（商品 > 原料 > 兜底）
    重新换算 original → g 并回写记录，随后刷新去标识汇总表，保证最新价/区间/
    成本计算口径一致。

    返回实际更新的记录条数；调用方负责 commit。
    """
    from app.services.unit_conversion_service import UnitConversionService
    from app.services.unit_matcher import UnitMatcher
    from app.utils.unit_converter import convert_to_standard

    records = (
        db.query(ProductRecord)
        .filter(
            ProductRecord.product_id == product_id,
            ProductRecord.is_active == True,  # noqa: E712
        )
        .all()
    )
    svc = UnitConversionService(db)
    matcher = UnitMatcher(db)
    g_unit = matcher.match_or_create_unit("g")
    changed = 0
    for r in records:
        if r.price is None or r.original_quantity is None or float(r.original_quantity) <= 0:
            continue
        original_unit = r.original_unit
        abbr = original_unit.abbreviation if original_unit else None
        if not abbr:
            continue
        result = svc.convert(
            Decimal(str(r.original_quantity)),
            abbr,
            "g",
            entity_type="product",
            entity_id=product_id,
        )
        if result is not None:
            new_sq, _ = result
            new_su = g_unit
        else:
            # 回退旧转换器（与 products.py create/update 逻辑一致）
            new_sq, su_str = convert_to_standard(r.original_quantity, abbr)
            new_su = matcher.match_or_create_unit(su_str) if su_str else None
        if new_sq is None:
            continue
        new_sq = Decimal(str(new_sq))
        new_su_id = new_su.id if new_su is not None else r.standard_unit_id
        if (
            r.standard_quantity is None
            or Decimal(str(r.standard_quantity)) != new_sq
            or r.standard_unit_id != new_su_id
        ):
            r.standard_quantity = new_sq
            r.standard_unit_id = new_su_id
            changed += 1
    # 记录换算变化后刷新汇总（即使无变化也刷新，保证汇总与当前覆盖一致）
    _recompute_summary_for_product(db, product_id=product_id)
    return changed


def recompute_ingredient_standard_quantities(db: Session, *, ingredient_id: int) -> int:
    """按当前覆盖重算某原料下所有商品的价格记录（商品覆盖 > 原料覆盖 > 兜底）。

    原料的自定义单位覆盖会影响其下商品记录（product 换算会回退到原料覆盖），
    故原料覆盖变更时需要对每个关联商品重算。返回更新总条数。
    """
    from app.models.product_entity import Product

    products = (
        db.query(Product)
        .filter(
            Product.ingredient_id == ingredient_id,
            Product.is_active == True,  # noqa: E712
        )
        .all()
    )
    total = 0
    for p in products:
        total += recompute_product_standard_quantities(db, product_id=p.id)
    return total
