"""商品/原料数量关联：校验、归一化、单位折克、价格因子与序列化。

唯一入口。任何地方需要解释「1 提 = 5 包」或「3 kg 鲜 = 1 kg 干」，
都应调用本模块，不要在成本/图表/前端各写一份公式。
"""
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import Iterable, Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.exceptions import LocalizedHTTPException
from app.models.entity_quantity_link import EntityQuantityLink
from app.models.nutrition import Ingredient
from app.models.product_entity import Product


VALID_ENTITY_TYPES = {"product", "ingredient"}
MAX_LINKS_PER_ENTITY = 50
MAX_QUANTITY = Decimal("1000000")
QUANTITY_STEP = Decimal("0.000001")


# ------------------------------------------------------------------ #
#  基础工具
# ------------------------------------------------------------------ #

def _dec(value, default=None):
    if value is None:
        return default
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        return default


def _fmt_qty(value) -> str:
    q = _dec(value, Decimal("1"))
    if q == q.to_integral():
        return str(q.quantize(Decimal("1")))
    text = format(q.normalize(), "f")
    return text.rstrip("0").rstrip(".") if "." in text else text


def validate_entity_type(entity_type: str) -> str:
    if entity_type not in VALID_ENTITY_TYPES:
        raise LocalizedHTTPException(
            status_code=400,
            message="无效的实体类型：{entity_type}（只支持 product / ingredient）",
            entity_type=entity_type,
        )
    return entity_type


def get_entity(db: Session, entity_type: str, entity_id: int):
    """返回 product / ingredient ORM 对象；不存在或已软删返回 None。"""
    validate_entity_type(entity_type)
    if entity_type == "product":
        return (
            db.query(Product)
            .filter(Product.id == entity_id, Product.is_active == True)  # noqa: E712
            .first()
        )
    return (
        db.query(Ingredient)
        .filter(Ingredient.id == entity_id, Ingredient.is_active == True)  # noqa: E712
        .first()
    )


def entity_display_name(db: Session, entity_type: str, entity_id: int) -> Optional[str]:
    obj = get_entity(db, entity_type, entity_id)
    return getattr(obj, "name", None) if obj is not None else None


def get_links_for_entity(
    db: Session,
    entity_type: str,
    entity_id: int,
    *,
    include_inactive: bool = False,
) -> list[EntityQuantityLink]:
    """当前实体参与的关联（请求级缓存，写路径 flush 时自动失效）。"""
    validate_entity_type(entity_type)

    if include_inactive:
        return (
            db.query(EntityQuantityLink)
            .filter(
                or_(
                    (EntityQuantityLink.from_type == entity_type)
                    & (EntityQuantityLink.from_id == entity_id),
                    (EntityQuantityLink.to_type == entity_type)
                    & (EntityQuantityLink.to_id == entity_id),
                )
            )
            .order_by(EntityQuantityLink.id.asc())
            .all()
        )

    from app.services.lookup_cache import memoize_result

    def _build():
        return (
            db.query(EntityQuantityLink)
            .filter(
                EntityQuantityLink.is_active.is_(True),
                or_(
                    (EntityQuantityLink.from_type == entity_type)
                    & (EntityQuantityLink.from_id == entity_id),
                    (EntityQuantityLink.to_type == entity_type)
                    & (EntityQuantityLink.to_id == entity_id),
                ),
            )
            .order_by(EntityQuantityLink.id.asc())
            .all()
        )

    return memoize_result(db, "entity_quantity_links", (entity_type, entity_id), _build)


def normalize_link(
    link: EntityQuantityLink,
    entity_type: str,
    entity_id: int,
) -> Optional[dict]:
    """把存储方向归一成「当前实体视角」。

    语义：current_quantity [current_unit] current
        = other_quantity [other_unit] other
    """
    if link.from_type == entity_type and link.from_id == entity_id:
        current_type, current_id = link.from_type, link.from_id
        current_qty, current_unit = link.from_quantity, link.from_unit
        other_type, other_id = link.to_type, link.to_id
        other_qty, other_unit = link.to_quantity, link.to_unit
    elif link.to_type == entity_type and link.to_id == entity_id:
        current_type, current_id = link.to_type, link.to_id
        current_qty, current_unit = link.to_quantity, link.to_unit
        other_type, other_id = link.from_type, link.from_id
        other_qty, other_unit = link.from_quantity, link.from_unit
    else:
        return None

    q_c = _dec(current_qty, Decimal("1"))
    q_o = _dec(other_qty, Decimal("1"))
    if q_c <= 0 or q_o <= 0:
        return None
    return {
        "link": link,
        "current_type": current_type,
        "current_id": current_id,
        "current_quantity": q_c,
        "current_unit": (current_unit or "").strip(),
        "other_type": other_type,
        "other_id": other_id,
        "other_quantity": q_o,
        "other_unit": (other_unit or "").strip(),
    }


# ------------------------------------------------------------------ #
#  单位折克（核心）
# ------------------------------------------------------------------ #

def resolve_unit_grams(
    db: Session,
    entity_type: str,
    entity_id: int,
    unit_name: str,
    visited: Optional[set] = None,
) -> Optional[Decimal]:
    """1 个 `unit_name` 对应该实体多少克。

    优先级：
      1. 现有单位覆盖 / 全局单位（UnitConversionService，关闭 link 回退避免递归）；
      2. 沿实体所在关联递归：1 current = (other_qty/current_qty) other。
    解析失败返回 None，绝不按 100g 臆估。
    """
    unit_name = (unit_name or "").strip()
    if not unit_name:
        return None
    if visited is None:
        visited = set()
    key = (entity_type, entity_id, unit_name)
    if key in visited:
        return None
    visited.add(key)

    try:
        from app.services.unit_conversion_service import UnitConversionService

        result = UnitConversionService(db).convert(
            Decimal("1"), unit_name, "g",
            entity_type=entity_type, entity_id=entity_id,
            allow_links=False,
        )
        if result and result[0] is not None:
            grams = Decimal(str(result[0]))
            if grams > 0:
                return grams
    except Exception:
        pass

    for link in get_links_for_entity(db, entity_type, entity_id):
        norm = normalize_link(link, entity_type, entity_id)
        if not norm or norm["current_unit"] != unit_name:
            continue
        other_grams = resolve_unit_grams(
            db, norm["other_type"], norm["other_id"], norm["other_unit"], visited,
        )
        if other_grams is None or other_grams <= 0:
            continue
        q_c = norm["current_quantity"]
        q_o = norm["other_quantity"]
        if q_c <= 0 or q_o <= 0:
            continue
        return (q_o / q_c) * other_grams
    return None


def link_price_factor(
    grams_current: Optional[Decimal],
    quantity_current: Optional[Decimal],
    grams_other: Optional[Decimal],
    quantity_other: Optional[Decimal],
) -> Optional[Decimal]:
    """当前每克价 → 对方每克价的乘数。

    factor = (g_c × q_c) / (g_o × q_o)
    ppg_other = ppg_current × factor
    ppg_current = ppg_other / factor
    """
    g_c = _dec(grams_current)
    g_o = _dec(grams_other)
    q_c = _dec(quantity_current)
    q_o = _dec(quantity_other)
    if None in (g_c, g_o, q_c, q_o):
        return None
    if g_c <= 0 or g_o <= 0 or q_c <= 0 or q_o <= 0:
        return None
    return (g_c * q_c) / (g_o * q_o)


# ------------------------------------------------------------------ #
#  最新价（关联区展示用）
# ------------------------------------------------------------------ #

def latest_price_for_side(
    db: Session,
    entity_type: str,
    entity_id: int,
    unit_name: str,
    *,
    user_id: Optional[int] = None,
    region_id: Optional[int] = None,
) -> Optional[dict]:
    """对方实体在指定单位下的最新价（用户币种），失败返回 None。"""
    unit_name = (unit_name or "").strip()
    if not unit_name:
        return None

    if entity_type == "ingredient":
        try:
            from app.services.ingredient_price_service import get_weighted_ingredient_price

            weighted = get_weighted_ingredient_price(
                db, entity_id,
                as_of_date=datetime.now(timezone.utc),
                user_id=user_id,
                target_unit_abbr=unit_name,
                mode="recent",
                region_id=region_id,
            )
        except Exception:
            return None
        price = weighted.get("unit_price") if weighted else None
        if price is None:
            return None
        # 最新记录日：一次简单查询（列表通常只有几条关联）
        from app.models.product import ProductRecord

        latest_at = (
            db.query(ProductRecord.recorded_at)
            .join(Product, Product.id == ProductRecord.product_id)
            .filter(
                Product.ingredient_id == entity_id,
                Product.is_active == True,  # noqa: E712
                ProductRecord.is_active == True,  # noqa: E712
            )
            .order_by(ProductRecord.recorded_at.desc())
            .limit(1)
            .scalar()
        )
        from app.services.price_region import is_stale_recorded_at

        return {
            "price": float(price),
            "unit": unit_name,
            "date": latest_at.isoformat() if latest_at else None,
            "is_stale": bool(is_stale_recorded_at(latest_at)) if latest_at else False,
        }

    product = get_entity(db, "product", entity_id)
    if product is None:
        return None
    from app.models.product import ProductRecord

    record = (
        db.query(ProductRecord)
        .filter(
            ProductRecord.product_id == entity_id,
            ProductRecord.is_active == True,  # noqa: E712
        )
        .order_by(ProductRecord.recorded_at.desc())
        .first()
    )
    if record is None or record.price is None or record.original_quantity is None:
        return None
    if record.original_quantity <= 0 or record.original_unit is None:
        return None

    try:
        from app.services.price_region import record_price_in_user_currency
        from app.services.unit_conversion_service import UnitConversionService

        converted = UnitConversionService(db).convert(
            Decimal(str(record.original_quantity)),
            record.original_unit.abbreviation,
            unit_name,
            entity_type="product",
            entity_id=entity_id,
        )
        if not converted or converted[0] is None:
            return None
        qty = Decimal(str(converted[0]))
        if qty <= 0:
            return None
        price = Decimal(str(record_price_in_user_currency(record))) / qty
    except Exception:
        return None

    from app.services.price_region import is_stale_recorded_at

    return {
        "price": float(price),
        "unit": unit_name,
        "date": record.recorded_at.isoformat() if record.recorded_at else None,
        "is_stale": bool(is_stale_recorded_at(record.recorded_at)) if record.recorded_at else False,
    }


# ------------------------------------------------------------------ #
#  校验
# ------------------------------------------------------------------ #

def validate_link_payload(
    db: Session,
    payload: dict,
    *,
    exclude_id: Optional[int] = None,
) -> dict:
    """校验并归一化创建/更新 payload（失败抛 400/404）。"""
    from_type = payload.get("from_type")
    from_id = payload.get("from_id")
    to_type = payload.get("to_type")
    to_id = payload.get("to_id")
    if from_type not in VALID_ENTITY_TYPES:
        raise LocalizedHTTPException(status_code=400, message="无效的 from_type")
    if to_type not in VALID_ENTITY_TYPES:
        raise LocalizedHTTPException(status_code=400, message="无效的 to_type")
    if from_id is None or to_id is None:
        raise LocalizedHTTPException(status_code=400, message="关联两端不能为空")
    from_id = int(from_id)
    to_id = int(to_id)

    if from_type == to_type and from_id == to_id:
        raise LocalizedHTTPException(status_code=400, message="不能关联到自身")

    from_entity = get_entity(db, from_type, from_id)
    if from_entity is None:
        raise LocalizedHTTPException(status_code=404, message="当前商品/原料不存在或已删除")
    to_entity = get_entity(db, to_type, to_id)
    if to_entity is None:
        raise LocalizedHTTPException(status_code=404, message="要关联的商品/原料不存在或已删除")

    from_unit = str(payload.get("from_unit") or "").strip()
    to_unit = str(payload.get("to_unit") or "").strip()
    if not from_unit or not to_unit:
        raise LocalizedHTTPException(status_code=400, message="两边的单位都不能为空")
    if len(from_unit) > 50 or len(to_unit) > 50:
        raise LocalizedHTTPException(status_code=400, message="单位名称不能超过 50 个字符")

    from_qty = _dec(payload.get("from_quantity"), Decimal("1"))
    to_qty = _dec(payload.get("to_quantity"), Decimal("1"))
    if from_qty is None or from_qty <= 0 or to_qty is None or to_qty <= 0:
        raise LocalizedHTTPException(status_code=400, message="两边的数量都必须大于 0")
    if from_qty > MAX_QUANTITY or to_qty > MAX_QUANTITY:
        raise LocalizedHTTPException(status_code=400, message="数量过大")
    from_qty = from_qty.quantize(QUANTITY_STEP)
    to_qty = to_qty.quantize(QUANTITY_STEP)

    note = payload.get("note")
    if note is not None:
        note = str(note).strip()
        if len(note) > 200:
            raise LocalizedHTTPException(status_code=400, message="说明不能超过 200 个字符")
        if not note:
            note = None

    # 同一对实体（不分方向）只允许一条活跃关联
    existing = (
        db.query(EntityQuantityLink)
        .filter(
            EntityQuantityLink.is_active.is_(True),
            or_(
                (EntityQuantityLink.from_type == from_type)
                & (EntityQuantityLink.from_id == from_id)
                & (EntityQuantityLink.to_type == to_type)
                & (EntityQuantityLink.to_id == to_id),
                (EntityQuantityLink.from_type == to_type)
                & (EntityQuantityLink.from_id == to_id)
                & (EntityQuantityLink.to_type == from_type)
                & (EntityQuantityLink.to_id == from_id),
            ),
        )
        .first()
    )
    if existing is not None and (exclude_id is None or existing.id != exclude_id):
        raise LocalizedHTTPException(
            status_code=400,
            message="这两个对象已经有关联了，请直接编辑现有行",
        )

    # 每个实体最多 50 条活跃关联
    for entity_type, entity_id in ((from_type, from_id), (to_type, to_id)):
        count = (
            db.query(EntityQuantityLink)
            .filter(
                EntityQuantityLink.is_active.is_(True),
                or_(
                    (EntityQuantityLink.from_type == entity_type)
                    & (EntityQuantityLink.from_id == entity_id),
                    (EntityQuantityLink.to_type == entity_type)
                    & (EntityQuantityLink.to_id == entity_id),
                ),
            )
            .count()
        )
        if count >= MAX_LINKS_PER_ENTITY and exclude_id is None:
            raise LocalizedHTTPException(
                status_code=400,
                message="一个商品/原料最多关联 {max_count} 个对象",
                max_count=MAX_LINKS_PER_ENTITY,
            )

    return {
        "from_type": from_type,
        "from_id": from_id,
        "from_quantity": from_qty,
        "from_unit": from_unit,
        "to_type": to_type,
        "to_id": to_id,
        "to_quantity": to_qty,
        "to_unit": to_unit,
        "note": note,
    }


# ------------------------------------------------------------------ #
#  序列化
# ------------------------------------------------------------------ #

def format_link_sentence(
    current_name: Optional[str],
    current_quantity,
    current_unit: str,
    other_name: Optional[str],
    other_quantity,
    other_unit: str,
) -> str:
    return (
        f"{_fmt_qty(current_quantity)} {current_unit} {current_name or '—'} = "
        f"{_fmt_qty(other_quantity)} {other_unit} {other_name or '—'}"
    )


def serialize_link(
    db: Session,
    link: EntityQuantityLink,
    current_type: str,
    current_id: int,
    *,
    include_prices: bool = False,
    user_id: Optional[int] = None,
    region_id: Optional[int] = None,
    pending: bool = False,
) -> Optional[dict]:
    norm = normalize_link(link, current_type, current_id)
    if norm is None:
        return None

    current_name = entity_display_name(db, norm["current_type"], norm["current_id"])
    other_name = entity_display_name(db, norm["other_type"], norm["other_id"])
    other_obj = get_entity(db, norm["other_type"], norm["other_id"])

    g_c = resolve_unit_grams(
        db, norm["current_type"], norm["current_id"], norm["current_unit"],
    )
    g_o = resolve_unit_grams(
        db, norm["other_type"], norm["other_id"], norm["other_unit"],
    )
    factor = link_price_factor(
        g_c, norm["current_quantity"], g_o, norm["other_quantity"],
    )

    q_c = norm["current_quantity"]
    q_o = norm["other_quantity"]
    other_per_current = q_o / q_c if q_c > 0 else None
    current_per_other = q_c / q_o if q_o > 0 else None

    price_info = None
    if include_prices:
        price_info = latest_price_for_side(
            db, norm["other_type"], norm["other_id"], norm["other_unit"],
            user_id=user_id, region_id=region_id,
        )

    equivalent_current_price = None
    if price_info and other_per_current is not None:
        equivalent_current_price = float(
            Decimal(str(price_info["price"])) * other_per_current
        )
        equivalent_current_price = round(equivalent_current_price, 4)

    return {
        "id": int(link.id or 0),
        "current": {
            "type": norm["current_type"],
            "id": norm["current_id"],
            "name": current_name,
            "quantity": float(q_c),
            "unit": norm["current_unit"],
            "ingredient_id": getattr(
                get_entity(db, norm["current_type"], norm["current_id"]),
                "ingredient_id", None,
            ) if norm["current_type"] == "product" else None,
        },
        "other": {
            "type": norm["other_type"],
            "id": norm["other_id"],
            "name": other_name,
            "quantity": float(q_o),
            "unit": norm["other_unit"],
            "ingredient_id": getattr(other_obj, "ingredient_id", None)
            if norm["other_type"] == "product" else None,
        },
        "other_per_current": float(other_per_current) if other_per_current is not None else 0.0,
        "current_per_other": float(current_per_other) if current_per_other is not None else 0.0,
        "grams_per_current_unit": float(g_c) if g_c is not None else None,
        "grams_per_other_unit": float(g_o) if g_o is not None else None,
        "price_factor_current_to_other": float(factor) if factor is not None else None,
        "resolvable": bool(g_c is not None and g_o is not None),
        "note": link.note,
        "other_latest_price": price_info["price"] if price_info else None,
        "other_latest_price_unit": price_info["unit"] if price_info else None,
        "equivalent_current_price": equivalent_current_price,
        "price_date": price_info["date"] if price_info else None,
        "is_stale": bool(price_info["is_stale"]) if price_info else False,
        "pending": bool(pending),
    }


def serialize_links(
    db: Session,
    links: Iterable[EntityQuantityLink],
    current_type: str,
    current_id: int,
    *,
    include_prices: bool = False,
    user_id: Optional[int] = None,
    region_id: Optional[int] = None,
) -> list[dict]:
    rows = []
    for link in links:
        row = serialize_link(
            db, link, current_type, current_id,
            include_prices=include_prices,
            user_id=user_id, region_id=region_id,
        )
        if row is not None:
            rows.append(row)
    return rows


# ------------------------------------------------------------------ #
#  生命周期：关联变化后重算价格记录
# ------------------------------------------------------------------ #

def recompute_links_affected(db: Session, seeds: Iterable[tuple[str, int]]) -> None:
    """沿活跃关联 BFS，重算受影响商品/原料的价格记录折克。

    失败只记 warning，不阻断关联保存；之后可用
    `scripts/recompute_price_records.py` 兜底。
    """
    from app.services.price_aggregator import (
        recompute_ingredient_standard_quantities,
        recompute_product_standard_quantities,
    )

    try:
        db.flush()
    except Exception:
        pass

    products: set[int] = set()
    ingredients: set[int] = set()
    seen: set[tuple[str, int]] = set()
    queue = list(seeds)
    while queue and len(seen) < 100:
        entity_type, entity_id = queue.pop(0)
        key = (entity_type, entity_id)
        if key in seen:
            continue
        seen.add(key)
        if entity_type == "product":
            products.add(entity_id)
        elif entity_type == "ingredient":
            ingredients.add(entity_id)
        for link in get_links_for_entity(db, entity_type, entity_id):
            other = (
                (link.to_type, link.to_id)
                if (link.from_type, link.from_id) == key
                else (link.from_type, link.from_id)
            )
            if other not in seen:
                queue.append(other)

    for pid in products:
        try:
            recompute_product_standard_quantities(db, product_id=pid)
        except Exception as exc:  # pragma: no cover - 防御性兜底
            import logging

            logging.getLogger(__name__).warning(
                "关联变化后重算商品 %s 价格记录失败（关联已生效）: %s", pid, exc,
            )
    for iid in ingredients:
        try:
            recompute_ingredient_standard_quantities(db, ingredient_id=iid)
        except Exception as exc:  # pragma: no cover - 防御性兜底
            import logging

            logging.getLogger(__name__).warning(
                "关联变化后重算原料 %s 价格记录失败（关联已生效）: %s", iid, exc,
            )
