from sqlalchemy.orm import Session
from typing import Dict, List, Optional, Tuple
import json
from datetime import datetime, timedelta, timezone
from app.models.recipe import Recipe, RecipeIngredient
from app.models.user import User
from app.models.product import ProductRecord
from app.models.product_entity import Product
from app.models.nutrition import Ingredient
from app.models.nutrition_data import NutritionData  # NutritionData 从 nutrition_data 导入，避免冲突
from app.models.ingredient_hierarchy import IngredientHierarchy, HierarchyRelationType
from app.services.unit_conversion_service import UnitConversionService
from app.models.unit import Unit
from decimal import Decimal
from app.utils.date_range_utils import local_date_range_to_utc_range, utc_datetime_to_local_date
import logging

logger = logging.getLogger(__name__)


def _get_price_record_with_fallback(
    db: Session,
    user_id: int,
    product_id: int = None,
    as_of_date: datetime = None,
    product_name_contains: str = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> Optional[ProductRecord]:
    """
    获取价格记录，带前向填充（Forward Fill）机制

    首先尝试查找指定日期之前的最新记录，如果找不到，则使用该食材/商品
    在整个时间段中的最早记录。这样可以避免因价格记录维护不及时导致的
    成本陡增现象。

    Args:
        db: 数据库会话
        user_id: 用户ID
        product_id: 商品ID（可选，与 product_name_contains 二选一）
        as_of_date: 指定日期（可选，如果不指定则返回最新记录）
        product_name_contains: 商品名称包含的字符串（可选，用于名称匹配）

    Returns:
        ProductRecord: 价格记录，如果找不到则返回 None
    """
    # 构建基础查询条件
    # 价格公开：成本跨用户使用公开价格计算，不再按 user_id 过滤。
    # user_id 参数仅保留以维持签名兼容。
    query = db.query(ProductRecord)

    if product_id:
        query = query.filter(ProductRecord.product_id == product_id)

    if product_name_contains:
        query = query.filter(ProductRecord.product_name.contains(product_name_contains))

    from app.services.price_region import apply_region_filter
    query = apply_region_filter(query, db, region_id)

    # 如果指定了日期，首先尝试查找该日期之前的最新记录
    if as_of_date:
        query_with_date = query.filter(ProductRecord.recorded_at <= as_of_date)
        latest_record = query_with_date.order_by(ProductRecord.recorded_at.desc()).first()

        if latest_record:
            # 找到了指定日期之前的记录，直接返回
            return latest_record

    # 如果没找到指定日期之前的记录，或者没有指定日期，则查找最早的记录
    # 这实现了前向填充（Forward Fill）机制
    earliest_record = query.order_by(ProductRecord.recorded_at.asc()).first()

    return earliest_record


def _get_price_records_with_fallback(
    db: Session,
    user_id: int,
    product_id: int,
    as_of_date: datetime,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> List[ProductRecord]:
    """
    获取前向填充日期的所有价格记录（而非仅一条）。

    先找到截至指定日期的最新记录，然后返回该记录所在日期的所有记录。
    这样可以正确处理同一天有多条价格记录的情况，通过取平均值得到更准确的成本。

    Args:
        db: 数据库会话
        user_id: 用户ID
        product_id: 商品ID
        as_of_date: 截止日期

    Returns:
        同一日期的所有价格记录列表，找不到则返回空列表
    """
    from app.services.price_region import apply_region_filter

    # 找到截至指定日期的最新记录
    latest_record = apply_region_filter(
        db.query(ProductRecord).filter(
            ProductRecord.product_id == product_id,
            ProductRecord.recorded_at <= as_of_date
        ),
        db, region_id,
    ).order_by(ProductRecord.recorded_at.desc()).first()

    if latest_record:
        # 获取同一天的所有记录（按用户本地日归属）
        fill_date = utc_datetime_to_local_date(latest_record.recorded_at, tz)
        day_start, day_end = local_date_range_to_utc_range(fill_date, fill_date, tz)
        return apply_region_filter(
            db.query(ProductRecord).filter(
                ProductRecord.product_id == product_id,
                ProductRecord.recorded_at >= day_start,
                ProductRecord.recorded_at <= day_end
            ),
            db, region_id,
        ).all()

    # 如果指定日期之前没有记录，获取所有记录中最早日期的所有记录
    earliest_record = apply_region_filter(
        db.query(ProductRecord).filter(
            ProductRecord.product_id == product_id
        ),
        db, region_id,
    ).order_by(ProductRecord.recorded_at.asc()).first()

    if earliest_record:
        fill_date = utc_datetime_to_local_date(earliest_record.recorded_at, tz)
        day_start, day_end = local_date_range_to_utc_range(fill_date, fill_date, tz)
        return apply_region_filter(
            db.query(ProductRecord).filter(
                ProductRecord.product_id == product_id,
                ProductRecord.recorded_at >= day_start,
                ProductRecord.recorded_at <= day_end
            ),
            db, region_id,
        ).all()

    return []


def _get_price_records_for_date(
    db: Session,
    user_id: int,
    ingredient_id: int,
    as_of_date: datetime,
    product_id: int = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> List[ProductRecord]:
    """
    获取某食材在指定日期的所有价格记录

    Args:
        db: 数据库会话
        user_id: 用户ID
        ingredient_id: 食材ID
        as_of_date: 指定日期
        product_id: 可选，指定商品ID，不指定则查找该食材下的第一个商品

    Returns:
        当天的所有价格记录列表
    """
    # 计算当天（用户本地日）的 UTC 起止时间
    _local_date = utc_datetime_to_local_date(as_of_date, tz)
    day_start, day_end = local_date_range_to_utc_range(_local_date, _local_date, tz)

    if product_id is not None:
        # 使用指定的商品ID查询
        product = db.query(Product).filter(
            Product.id == product_id,
            Product.is_active == True
        ).first()
    else:
        # 获取食材对应的第一个商品（兼容旧行为）
        product = db.query(Product).filter(
            Product.ingredient_id == ingredient_id,
            Product.is_active == True
        ).first()

    if not product:
        return []

    # 查询当天的所有价格记录
    from app.services.price_region import apply_region_filter
    records = apply_region_filter(
        db.query(ProductRecord).filter(
            ProductRecord.product_id == product.id,
            ProductRecord.recorded_at >= day_start,
            ProductRecord.recorded_at <= day_end
        ),
        db, region_id,
    ).all()

    return records


def _get_ingredient_fallback(db: Session, ingredient: Ingredient, user_id: int, visited: Optional[List[int]] = None, region_id: Optional[int] = None) -> Optional[tuple[Ingredient, ProductRecord, str]]:
    """
    获取食材的回退链中的第一个有价格的食材

    Args:
        db: 数据库会话
        ingredient: 食材对象
        user_id: 用户ID
        visited: 已访问的食材ID列表（避免循环）

    Returns:
        (fallback_ingredient, price_record, fallback_chain) 或 None
        - fallback_ingredient: 回退食材对象
        - price_record: 价格记录
        - fallback_chain: 回退链描述（如 "猪肉 → 里脊"）
    """
    if not ingredient:
        return None

    # 防止循环引用
    if visited is None:
        visited = []

    if ingredient.id in visited:
        return None

    visited = visited + [ingredient.id]

    # 查找所有回退源（按 fallback > substitutable 优先级，strength 降序尝试）
    # substitutable（可替代）关系也可作为价格回退源
    hierarchies = db.query(IngredientHierarchy).filter(
        IngredientHierarchy.child_id == ingredient.id,
        IngredientHierarchy.relation_type.in_([
            HierarchyRelationType.FALLBACK.value,
            HierarchyRelationType.SUBSTITUTABLE.value,
        ])
    ).order_by(IngredientHierarchy.strength.desc()).all()

    # 对于 SUBSTITUTABLE，也需要检查反向关系（parent_id == ingredient.id）
    # 因为可替代关系是双向的
    reverse_substitutes = db.query(IngredientHierarchy).filter(
        IngredientHierarchy.parent_id == ingredient.id,
        IngredientHierarchy.relation_type == HierarchyRelationType.SUBSTITUTABLE.value,
    ).order_by(IngredientHierarchy.strength.desc()).all()

    # 合并并排序：fallback 优先于 substitutable
    hierarchies.extend(reverse_substitutes)
    hierarchies.sort(key=lambda h: 0 if h.relation_type == HierarchyRelationType.FALLBACK.value else 1)

    for hierarchy in hierarchies:
        # 确定回退源食材
        # 对于反向 SUBSTITUTABLE（ingredient 是 parent），child 是回退源
        if hierarchy.parent_id == ingredient.id and hierarchy.relation_type == HierarchyRelationType.SUBSTITUTABLE.value:
            fallback_source = hierarchy.child
        else:
            fallback_source = hierarchy.parent

        if not hierarchy or not fallback_source:
            continue

        # 检查回退源是否有价格
        product = db.query(Product).filter(
            Product.ingredient_id == fallback_source.id,
            Product.is_active == True
        ).first()

        if product:
            # 查找该商品的公开价格记录（跨用户）
            from app.services.price_region import apply_region_filter
            latest_record = apply_region_filter(
                db.query(ProductRecord).filter(
                    ProductRecord.product_id == product.id
                ),
                db, region_id,
            ).order_by(ProductRecord.recorded_at.desc()).first()

            if latest_record:
                # 找到了有价格的回退食材
                fallback_chain = f"{ingredient.name} → {fallback_source.name}"
                return fallback_source, latest_record, fallback_chain

        # 如果当前回退源没有价格，继续向上查找
        result = _get_ingredient_fallback(db, fallback_source, user_id, visited, region_id=region_id)
        if result:
            fallback_ingredient, price_record, chain = result
            # 如果回退链最终回到了原始食材，跳过此回退源（避免循环链）
            if fallback_ingredient.id == ingredient.id:
                continue
            # 在回退链的开头添加当前食材
            fallback_chain = f"{ingredient.name} → {chain}"
            return fallback_ingredient, price_record, fallback_chain

    return None


def _convert_record_to_price_per_gram(
    db: Session,
    record: ProductRecord,
    ingredient_id: int
) -> Optional[Decimal]:
    """
    将价格记录转换为每克价格（元/克）

    通过 UnitConversionService 将 standard_unit_id 转换为克(unit_id=3)，
    得到标准化的每克价格，便于不同单位的子食材之间进行聚合。

    Args:
        db: 数据库会话
        record: 价格记录
        ingredient_id: 食材ID（用于单位转换的上下文）

    Returns:
        每克价格（元/克），如果转换失败则返回 None
    """
    if not record or record.price is None or record.standard_quantity is None or record.standard_quantity == 0:
        return None

    from app.services.price_region import record_price_in_user_currency
    unit_price = record_price_in_user_currency(record) / Decimal(str(record.standard_quantity))

    # 如果已经是克单位，直接返回
    if record.standard_unit_id is None or record.standard_unit_id == 3:
        return unit_price

    # 转换为克：先计算 1 个标准单位等于多少克，再用 unit_price 除以这个值
    price_unit = db.query(Unit).filter(Unit.id == record.standard_unit_id).first()
    gram_unit = db.query(Unit).filter(Unit.id == 3).first()

    if not price_unit or not gram_unit:
        return None

    ucs = UnitConversionService(db)
    converted = ucs.convert(
        Decimal("1"),
        price_unit.abbreviation,
        gram_unit.abbreviation,
        entity_type="ingredient",
        entity_id=ingredient_id,
    )
    if converted:
        grams_per_unit = Decimal(str(converted[0]))
        if grams_per_unit > 0:
            return unit_price / grams_per_unit

    return None


def _get_child_price_per_gram(
    db: Session,
    ingredient: Ingredient,
    user_id: int,
    as_of_date: datetime,
    visited: Optional[List[int]] = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> Optional[Decimal]:
    """
    获取食材的每克价格（元/克），通过所有可能的途径依次尝试：
    1. 直接商品价格
    2. FALLBACK/SUBSTITUTABLE 回退
    3. CONTAINS 子食材聚合（递归）

    Args:
        db: 数据库会话
        ingredient: 食材
        user_id: 用户ID
        as_of_date: 指定日期
        visited: 已访问的食材ID列表（防止循环）

    Returns:
        每克价格（元/克），全部失败则返回 None
    """
    if not ingredient:
        return None

    if visited is None:
        visited = []

    if ingredient.id in visited:
        return None

    visited = visited + [ingredient.id]

    # 1. 尝试直接商品
    products = db.query(Product).filter(
        Product.ingredient_id == ingredient.id,
        Product.is_active == True
    ).all()

    for p in products:
        record = _get_price_record_with_fallback(
            db=db,
            user_id=user_id,
            product_id=p.id,
            as_of_date=as_of_date,
            tz=tz,
            region_id=region_id,
        )
        if record:
            ppg = _convert_record_to_price_per_gram(db, record, ingredient.id)
            if ppg is not None:
                return ppg

    # 2. 尝试 FALLBACK/SUBSTITUTABLE 回退
    fallback_result = _get_ingredient_fallback(db, ingredient, user_id, visited, region_id=region_id)
    if fallback_result:
        fallback_ingredient, fallback_price_record, _ = fallback_result
        ppg = _convert_record_to_price_per_gram(db, fallback_price_record, fallback_ingredient.id)
        if ppg is not None:
            return ppg

    # 3. 尝试 CONTAINS 子食材聚合（递归）
    agg_result = _get_aggregated_cost_from_children(db, ingredient, user_id, as_of_date, visited, tz=tz, region_id=region_id)
    if agg_result:
        ppg, _ = agg_result
        return ppg

    return None


def _get_aggregated_cost_from_children(
    db: Session,
    ingredient: Ingredient,
    user_id: int,
    as_of_date: datetime,
    visited: Optional[List[int]] = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> Optional[tuple[Decimal, str]]:
    """
    从包含关系的子食材中聚合加权平均成本

    查找所有 CONTAINS 关系的子食材，对能获取到每克价格的子食材，
    使用 strength 作为权重进行加权平均。可递归：子食材也可通过其自身的
    子食材计算成本。

    Args:
        db: 数据库会话
        ingredient: 父食材
        user_id: 用户ID
        as_of_date: 指定日期
        visited: 已访问的食材ID列表（防止循环）

    Returns:
        (weighted_price_per_gram, aggregation_chain) 或 None
        - weighted_price_per_gram: 加权平均每克价格（元/克）
        - aggregation_chain: 聚合链描述（如 "猪肉 ← 子食材(猪五花肉,猪里脊)"）
    """
    if not ingredient:
        return None

    # 查找所有 CONTAINS 子食材（按 strength 降序排列）
    hierarchies = db.query(IngredientHierarchy).filter(
        IngredientHierarchy.parent_id == ingredient.id,
        IngredientHierarchy.relation_type == HierarchyRelationType.CONTAINS.value
    ).order_by(IngredientHierarchy.strength.desc()).all()

    if not hierarchies:
        return None

    children_prices = []  # (price_per_gram, strength, name)
    total_strength = 0

    for hierarchy in hierarchies:
        if not hierarchy or not hierarchy.child:
            continue

        child_ppg = _get_child_price_per_gram(
            db, hierarchy.child, user_id, as_of_date, visited, tz=tz,
            region_id=region_id,
        )
        if child_ppg is not None:
            strength = hierarchy.strength or 50  # 默认 strength 为 50
            children_prices.append((child_ppg, strength, hierarchy.child.name))
            total_strength += strength

    if not children_prices:
        return None

    # 加权平均
    if total_strength > 0:
        weighted_avg = sum(
            price * Decimal(str(strength)) for price, strength, _ in children_prices
        ) / Decimal(str(total_strength))
    else:
        # 如果所有 strength 为 0，退化为简单平均
        weighted_avg = sum(price for price, _, _ in children_prices) / Decimal(len(children_prices))

    # 构造聚合链描述
    child_names = ", ".join(name for _, _, name in children_prices)
    chain = f"{ingredient.name} ← 子食材({child_names})"

    return weighted_avg, chain


def _get_child_price_per_gram_range(
    db: Session,
    ingredient: Ingredient,
    user_id: int,
    as_of_date: datetime,
    visited: Optional[List[int]] = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> Optional[tuple[Decimal, Decimal, Decimal]]:
    """获取食材每克价格三档 (min_ppg, max_ppg, avg_ppg)，单位元/克。全失败返 None。

    降级链与 _get_child_price_per_gram 1:1 对齐（不含 name_match/recipe，
    否则 avg 会与既有 single 版漂移）：
    1. 直接商品
    2. FALLBACK/SUBSTITUTABLE 回退
    3. CONTAINS 子食材聚合（递归）

    direct 层三档同源：min/max/avg 全取 clean 集极值与均值（与 _direct_cost_range_ppg 一致，
    保证 min≤avg≤max）；fallback 仅单条记录，三档塌缩。
    """
    if not ingredient:
        return None
    if visited is None:
        visited = []
    if ingredient.id in visited:
        return None
    visited = visited + [ingredient.id]

    # 1. 尝试直接商品
    products = db.query(Product).filter(
        Product.ingredient_id == ingredient.id, Product.is_active == True
    ).all()
    for p in products:
        # 单数版拿代表记录（与既有 _get_child_price_per_gram 同款）
        record = _get_price_record_with_fallback(
            db=db, user_id=user_id, product_id=p.id,
            as_of_date=as_of_date, tz=tz, region_id=region_id,
        )
        if record:
            avg_ppg = _convert_record_to_price_per_gram(db, record, ingredient.id)
            # 对齐既有：convert 成功（非 None）即命中，不拦 ≤0
            if avg_ppg is not None:
                # min/max：复数版取该商品当天全部记录极值（过滤脏数据）
                recs = _get_price_records_with_fallback(
                    db, user_id, p.id, as_of_date, tz, region_id=region_id,
                )
                ppgs: list[Decimal] = []
                for r in recs or []:
                    if _is_dirty_record(r):
                        continue
                    ppgs.append(_convert_record_to_price_per_gram(db, r, ingredient.id))
                rng = _ppgs_to_range(ppgs)
                if rng is not None:
                    # 三档同源（与 _direct_cost_range_ppg 一致）：min/max/avg 全取 clean 集极值与均值，
                    # 避免「代表记录脏（price≤0）但同日有 clean 记录」时 avg<min。
                    return rng
                # 极值集空（罕见：代表记录折克成功但逐条折克全失败/全脏）
                # 三档塌缩为唯一可用代表记录
                return (avg_ppg, avg_ppg, avg_ppg)

    # 2. 尝试 FALLBACK/SUBSTITUTABLE 回退
    # _get_ingredient_fallback 不接 as_of/tz，只给单条全局最新记录
    fallback_result = _get_ingredient_fallback(db, ingredient, user_id, visited, region_id=region_id)
    if fallback_result:
        fallback_ingredient, fallback_price_record, _ = fallback_result
        avg_ppg = _convert_record_to_price_per_gram(
            db, fallback_price_record, fallback_ingredient.id
        )
        if avg_ppg is not None:
            # 既有 fallback 只给单条（无 as_of 锚点日），三档塌缩
            return (avg_ppg, avg_ppg, avg_ppg)

    # 3. 尝试 CONTAINS 子食材聚合（递归）
    agg_result = _contains_cost_range_ppg(
        db, ingredient, user_id, as_of_date, visited, tz=tz,
        region_id=region_id,
    )
    if agg_result:
        mn, mx, av, _ = agg_result
        return (mn, mx, av)

    return None


def _contains_cost_range_ppg(
    db: Session,
    ingredient: Ingredient,
    user_id: int,
    as_of_date: datetime,
    visited: Optional[List[int]] = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> Optional[tuple[Decimal, Decimal, Decimal, str]]:
    """CONTAINS 子食材按 strength 加权的三档 (min,max,avg) ppg + chain。

    与 _get_aggregated_cost_from_children 1:1 对齐：遍历 CONTAINS 子食材
    （strength 降序），每个调 _get_child_price_per_gram_range 拿 (min,max,avg)，
    按 strength 各档独立加权求和（非取极值子食材）。total_strength==0 时
    退化为简单平均（对齐既有 else 分支）。

    数学保证：每个子食材 min_i≤avg_i≤max_i，加权（凸组合）后总体
    min≤avg≤max 恒成立。avg_w 严格等于既有 weighted_avg。

    visited 透传给 _get_child_price_per_gram_range 做循环检测。
    """
    if not ingredient:
        return None

    hierarchies = db.query(IngredientHierarchy).filter(
        IngredientHierarchy.parent_id == ingredient.id,
        IngredientHierarchy.relation_type == HierarchyRelationType.CONTAINS.value
    ).order_by(IngredientHierarchy.strength.desc()).all()
    if not hierarchies:
        return None

    # (cmin, cmax, cavg, strength, name)
    children_ranges: list[tuple[Decimal, Decimal, Decimal, int, str]] = []
    total_strength = 0

    for hierarchy in hierarchies:
        if not hierarchy or not hierarchy.child:
            continue
        child_rng = _get_child_price_per_gram_range(
            db, hierarchy.child, user_id, as_of_date, visited, tz=tz,
            region_id=region_id,
        )
        if child_rng is not None:
            cmin, cmax, cavg = child_rng
            strength = hierarchy.strength or 50  # 默认 strength 为 50，对齐既有
            children_ranges.append((cmin, cmax, cavg, strength, hierarchy.child.name))
            total_strength += strength

    if not children_ranges:
        return None

    # 各档独立加权（凸组合：Σstrength_i/Σstrength = 1）
    if total_strength > 0:
        denom = Decimal(str(total_strength))
        min_w = sum(cmin * Decimal(str(s)) for cmin, _, _, s, _ in children_ranges) / denom
        max_w = sum(cmax * Decimal(str(s)) for _, cmax, _, s, _ in children_ranges) / denom
        avg_w = sum(cavg * Decimal(str(s)) for _, _, cavg, s, _ in children_ranges) / denom
    else:
        # 全 strength=0 退化为简单平均（对齐既有 else 分支）
        n = Decimal(len(children_ranges))
        min_w = sum(cmin for cmin, _, _, _, _ in children_ranges) / n
        max_w = sum(cmax for _, cmax, _, _, _ in children_ranges) / n
        avg_w = sum(cavg for _, _, cavg, _, _ in children_ranges) / n

    child_names = ", ".join(name for _, _, _, _, name in children_ranges)
    chain = f"{ingredient.name} ← 子食材({child_names})"
    return (min_w, max_w, avg_w, chain)


def _serving_weight_to_grams(db: Session, ingredient: Ingredient) -> Optional[Decimal]:
    """将原料的成品基准量 serving_weight 折算为克。无法转换返回 None。"""
    if not ingredient or ingredient.serving_weight is None:
        return None
    sw = Decimal(str(ingredient.serving_weight))
    if sw <= 0:
        return None
    unit_id = ingredient.serving_weight_unit_id
    # 已是克（unit_id=3）或无单位：直接视为克
    if unit_id is None or unit_id == 3:
        return sw
    unit = db.query(Unit).filter(Unit.id == unit_id).first()
    gram_unit = db.query(Unit).filter(Unit.id == 3).first()
    if not unit or not gram_unit:
        return None
    ucs = UnitConversionService(db)
    converted = ucs.convert(
        sw,
        unit.abbreviation,
        gram_unit.abbreviation,
        entity_type="ingredient",
        entity_id=ingredient.id,
    )
    if converted:
        grams = Decimal(str(converted[0]))
        return grams if grams > 0 else None
    return None


def _get_cost_from_recipe(
    db: Session,
    ingredient: Ingredient,
    user_id: int,
    as_of_date: datetime,
    visited: Optional[set] = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> Optional[tuple[Decimal, "Recipe", str]]:
    """
    从制作菜谱推导原料的每克成本（半成品成本传递）。

    查找把该原料当成品(result_ingredient_id)的菜谱，递归计算其成本，
    再用「份 × 每份重」桥接为每克单价。

    Returns:
        (price_per_gram, making_recipe, chain) 或 None
        - price_per_gram: 元/克
        - making_recipe: 制作菜谱对象
        - chain: 链描述（如 "米饭 ← 制作自「电饭煲蒸米饭」"）
    """
    if not ingredient:
        return None
    # 反查制作菜谱（哪个菜谱把我当成品产出）
    recipe = db.query(Recipe).filter(
        Recipe.result_ingredient_id == ingredient.id,
        Recipe.is_active == True,
    ).first()
    if not recipe:
        return None
    # 循环检测：链上已见过的菜谱直接放弃
    if visited is None:
        visited = set()
    if recipe.id in visited:
        return None
    # 份重桥接 → 总产量(克)
    sw_g = _serving_weight_to_grams(db, ingredient)
    if sw_g is None or sw_g <= 0:
        return None
    servings = recipe.servings or 1
    if servings <= 0:
        return None
    # 递归算制作菜谱成本（支持套娃），把 recipe.id 纳入 visited 透传
    recipe_cost = calculate_recipe_cost_as_of(
        recipe.id, user_id, as_of_date, db, visited=visited | {recipe.id}, tz=tz,
        region_id=region_id,
    )
    if not recipe_cost:
        return None
    total_cost = Decimal(str(recipe_cost.get("total_cost") or 0))
    total_yield_g = Decimal(str(servings)) * sw_g
    if total_yield_g <= 0:
        return None
    ppg = total_cost / total_yield_g
    chain = f"{ingredient.name} ← 制作自「{recipe.name}」"
    return ppg, recipe, chain


def _get_cost_from_recipe_range(
    db: Session,
    ingredient: Ingredient,
    user_id: int,
    as_of_date: datetime,
    visited: Optional[List[int]] = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> Optional[tuple[Decimal, Decimal, Decimal, str]]:
    """半成品推导的 (min_ppg, max_ppg, avg_ppg, chain)，单位元/克。

    无制作菜谱/循环返 None。与 _get_cost_from_recipe 同骨架（1:1 对齐）：
    找制作菜谱 → visited 循环检测 → servings × serving_weight 算产量克 →
    递归 calculate_recipe_cost_range_as_of 拿三档总成本 → ÷ 产量克 得每克三档单价。

    visited 为菜谱 ID 列表（区间版专用；单点版 _get_cost_from_recipe 用 set，
    因 calculate_recipe_cost_as_of 的 visited 是 set）。
    """
    if not ingredient:
        return None
    # 反查制作菜谱（哪个菜谱把我当成品产出）
    recipe = db.query(Recipe).filter(
        Recipe.result_ingredient_id == ingredient.id,
        Recipe.is_active == True,
    ).first()
    if not recipe:
        return None
    # 循环检测：链上已见过的菜谱直接放弃
    if visited is None:
        visited = []
    if recipe.id in visited:
        return None
    # 份重桥接 → 总产量(克)
    sw_g = _serving_weight_to_grams(db, ingredient)
    if sw_g is None or sw_g <= 0:
        return None
    servings = recipe.servings or 1
    if servings <= 0:
        return None
    # 递归算制作菜谱三档成本（支持套娃），visited 透传；
    # calculate_recipe_cost_range_as_of 入口会自己把 recipe.id 加进 visited
    rng = calculate_recipe_cost_range_as_of(
        db, recipe.id, user_id, as_of_date, visited=visited, tz=tz,
        region_id=region_id,
    )
    if not rng:
        return None
    total_yield_g = Decimal(str(servings)) * sw_g
    if total_yield_g <= 0:
        return None
    mn_ppg = Decimal(str(rng.get("min_cost") or 0)) / total_yield_g
    mx_ppg = Decimal(str(rng.get("max_cost") or 0)) / total_yield_g
    av_ppg = Decimal(str(rng.get("avg_cost") or 0)) / total_yield_g
    chain = f"{ingredient.name} ← 制作自「{recipe.name}」"
    return mn_ppg, mx_ppg, av_ppg, chain


def _get_ingredient_nutrition(
    db: Session,
    ingredient: Ingredient,
    visited: Optional[List[int]] = None
) -> Optional[tuple[Ingredient, NutritionData, str]]:
    """
    获取食材的回退链中的第一个有营养数据的食材

    Args:
        db: 数据库会话
        ingredient: 食材对象
        visited: 已访问的食材ID列表（避免循环）

    Returns:
        (fallback_ingredient, nutrition_data, fallback_chain) 或 None
        - fallback_ingredient: 回退食材对象
        - nutrition_data: 营养数据
        - fallback_chain: 回退链描述（如 "猪肉 → 里脊"）
    """
    if not ingredient:
        return None

    # 防止循环引用
    if visited is None:
        visited = []

    if ingredient.id in visited:
        return None

    visited = visited + [ingredient.id]

    # 查找所有回退源（按 fallback > substitutable 优先级，strength 降序尝试）
    # substitutable（可替代）关系也可作为营养回退源
    hierarchies = db.query(IngredientHierarchy).filter(
        IngredientHierarchy.child_id == ingredient.id,
        IngredientHierarchy.relation_type.in_([
            HierarchyRelationType.FALLBACK.value,
            HierarchyRelationType.SUBSTITUTABLE.value,
        ])
    ).order_by(IngredientHierarchy.strength.desc()).all()

    # 对于 SUBSTITUTABLE，也需要检查反向关系（parent_id == ingredient.id）
    reverse_substitutes = db.query(IngredientHierarchy).filter(
        IngredientHierarchy.parent_id == ingredient.id,
        IngredientHierarchy.relation_type == HierarchyRelationType.SUBSTITUTABLE.value,
    ).order_by(IngredientHierarchy.strength.desc()).all()

    # 合并并排序：fallback 优先于 substitutable
    hierarchies.extend(reverse_substitutes)
    hierarchies.sort(key=lambda h: 0 if h.relation_type == HierarchyRelationType.FALLBACK.value else 1)

    for hierarchy in hierarchies:
        # 确定回退源食材
        if hierarchy.parent_id == ingredient.id and hierarchy.relation_type == HierarchyRelationType.SUBSTITUTABLE.value:
            fallback_source = hierarchy.child
        else:
            fallback_source = hierarchy.parent

        if not hierarchy or not fallback_source:
            continue

        # 检查回退源是否有营养数据
        nutrition = db.query(NutritionData).filter(
            NutritionData.ingredient_id == fallback_source.id
        ).order_by(NutritionData.id.desc()).first()

        if nutrition:
            # 找到了有营养数据的回退食材
            fallback_chain = f"{ingredient.name} → {fallback_source.name}"
            return fallback_source, nutrition, fallback_chain

        # 如果当前回退源没有营养数据，继续向上查找
        result = _get_ingredient_nutrition(db, fallback_source, visited)
        if result:
            fallback_ingredient, nutrition_data, chain = result
            # 如果回退链最终回到了原始食材，跳过此回退源（避免循环链）
            if fallback_ingredient.id == ingredient.id:
                continue
            # 在回退链的开头添加当前食材
            fallback_chain = f"{ingredient.name} → {chain}"
            return fallback_ingredient, nutrition_data, fallback_chain

    return None


async def batch_calculate_recipes_cost_nutrition(
    recipe_ids: List[int],
    user_id: int,
    db: Session = None,
    region_id: Optional[int] = None,
) -> Dict[int, Dict]:
    """批量计算多个菜谱的成本和营养信息"""
    # 首先获取所有菜谱
    recipes = db.query(Recipe).filter(Recipe.id.in_(recipe_ids)).all()

    results = {}

    for recipe in recipes:
        cost_result = await calculate_recipe_cost(recipe.id, user_id, db, region_id=region_id)
        nutrition_result = await calculate_recipe_nutrition(recipe.id, db)

        # 合并结果
        combined_result = {
            "cost": cost_result,
            "nutrition": nutrition_result
        }

        results[recipe.id] = combined_result

    return results


# 模糊量关键词 → 默认克数映射
VAGUE_QUANTITY_GRAM_MAP = {
    "适量": Decimal("100"),
    "少许": Decimal("5"),
}


def _get_effective_quantity(recipe_ingredient) -> tuple[Decimal, int | None]:
    """
    从 recipe_ingredient 中提取有效数量和有效单位ID。

    优先使用 quantity，如果为 None 则尝试从 quantity_range 取平均值。
    如果仍是 None，检查 original_quantity 中的模糊量关键词（适量→100g, 少许→5g）。

    Returns:
        (quantity, effective_unit_id):
        - quantity: 有效数量（Decimal）
        - effective_unit_id: 数量对应的单位ID。
          当使用 VAGUE_QUANTITY_GRAM_MAP 回退时，返回克单位ID (3)；
          否则返回 recipe_ingredient.unit_id。
          如果无法确定单位，返回 None。
    """
    qty = recipe_ingredient.quantity

    # 如果 quantity 为 None 或字符串 "None"，检查 quantity_range
    if qty is None or (isinstance(qty, str) and qty.lower() == "none"):
        q_range = recipe_ingredient.quantity_range
        if q_range is not None and q_range != 'null':
            try:
                if isinstance(q_range, str):
                    q_range = json.loads(q_range)
                if isinstance(q_range, dict):
                    q_min = q_range.get("min")
                    q_max = q_range.get("max")
                    if q_max is not None:
                        return Decimal(str(q_max)), recipe_ingredient.unit_id
                    elif q_min is not None:
                        return Decimal(str(q_min)), recipe_ingredient.unit_id
            except (json.JSONDecodeError, TypeError, ValueError):
                pass

        # 检查 original_quantity 中的模糊量关键词
        orig = recipe_ingredient.original_quantity
        if orig:
            if isinstance(orig, str):
                orig_lower = orig.strip().lower()
            else:
                # original_quantity 可能是 JSON 字符串
                try:
                    orig_parsed = json.loads(orig) if isinstance(orig, str) else orig
                    if isinstance(orig_parsed, str):
                        orig_lower = orig_parsed.strip().lower()
                    else:
                        orig_lower = str(orig_parsed).lower()
                except (json.JSONDecodeError, TypeError):
                    orig_lower = str(orig).lower()

            for keyword, default_qty in VAGUE_QUANTITY_GRAM_MAP.items():
                if keyword in orig_lower:
                    # VAGUE_QUANTITY_GRAM_MAP 中的值是克数，所以有效单位是"克" (id=3)
                    return default_qty, 3

        return Decimal("0"), recipe_ingredient.unit_id

    return Decimal(str(qty)), recipe_ingredient.unit_id


async def calculate_recipe_cost(
    recipe_id: int,
    user_id: int,
    db: Session = None,
    visited: Optional[set] = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
    recipe_ingredients_override=None,
    servings_override=None,
) -> Dict:
    """计算菜谱成本，使用当天价格区间的平均值"""
    recipe = db.query(Recipe).filter(Recipe.id == recipe_id).first()
    if not recipe:
        return None

    # 循环检测：把自身菜谱纳入已访问集合，透传给制作菜谱回退
    visited = (visited or set()) | {recipe_id}

    total_cost = Decimal("0.00")
    cost_breakdown = []

    # 获取当前日期（UTC naive，与 recorded_at 口径一致）
    now = datetime.now(timezone.utc)

    recipe_ingredients = (
        recipe.ingredients
        if recipe_ingredients_override is None
        else recipe_ingredients_override
    )
    for recipe_ingredient in recipe_ingredients:
        ingredient = recipe_ingredient.ingredient

        # 检查食材是否已被合并，如果是，使用合并后的目标食材
        if ingredient and ingredient.is_merged and ingredient.merged_into_id:
            # 获取合并后的目标食材
            ingredient = db.query(Ingredient).filter(Ingredient.id == ingredient.merged_into_id).first()

        if not ingredient:
            continue

        # 通过ingredient_id查找所有关联商品（可能有多个品牌商品）
        from app.models.product_entity import Product
        products = db.query(Product).filter(
            Product.ingredient_id == ingredient.id,
            Product.is_active == True
        ).all()

        day_records = []
        unit_price = None
        fallback_chain = None  # 回退链信息
        aggregation_chain = None  # 子食材聚合链信息
        recipe_chain = None  # 制作菜谱链信息（半成品成本传递）
        original_ingredient_name = ingredient.name  # 保存原始食材名称
        product = None
        weighted_participants = None  # 直接商品加权明细（透明追溯）

        # 直接商品：与 range 版对齐，使用 _direct_cost_range_ppg 取每克单价
        # （走 original 口径，对 standard_quantity 数据异常鲁棒）
        if products:
            dr_ppg = _direct_cost_range_ppg(db, ingredient, user_id, now, tz, region_id=region_id)
            if dr_ppg is not None:
                _min_ppg, _max_ppg, unit_price = dr_ppg
                # unit_price = avg_ppg，单位元/克

        # 回退食材：与 range 版对齐，用 _fallback_cost_range_ppg
        # （取 fallback 食材全部记录的每克单价均值）
        if unit_price is None:
            fb_range = _fallback_cost_range_ppg(db, ingredient, user_id, now, tz, region_id=region_id)
            if fb_range is not None:
                _fb_min, _fb_max, unit_price = fb_range
                fb_full = _get_ingredient_fallback(db, ingredient, user_id, region_id=region_id)
                if fb_full:
                    _, _, fallback_chain = fb_full

        # 名称匹配：与 range 版对齐，用 _name_match_cost_range_ppg
        if unit_price is None:
            nm_range = _name_match_cost_range_ppg(db, ingredient, user_id, now, tz, region_id=region_id)
            if nm_range is not None:
                _nm_min, _nm_max, unit_price = nm_range

        # 尝试从制作菜谱推导成本（半成品，优先于子食材聚合）
        if unit_price is None:
            recipe_result = _get_cost_from_recipe(db, ingredient, user_id, now, visited, tz=tz, region_id=region_id)
            if recipe_result:
                unit_price, _mk_recipe, recipe_chain = recipe_result
                # unit_price 已经是元/克

        # 如果上述途径全部失败，尝试从包含关系的子食材中聚合成本
        if unit_price is None:
            child_agg = _get_aggregated_cost_from_children(db, ingredient, user_id, now, tz=tz, region_id=region_id)
            if child_agg:
                unit_price, aggregation_chain = child_agg
                # unit_price 已经是元/克

        if unit_price is not None:
            # 计算成本：单价 × 菜谱中的数量 = 成本
            # 优先使用 quantity，如果为 None 则从 quantity_range 取平均值
            # 当使用 VAGUE_QUANTITY_GRAM_MAP 回退时，effective_unit_id 为克(3)
            quantity, effective_unit_id = _get_effective_quantity(recipe_ingredient)

            # 单位转换：将菜谱用量转换为价格记录的单位
            # price_record 的单价是基于 standard_unit_id，菜谱用量基于 effective_unit_id
            if quantity and effective_unit_id:
                if aggregation_chain is not None or recipe_chain is not None or (unit_price is not None and not day_records):
                    # 子食材聚合 / 制作菜谱 / range 版直接商品：unit_price 是元/克，将菜谱用量转换为克
                    if effective_unit_id != 3:
                        recipe_unit = db.query(Unit).filter(Unit.id == effective_unit_id).first()
                        gram_unit = db.query(Unit).filter(Unit.id == 3).first()
                        if recipe_unit and gram_unit:
                            ucs = UnitConversionService(db)
                            converted = ucs.convert(
                                Decimal(str(quantity)),
                                recipe_unit.abbreviation,
                                gram_unit.abbreviation,
                                entity_type="ingredient",
                                entity_id=ingredient.id,
                            )
                            if converted:
                                quantity = float(converted[0])
                elif day_records:
                    price_unit_id = day_records[0].standard_unit_id
                    recipe_unit_id = effective_unit_id
                    if price_unit_id and price_unit_id != recipe_unit_id:
                        # 需要做单位转换
                        price_unit = db.query(Unit).filter(Unit.id == price_unit_id).first()
                        recipe_unit = db.query(Unit).filter(Unit.id == recipe_unit_id).first()
                        if price_unit and recipe_unit:
                            ucs = UnitConversionService(db)
                            # 将菜谱用量从 recipe_unit 转换为 price_unit
                            converted = ucs.convert(
                                Decimal(str(quantity)),
                                recipe_unit.abbreviation,
                                price_unit.abbreviation,
                                entity_type="ingredient",
                                entity_id=ingredient.id,
                            )
                            if converted:
                                quantity = float(converted[0])

            # 只有当数量大于0时才计算成本
            # 对于数量为0的食材，不计入成本（但可能需要显示在成本明细中）
            if quantity:
                try:
                    cost = unit_price * Decimal(str(quantity)) if unit_price else Decimal("0")
                    total_cost += cost

                    cost_breakdown.append({
                        "ingredient_name": ingredient.name,
                        "original_ingredient_name": original_ingredient_name,  # 添加原始食材名称
                        "ingredient_id": ingredient.id,
                        "recipe_ingredient_id": recipe_ingredient.id,  # 添加recipe_ingredient的ID
                        "quantity": str(quantity),
                        "unit_price": float(unit_price) if unit_price else 0.0,
                        "cost": float(cost),
                        "fallback_chain": fallback_chain,  # 回退链信息（如果有）
                        "aggregation_chain": aggregation_chain,  # 子食材聚合链信息（如果有）
                        "recipe_chain": recipe_chain,  # 制作菜谱链信息（如果有）
                        "cost_source": "recipe" if recipe_chain else ("contains_aggregation" if aggregation_chain else ("fallback" if fallback_chain else "direct"))
                    })
                except Exception as e:
                    # 数量解析失败，使用基础价格
                    cost = unit_price
                    total_cost += cost
                    cost_breakdown.append({
                        "ingredient_name": ingredient.name,
                        "ingredient_id": ingredient.id,
                        "recipe_ingredient_id": recipe_ingredient.id,  # 添加recipe_ingredient的ID
                        "quantity": "1",  # 默认为1
                        "unit_price": float(unit_price) if unit_price else 0.0,
                        "cost": float(cost),
                        "fallback_chain": fallback_chain,  # 回退链信息（如果有）
                        "aggregation_chain": aggregation_chain,  # 子食材聚合链信息（如果有）
                        "recipe_chain": recipe_chain,  # 制作菜谱链信息（如果有）
                        "cost_source": "recipe" if recipe_chain else ("contains_aggregation" if aggregation_chain else ("fallback" if fallback_chain else "direct"))
                    })
            else:
                # 对于数量为0的食材，我们仍然添加到明细中但成本为0
                # 这样用户可以看到所有食材，即使它们的数量为0
                cost_breakdown.append({
                    "ingredient_name": ingredient.name,
                    "original_ingredient_name": original_ingredient_name,  # 添加原始食材名称
                    "ingredient_id": ingredient.id,
                    "recipe_ingredient_id": recipe_ingredient.id,  # 添加recipe_ingredient的ID
                    "quantity": str(quantity),
                    "unit_price": float(unit_price) if unit_price else 0.0,
                    "cost": 0.0,
                    "fallback_chain": fallback_chain,  # 回退链信息（如果有）
                    "aggregation_chain": aggregation_chain,  # 子食材聚合链信息（如果有）
                    "recipe_chain": recipe_chain,  # 制作菜谱链信息（如果有）
                    "cost_source": "recipe" if recipe_chain else ("contains_aggregation" if aggregation_chain else ("fallback" if fallback_chain else "direct"))
                })

    from app.services.currency_service import get_user_default_currency
    return {
        "total_cost": total_cost,
        "currency": get_user_default_currency(db, db.query(User).filter(User.id == user_id).first()),
        "cost_per_serving": total_cost / (servings_override or recipe.servings or 1),
        "cost_breakdown": cost_breakdown
    }


def _is_dirty_record(record) -> bool:
    """检查价格记录是否脏（price/standard_quantity 缺失或 ≤0）。"""
    if record is None:
        return True
    if record.price is None or Decimal(str(record.price)) <= 0:
        return True
    if record.standard_quantity is None or Decimal(str(record.standard_quantity)) <= 0:
        return True
    return False


def _qty_unit_to_grams(
    db: Session,
    ingredient: Ingredient,
    qty: Decimal,
    unit_id: Optional[int],
) -> Optional[Decimal]:
    """将 (数量, 单位) 折算为克。

    unit_id 为 None 或 3(克) 时直接返回 qty；
    通过 UnitConversionService 换算其他单位到克。
    qty 为 None/≤0 或转换失败时返回 None。
    """
    if qty is None or qty <= 0:
        return None
    if unit_id is None or unit_id == 3:
        return qty
    unit = db.query(Unit).filter(Unit.id == unit_id).first()
    gram_unit = db.query(Unit).filter(Unit.id == 3).first()
    if not unit or not gram_unit:
        return None
    ucs = UnitConversionService(db)
    converted = ucs.convert(
        qty,
        unit.abbreviation,
        gram_unit.abbreviation,
        entity_type="ingredient",
        entity_id=ingredient.id,
    )
    if converted:
        grams = Decimal(str(converted[0]))
        return grams if grams > 0 else None
    return None


def _direct_cost_range_ppg(
    db: Session,
    ingredient: Ingredient,
    user_id: int,
    as_of_date: datetime,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> Optional[tuple[Decimal, Decimal, Decimal]]:
    """直接商品的 (min_ppg, max_ppg, avg_ppg) 元/克。无可用记录返 None。

    三档全部来自参与商品当天有效记录的逐条每克单价（_convert_record_to_price_per_gram），
    经 _ppgs_to_range 得同源极值与均值，数学上保证 min ≤ avg ≤ max。
    participants（参与商品集）取自 resolve_direct_weighted_for_cost 的筛选。

    不再用 resolve_direct_weighted_for_cost 的 unit_price 折克做 avg override：
    该路径经 _product_unit_price 依赖记录的 standard_quantity，当该字段数据质量异常
    （如 original 与 standard 单位转换未落地）会把价格放大数十倍，导致 avg > max。
    逐条 _convert_record_to_price_per_gram 走 original_quantity/original_unit 折克，
    对数据质量鲁棒，且与 _records_cost_range_ppg 等其它层级同口径。
    """
    from app.services.ingredient_price_service import resolve_direct_weighted_for_cost
    dw = resolve_direct_weighted_for_cost(
        db, ingredient.id, user_id=user_id, as_of_date=as_of_date, tz=tz,
        region_id=region_id,
    )
    if dw is None:
        return None
    _, participants, _ = dw

    ppgs: list[Decimal] = []
    for p in participants:
        pid = p.get("product_id")
        if not pid:
            continue
        recs = _get_price_records_with_fallback(
            db=db, user_id=user_id, product_id=pid, as_of_date=as_of_date, tz=tz,
            region_id=region_id,
        )
        for r in recs or []:
            if _is_dirty_record(r):
                continue
            ppgs.append(_convert_record_to_price_per_gram(db, r, ingredient.id))
    return _ppgs_to_range(ppgs)


def _ppgs_to_range(ppgs):
    """一组每克单价 → (min, max, avg)，池空返回 None。

    过滤 None 与 ≤0 脏数据（防 min=0 等）。纯函数（不吃 db），
    便于单测；被 _records_cost_range_ppg / _direct_cost_range_ppg /
    _get_child_price_per_gram_range 共用。
    """
    clean = [Decimal(str(p)) for p in ppgs if p is not None and Decimal(str(p)) > 0]
    if not clean:
        return None
    avg = sum(clean) / Decimal(len(clean))
    return (min(clean), max(clean), avg)


def _records_cost_range_ppg(
    records,
    db: Session,
    ingredient_id: int,
) -> Optional[tuple[Decimal, Decimal, Decimal]]:
    """一组记录 → (min_ppg, max_ppg, avg_ppg) 元/克，过滤脏数据。池空返 None。

    avg 取记录 per_gram 简单平均；min/max 是同一记录集极值，故 min≤avg≤max 必然成立。
    ingredient_id 用于 _convert_record_to_price_per_gram 的单位转换上下文（entity 级 override）。
    """
    ppgs: list[Decimal] = []
    for r in records or []:
        if _is_dirty_record(r):
            continue
        ppgs.append(_convert_record_to_price_per_gram(db, r, ingredient_id))
    return _ppgs_to_range(ppgs)


def _fallback_cost_range_ppg(
    db: Session,
    ingredient: Ingredient,
    user_id: int,
    as_of_date: datetime,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> Optional[tuple[Decimal, Decimal, Decimal]]:
    """fallback 链（含 substitutable）：回退食材当天记录集的 (min,max,avg) ppg。

    _get_ingredient_fallback 内部已处理 fallback + substitutable 双向关系，
    返回的 fb_ingredient 是第一个「有任何价格记录」的回退源；这里再按 as_of_date
    前向填充取该回退食材当天所有商品的有效记录极值。
    """
    fb = _get_ingredient_fallback(db, ingredient, user_id, region_id=region_id)
    if not fb:
        return None
    fb_ingredient, _latest, _chain = fb
    products = db.query(Product).filter(
        Product.ingredient_id == fb_ingredient.id, Product.is_active == True
    ).all()
    all_recs: list[ProductRecord] = []
    for p in products:
        recs = _get_price_records_with_fallback(
            db=db, user_id=user_id, product_id=p.id, as_of_date=as_of_date, tz=tz,
            region_id=region_id,
        )
        all_recs.extend(recs or [])
    # ingredient_id 用回退食材 id：记录的 unit override 上下文属于回退食材
    return _records_cost_range_ppg(all_recs, db, fb_ingredient.id)


def _name_match_cost_range_ppg(
    db: Session,
    ingredient: Ingredient,
    user_id: int,
    as_of_date: datetime,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> Optional[tuple[Decimal, Decimal, Decimal]]:
    """按食材名作 product_name_contains 匹配的记录集 (min,max,avg) ppg。

    注意：_get_price_records_with_fallback（复数）只接 product_id 不接 name_contains，
    所以先用单数版 _get_price_record_with_fallback 拿前向填充锚点，
    再以锚点所在本地日 + product_name.contains 取该日全部同名记录（对齐复数版的
    「锚点日全记录集」范式）。
    """
    anchor = _get_price_record_with_fallback(
        db=db, user_id=user_id, product_name_contains=ingredient.name,
        as_of_date=as_of_date, tz=tz, region_id=region_id,
    )
    if not anchor:
        return None
    fill_date = utc_datetime_to_local_date(anchor.recorded_at, tz)
    day_start, day_end = local_date_range_to_utc_range(fill_date, fill_date, tz)
    from app.services.price_region import apply_region_filter
    recs = apply_region_filter(
        db.query(ProductRecord).filter(
            ProductRecord.product_name.contains(ingredient.name),
            ProductRecord.recorded_at >= day_start,
            ProductRecord.recorded_at <= day_end,
        ),
        db, region_id,
    ).all()
    return _records_cost_range_ppg(recs, db, ingredient.id)


def _ingredient_cost_range(
    db: Session,
    recipe_ingredient: RecipeIngredient,
    ingredient: Ingredient,
    user_id: int,
    as_of_date: datetime,
    visited: Optional[List[int]] = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> tuple[Decimal, Decimal, Decimal, str]:
    """单个食材成本三档 + 来源标签。返回 (min, max, avg, cost_source)。

    全无价返 (0, 0, 0, "no_price")；无法归克返 (0, 0, 0, "no_quantity")。
    降级链与 calculate_recipe_cost_as_of 对齐：
    direct → fallback → name_match → recipe → contains。
    （direct/fallback/name_match 已接入；recipe/contains 在 Task 4/5 接入）
    """
    qty_decimal, qty_unit_id = _get_effective_quantity(recipe_ingredient)
    qty_g = _qty_unit_to_grams(db, ingredient, qty_decimal, qty_unit_id)
    if qty_g is None or qty_g <= 0:
        return Decimal("0"), Decimal("0"), Decimal("0"), "no_quantity"

    # 来源 1：direct
    direct = _direct_cost_range_ppg(db, ingredient, user_id, as_of_date, tz, region_id=region_id)
    if direct is not None:
        mn, mx, av = direct
        return (mn * qty_g, mx * qty_g, av * qty_g, "direct")

    # 来源 2：fallback（含 substitutable）
    fb = _fallback_cost_range_ppg(db, ingredient, user_id, as_of_date, tz, region_id=region_id)
    if fb is not None:
        mn, mx, av = fb
        return (mn * qty_g, mx * qty_g, av * qty_g, "fallback")

    # 来源 3：name_match（按食材名匹配 product_name）
    nm = _name_match_cost_range_ppg(db, ingredient, user_id, as_of_date, tz, region_id=region_id)
    if nm is not None:
        mn, mx, av = nm
        return (mn * qty_g, mx * qty_g, av * qty_g, "name_match")

    # 来源 4：recipe 半成品递归（与 calculate_recipe_cost_as_of 对齐）
    rc = _get_cost_from_recipe_range(db, ingredient, user_id, as_of_date, visited, tz, region_id=region_id)
    if rc is not None:
        mn_ppg, mx_ppg, av_ppg, _chain = rc
        return (mn_ppg * qty_g, mx_ppg * qty_g, av_ppg * qty_g, "recipe")

    # 来源 5: contains 子食材聚合（与 calculate_recipe_cost_as_of 对齐）
    # 注意：contains 聚合的循环检测是食材级（visited 为食材 id 列表），
    # 与上层菜谱级 visited（菜谱 id 列表）独立，故传 None 从空开始——
    # 对齐既有 single 版 calculate_recipe_cost_as_of @2435 的调用方式
    contains = _contains_cost_range_ppg(db, ingredient, user_id, as_of_date, None, tz, region_id=region_id)
    if contains is not None:
        mn_ppg, mx_ppg, av_ppg, _chain = contains
        return (mn_ppg * qty_g, mx_ppg * qty_g, av_ppg * qty_g, "contains_aggregation")

    return Decimal("0"), Decimal("0"), Decimal("0"), "no_price"


def calculate_recipe_cost_range_as_of(
    db: Session,
    recipe_id: int,
    user_id: int,
    as_of_date: datetime,
    visited: Optional[List[int]] = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> Optional[Dict]:
    """计算菜谱在指定日期的成本三档（min/max/avg），三档基于同一组价格源。

    返回 {min_cost, max_cost, avg_cost, currency, cost_breakdown} 或 None。
    保证 min ≤ avg ≤ max（数学上：min/max 取记录极值、avg 取加权均价，
    两者源自同一批参与商品的有效记录，加权值必在极值闭区间内）。
    降级链与 calculate_recipe_cost_as_of 1:1 对齐：
    direct → fallback → name_match → recipe → contains。

    visited 为菜谱 ID 列表（循环检测，半成品递归用）。
    """
    if visited is None:
        visited = []
    if recipe_id in visited:
        return None  # 循环检测
    visited = visited + [recipe_id]

    recipe = db.query(Recipe).filter(Recipe.id == recipe_id).first()
    if not recipe:
        return None

    total_min = Decimal("0")
    total_max = Decimal("0")
    total_avg = Decimal("0")
    breakdown: list[dict] = []

    for ri in recipe.ingredients:
        ing = ri.ingredient
        # 检查食材是否已被合并，使用合并后的目标食材
        if ing and ing.is_merged and ing.merged_into_id:
            ing = db.query(Ingredient).filter(Ingredient.id == ing.merged_into_id).first()
        if not ing:
            continue

        imin, imax, iavg, src = _ingredient_cost_range(
            db, ri, ing, user_id, as_of_date, visited, tz,
            region_id=region_id,
        )
        total_min += imin
        total_max += imax
        total_avg += iavg
        breakdown.append({
            "ingredient_id": ing.id,
            "name": ing.name,
            "min_cost": float(imin),
            "max_cost": float(imax),
            "avg_cost": float(iavg),
            "cost_source": src,
        })

    from app.services.currency_service import get_user_default_currency
    return {
        "min_cost": total_min,
        "max_cost": total_max,
        "avg_cost": total_avg,
        "currency": get_user_default_currency(db, db.query(User).filter(User.id == user_id).first()),
        "cost_breakdown": breakdown,
    }


def calculate_recipe_cost_range_trend(
    recipe_id: int,
    user_id: int,
    db: Session,
    days: int = 90,
    offset_days: int = 0,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> List[Dict]:
    """
    计算菜谱的成本区间趋势

    对每一天统一调用 calculate_recipe_cost_range_as_of（单轨），min/max/avg
    三档基于同一组价格源、走同一条 5 层降级链（direct → fallback →
    name_match → recipe → contains），从数学上保证 min ≤ avg ≤ max。

    Args:
        recipe_id: 菜谱ID
        user_id: 用户ID
        db: 数据库会话
        days: 查询天数（默认90天）
        offset_days: 偏移天数。如 days=30, offset_days=0 为近30天；
                     days=60, offset_days=30 为第31天至第90天。

    Returns:
        成本区间趋势数据列表
    """
    recipe = db.query(Recipe).filter(Recipe.id == recipe_id).first()
    if not recipe:
        return []

    earliest_record = db.query(ProductRecord).order_by(ProductRecord.recorded_at.asc()).first()
    if not earliest_record:
        return []

    # ── 日期范围 ──
    end_date = utc_datetime_to_local_date(datetime.now(timezone.utc), tz) - timedelta(days=offset_days)
    start_date = max(
        utc_datetime_to_local_date(earliest_record.recorded_at, tz),
        end_date - timedelta(days=days)
    )

    date_list = []
    current_date = start_date
    while current_date <= end_date:
        date_list.append(current_date)
        current_date += timedelta(days=1)

    # ═══════════════════════════════════════════════════════════
    # 逐天计算：统一走 calculate_recipe_cost_range_as_of（单轨）
    # ═══════════════════════════════════════════════════════════
    cost_range_trend = []

    for date in date_list:
        _, as_of_datetime = local_date_range_to_utc_range(date, date, tz)

        try:
            result = calculate_recipe_cost_range_as_of(
                db, recipe_id, user_id, as_of_datetime, tz=tz,
                region_id=region_id,
            )
        except Exception as e:
            logger.debug("calculate_recipe_cost_range_as_of 失败 recipe=%s date=%s: %s", recipe_id, date, e)
            continue

        # 跳过无有效成本的日子（avg 为 0/None）
        if not result or not result.get("avg_cost") or result["avg_cost"] <= 0:
            continue

        # breakdown 字段映射：
        # range 版 {ingredient_id, name, min_cost, max_cost, avg_cost, cost_source}
        # → 旧 trend {ingredient_id, ingredient_name, cost}
        # 旧 trend 的 cost 即单点成本，对应 range 版 avg_cost（保持前端兼容）
        breakdown_items = []
        for bi in result.get("cost_breakdown", []) or []:
            try:
                breakdown_items.append({
                    "ingredient_id": bi["ingredient_id"],
                    "ingredient_name": bi["name"],
                    "cost": float(bi["avg_cost"]) if bi.get("avg_cost") is not None else 0.0,
                })
            except (KeyError, TypeError):
                continue

        # recorded_at 时间戳（保留旧逻辑：当天中午 UTC 时间戳）
        recorded_at = int((
            local_date_range_to_utc_range(date, date, tz)[0] + timedelta(hours=12)
        ).replace(tzinfo=timezone.utc).timestamp())

        cost_range_trend.append({
            "date": date.strftime("%Y-%m-%d"),
            "recorded_at": recorded_at,
            "min_cost": round(float(result["min_cost"]), 4),
            "max_cost": round(float(result["max_cost"]), 4),
            "avg_cost": round(float(result["avg_cost"]), 4),
            "breakdown": breakdown_items,
        })

    return cost_range_trend


async def calculate_recipe_nutrition(
    recipe_id: int,
    db: Session = None
) -> Dict:
    """计算菜谱营养"""
    recipe = db.query(Recipe).filter(Recipe.id == recipe_id).first()
    if not recipe:
        return None

    # NRV（营养素参考值）- 中国标准值（成人每日摄入量）
    # 来源：GB 28050-2011《食品安全国家标准 预包装食品营养标签通则》
    NRV_REFERENCE_VALUES = {
        "能量": 2000,  # kcal
        "蛋白质": 60,   # g
        "脂肪": 60,     # g
        "碳水化合物": 300,  # g
        "膳食纤维": 25,   # g
        "钙": 800,      # mg
        "铁": 15,       # mg
        "钠": 2000,     # mg
        "钾": 2000,     # mg
        "维生素A": 800,  # μg
        "维生素C": 100,   # mg
        "维生素B1": 1.2, # mg
        "维生素B2": 1.4, # mg
        "维生素B12": 2.4, # μg
        "维生素D": 5,     # μg
        "维生素E": 14,    # mg
        "维生素K": 80     # μg
    }

    # 初始化所有核心营养素的总量
    total_core_nutrients = {
        "能量": {"value": 0, "unit": "kcal", "key": "energy"},
        "蛋白质": {"value": 0, "unit": "g", "key": "protein"},
        "脂肪": {"value": 0, "unit": "g", "key": "fat"},
        "碳水化合物": {"value": 0, "unit": "g", "key": "carbohydrate"},
        "膳食纤维": {"value": 0, "unit": "g", "key": "fiber"},
        "钙": {"value": 0, "unit": "mg", "key": "calcium"},
        "铁": {"value": 0, "unit": "mg", "key": "iron"},
        "钠": {"value": 0, "unit": "mg", "key": "sodium"},
        "钾": {"value": 0, "unit": "mg", "key": "potassium"},
        "维生素A": {"value": 0, "unit": "μg", "key": "vitamin_a_rae"},
        "维生素C": {"value": 0, "unit": "mg", "key": "vitamin_c"},
        "维生素B1": {"value": 0, "unit": "mg", "key": "vitamin_b1"},
        "维生素B2": {"value": 0, "unit": "mg", "key": "vitamin_b2"},
        "维生素B12": {"value": 0, "unit": "μg", "key": "vitamin_b12"},
        "维生素D": {"value": 0, "unit": "μg", "key": "vitamin_d"},
        "维生素E": {"value": 0, "unit": "mg", "key": "vitamin_e"},
        "维生素K": {"value": 0, "unit": "μg", "key": "vitamin_k"}
    }

    from app.utils.unit_converter import convert_to_standard

    # 存储食材贡献详情
    ingredient_details = []

    # 初始化所有营养素的总量（包括 all_nutrients）
    total_all_nutrients = {}

    for recipe_ingredient in recipe.ingredients:
        ingredient = recipe_ingredient.ingredient

        # 检查食材是否已被合并，如果是，使用合并后的目标食材
        if ingredient and ingredient.is_merged and ingredient.merged_into_id:
            ingredient = db.query(Ingredient).filter(Ingredient.id == ingredient.merged_into_id).first()

        if not ingredient:
            continue

        # 使用 ingredient_id 查找营养数据（而不是 nutrition_id）
        nutrition = db.query(NutritionData).filter(
            NutritionData.ingredient_id == ingredient.id
        ).order_by(NutritionData.id.desc()).first()

        # 如果当前食材没有营养数据，尝试使用回退食材
        if not nutrition:
            fallback_result = _get_ingredient_nutrition(db, ingredient, None)
            if fallback_result:
                fallback_ingredient, fallback_nutrition, fallback_chain = fallback_result
                ingredient = fallback_ingredient
                nutrition = fallback_nutrition
                # 记录使用了回退食材
                fallback_chain_info = fallback_chain
            else:
                continue
        else:
            fallback_chain_info = None

        # 获取营养数据（从 JSON 字段）
        nutrients = nutrition.nutrients or {}
        core_nutrients = nutrients.get("core_nutrients", {})
        all_nutrients = nutrients.get("all_nutrients", {})

        # 获取回退食材的营养数据（用于单条营养素回退）
        fallback_nutrition = None
        if not fallback_chain_info:
            # 如果已经使用了回退食材（fallback_chain_info 不为 None），就不需要再次查找
            fallback_result = _get_ingredient_nutrition(db, ingredient, None)
            if fallback_result:
                fallback_nutrition = fallback_result[1]
                if fallback_nutrition and fallback_nutrition.nutrients:
                    fallback_nutrients = fallback_nutrition.nutrients.get("core_nutrients", {})
                else:
                    fallback_nutrients = {}
            else:
                fallback_nutrients = {}

        # 提取参考基准
        reference_amount = Decimal(str(nutrition.reference_amount or 100.0))
        reference_unit = nutrition.reference_unit or "g"

        # 获取菜谱中的原料数量，并转换为标准单位
        ingredient_quantity_str = recipe_ingredient.quantity or "0"
        # 将 None 视为 "0"
        if recipe_ingredient.quantity is None:
            ingredient_quantity_str = "0"
        ingredient_unit = ""

        # 尝试解析数量和单位
        try:
            # 如果数量是纯数字字符串
            if str(ingredient_quantity_str).replace(".", "").replace("-", "").isdigit():
                quantity = Decimal(str(ingredient_quantity_str))
                # 如果有单位信息，尝试使用原始数量和单位
                if recipe_ingredient.unit:
                    ingredient_unit = recipe_ingredient.unit.abbreviation
                    # 转换为标准单位
                    standard_quantity, standard_unit = convert_to_standard(quantity, ingredient_unit)
                else:
                    # 没有单位信息，假设使用参考基准单位
                    standard_quantity = quantity
                    standard_unit = reference_unit
            else:
                # 数量可能包含单位（如 "250g"），需要解析
                import re
                match = re.match(r"([\d.]+)\s*([a-zA-Z\u4e00-\u9fff]+)", str(ingredient_quantity_str))
                if match:
                    quantity = Decimal(match.group(1))
                    ingredient_unit = match.group(2)
                    standard_quantity, standard_unit = convert_to_standard(quantity, ingredient_unit)
                else:
                    # 无法解析，使用默认值
                    standard_quantity = Decimal("0")
                    standard_unit = reference_unit
        except Exception as e:
            # 解析失败，使用默认值
            standard_quantity = Decimal("0")
            standard_unit = reference_unit

        # 计算比例因子（菜谱中的数量 / 参考基准数量）
        # 确保单位一致才能比较

        # 首先处理容量单位的密度转换
        if standard_unit.lower() == "ml" and recipe_ingredient.unit:
            # 如果是容量单位，尝试使用密度转换为重量
            from app.models.ingredient_density import IngredientDensity

            # 查找密度数据（mL → g）
            density = db.query(IngredientDensity).filter(
                IngredientDensity.ingredient_id == ingredient.id,
                IngredientDensity.from_unit_id == recipe_ingredient.unit.id,
                IngredientDensity.to_unit_id == 3  # g 的 ID
            ).first()

            if density and density.density_value:
                # 使用密度转换：重量 = 容量 × 密度
                standard_quantity = standard_quantity * Decimal(str(density.density_value))
                standard_unit = "g"  # 转换为克
            else:
                # 没有密度数据，假设密度为 1.0 g/mL
                standard_quantity = standard_quantity
                standard_unit = "g"

        if standard_unit.lower() in ["g", "ml"] and reference_unit.lower() in ["g", "ml"]:
            # 如果都是重量或容量单位，可以计算比例
            ratio = standard_quantity / reference_amount
        elif recipe_ingredient.unit and recipe_ingredient.unit.unit_type == "count":
            # 如果是计数单位（如"个"），尝试使用 piece_weight 转换
            from app.models.unit import Unit
            from app.models.entity_unit_override import EntityUnitOverride
            if ingredient.piece_weight:
                # 使用食材的标准重量转换（如：1个鸡蛋=50g）
                # piece_weight_unit_id 未设置时默认按克(g)处理
                piece_weight = Decimal(str(ingredient.piece_weight))
                piece_weight_unit = ingredient.piece_weight_unit.abbreviation if ingredient.piece_weight_unit else "g"

                # 转换为标准重量单位
                converted_weight, converted_unit = convert_to_standard(piece_weight, piece_weight_unit)
                # 计算总重量（数量 × 每个的重量）
                total_weight = quantity * converted_weight

                if converted_unit.lower() == reference_unit.lower():
                    # 单位一致，计算比例
                    ratio = total_weight / reference_amount
                else:
                    # 单位不一致，尝试转换
                    weight_unit_obj = db.query(Unit).filter(Unit.abbreviation == converted_unit).first()
                    if weight_unit_obj and weight_unit_obj.unit_type == "mass":
                        ratio = total_weight / reference_amount
                    else:
                        # 无法转换，使用默认值
                        ratio = Decimal("1.0")
            else:
                # 没有设置 piece_weight，尝试查询 entity_unit_overrides 自定义单位表
                entity_override = db.query(EntityUnitOverride).filter(
                    EntityUnitOverride.entity_type == "ingredient",
                    EntityUnitOverride.entity_id == ingredient.id,
                    EntityUnitOverride.unit_name == recipe_ingredient.unit.abbreviation,
                    EntityUnitOverride.weight_per_unit.isnot(None),
                    EntityUnitOverride.weight_unit_id.isnot(None),
                    EntityUnitOverride.is_active.is_(True),
                ).first()
                if entity_override and entity_override.weight_per_unit:
                    # 使用自定义单位中维护的每件标准重量（如 1 颗=0.2g）
                    weight_unit = db.query(Unit).filter(Unit.id == entity_override.weight_unit_id).first()
                    if weight_unit:
                        converted_weight, converted_unit = convert_to_standard(
                            Decimal(str(entity_override.weight_per_unit)),
                            weight_unit.abbreviation
                        )
                        total_weight = quantity * converted_weight
                        if converted_unit.lower() == reference_unit.lower():
                            ratio = total_weight / reference_amount
                        else:
                            # 单位不一致，尝试通过 Unit 类型判断
                            weight_unit_obj = db.query(Unit).filter(Unit.abbreviation == converted_unit).first()
                            if weight_unit_obj and weight_unit_obj.unit_type == "mass":
                                ratio = total_weight / reference_amount
                            else:
                                ratio = Decimal("0")
                    else:
                        ratio = Decimal("0")
                else:
                    # 没有维护每件标准重量，无法将计数单位换算为质量
                    # 设为 0 避免错误高估（原 ratio=1.0 会将 20 颗按 100g 计算）
                    ratio = Decimal("0")
        else:
            # 单位不一致，假设比例是1:1（使用参考值）
            ratio = Decimal("1.0")

        # 累加所有核心营养素值
        for nutrient_name, nutrient_data in core_nutrients.items():
            if nutrient_name in total_core_nutrients:
                # 确保 value 不为 None
                value = float(nutrient_data.get("value", 0) or 0)
                source_unit = nutrient_data.get("unit", "")

                # 如果值为 0 且有回退食材，尝试从回退食材获取该营养素的值
                if value == 0 and fallback_nutrients and nutrient_name in fallback_nutrients:
                    fallback_value = float(fallback_nutrients[nutrient_name].get("value", 0) or 0)
                    if fallback_value > 0:
                        value = fallback_value
                        source_unit = fallback_nutrients[nutrient_name].get("unit", "")
                        # 记录使用了回退值（可在日志中查看）

                # 如果是能量，检查单位并转换为 kcal
                if nutrient_name == "能量" and source_unit in ("kJ", "千焦", "千焦(kJ)"):
                    # 先将 kJ 转换为 kcal（1 kJ = 0.239006 kcal）
                    value_kcal = value * 0.239006
                    total_core_nutrients[nutrient_name]["value"] += value_kcal * float(ratio)
                    total_core_nutrients[nutrient_name]["unit"] = "kcal"
                else:
                    total_core_nutrients[nutrient_name]["value"] += value * float(ratio)
                    total_core_nutrients[nutrient_name]["unit"] = source_unit

        # 累加所有其他营养素值（all_nutrients）
        for nutrient_name, nutrient_data in all_nutrients.items():
            if nutrient_name not in total_core_nutrients:  # 避免重复累加核心营养素
                # 确保 value 不为 None
                value = float(nutrient_data.get("value", 0) or 0)
                source_unit = nutrient_data.get("unit", "")

                # 如果值为 0 且有回退食材，尝试从回退食材获取该营养素的值
                if value == 0 and fallback_nutrients and nutrient_name in fallback_nutrients:
                    fallback_value = float(fallback_nutrients[nutrient_name].get("value", 0) or 0)
                    if fallback_value > 0:
                        value = fallback_value
                        source_unit = fallback_nutrients[nutrient_name].get("unit", "")

                # 初始化 total_all_nutrients（如果不存在）
                if nutrient_name not in total_all_nutrients:
                    total_all_nutrients[nutrient_name] = {"value": 0, "unit": source_unit}

                # 如果是能量，检查单位并转换为 kcal
                if nutrient_name == "能量" and source_unit in ("kJ", "千焦", "千焦(kJ)"):
                    # 先将 kJ 转换为 kcal（1 kJ = 0.239006 kcal）
                    value_kcal = value * 0.239006
                    total_all_nutrients[nutrient_name]["value"] += value_kcal * float(ratio)
                    total_all_nutrients[nutrient_name]["unit"] = "kcal"
                else:
                    total_all_nutrients[nutrient_name]["value"] += value * float(ratio)
                    total_all_nutrients[nutrient_name]["unit"] = source_unit

        # 添加食材贡献详情
        # 收集每个营养素的贡献值（考虑回退）——先 core，再 all
        contribution_data = {}
        for nutrient_name, nutrient_data in {**core_nutrients, **all_nutrients}.items():
            value = float(nutrient_data.get("value", 0) or 0)
            used_fallback = False

            # 如果值为 0 且有回退食材，尝试从回退食材获取该营养素的值
            if value == 0 and fallback_nutrients and nutrient_name in fallback_nutrients:
                fallback_value = float(fallback_nutrients[nutrient_name].get("value", 0) or 0)
                if fallback_value > 0:
                    value = fallback_value
                    used_fallback = True

            nrv_ref = NRV_REFERENCE_VALUES.get(nutrient_name, 0)
            contribution_data[nutrient_name] = {
                "value": value * float(ratio),
                "unit": nutrient_data.get("unit", ""),
                "nrp_pct": round((value * float(ratio) / nrv_ref) * 100, 2) if nrv_ref > 0 else 0,
                "used_fallback": used_fallback,
            }

        ingredient_details.append({
            "recipe_ingredient_id": recipe_ingredient.id,  # 添加recipe_ingredient的ID
            "ingredient_id": ingredient.id,
            "ingredient_name": ingredient.name,
            "quantity": float(standard_quantity),
            "unit": standard_unit,
            "nutrition_contribution": contribution_data
        })

    servings = recipe.servings or 1

    # 计算每份营养值和 NRV 百分比
    per_serving_core_nutrients = {}
    for name, data in total_core_nutrients.items():
        # 处理 None 值的情况
        total_value = data["value"] if data["value"] is not None else 0
        per_serving_value = round(total_value / servings, 2)
        per_serving_unit = data["unit"] if data["unit"] is not None else ""

        # 使用 NRV 标准参考值计算 NRV 百分比
        nrv_reference = NRV_REFERENCE_VALUES.get(name, 0)
        if nrv_reference > 0:
            # NRV 百分比 = （每份营养值 / NRV 标准值）× 100
            per_serving_nrp_pct = round((per_serving_value / nrv_reference) * 100, 2)
            # 添加参考值说明
            per_serving_standard = f"NRV标准值：{nrv_reference}{per_serving_unit}"
        else:
            # 没有参考值，设为 None
            per_serving_nrp_pct = None
            per_serving_standard = "无标准"

        per_serving_core_nutrients[name] = {
            "value": per_serving_value,
            "unit": per_serving_unit,
            "key": data["key"],
            "nrp_pct": per_serving_nrp_pct,
            "standard": per_serving_standard
        }

    # 计算每份的 all_nutrients 值
    per_serving_all_nutrients = {}
    for name, data in total_all_nutrients.items():
        # 处理 None 值的情况
        total_value = data["value"] if data["value"] is not None else 0
        per_serving_value = round(total_value / servings, 2)
        per_serving_unit = data["unit"] if data["unit"] is not None else ""

        # 使用 NRV 标准参考值计算 NRV 百分比（如果有参考值）
        nrv_reference = NRV_REFERENCE_VALUES.get(name, 0)
        if nrv_reference > 0:
            per_serving_nrp_pct = round((per_serving_value / nrv_reference) * 100, 2)
            # 添加参考值说明
            per_serving_standard = f"NRV标准值：{nrv_reference}{per_serving_unit}"
        else:
            # 没有参考值，设为 None
            per_serving_nrp_pct = None
            per_serving_standard = "无标准"

        per_serving_all_nutrients[name] = {
            "value": per_serving_value,
            "unit": per_serving_unit,
            "nrp_pct": per_serving_nrp_pct,
            "standard": per_serving_standard
        }

    # 提取简化的核心值用于兼容性
    energy_data = total_core_nutrients.get("能量", {})
    protein_data = total_core_nutrients.get("蛋白质", {})
    fat_data = total_core_nutrients.get("脂肪", {})
    carb_data = total_core_nutrients.get("碳水化合物", {})

    # 如果能量单位是 kJ，转换为 kcal，并处理 None 值
    energy_value = energy_data.get("value", 0) if energy_data else 0
    total_calories = float(energy_value) if energy_value is not None else 0.0
    if energy_data and energy_data.get("unit") in ("kJ", "千焦", "千焦(kJ)"):
        total_calories *= 0.239006

    protein_value = protein_data.get("value", 0) if protein_data else 0.0
    total_protein = float(protein_value) if protein_value is not None else 0.0

    fat_value = fat_data.get("value", 0) if fat_data else 0.0
    total_fat = float(fat_value) if fat_value is not None else 0.0

    carb_value = carb_data.get("value", 0) if carb_data else 0.0
    total_carbs = float(carb_value) if carb_value is not None else 0.0

    return {
        "total_calories": total_calories,
        "total_protein": float(protein_data["value"]),
        "total_fat": float(fat_data["value"]),
        "total_carbs": float(carb_data["value"]),
        "per_serving": {
            "calories": total_calories / servings,
            "protein": total_protein / servings,
            "fat": total_fat / servings,
            "carbs": total_carbs / servings
        },
        "total_nutrition": {
            "core_nutrients": {
                name: {
                    **data,
                    "value": round(data["value"], 2)
                }
                for name, data in total_core_nutrients.items()
            }
        },
        "per_serving_nutrition": {
            "core_nutrients": per_serving_core_nutrients,
            "all_nutrients": per_serving_all_nutrients
        },
        "ingredient_details": ingredient_details  # 添加食材贡献详情
    }


def calculate_recipe_cost_as_of(
    recipe_id: int,
    user_id: int,
    as_of_date: datetime,
    db: Session,
    visited: Optional[set] = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> Dict:
    """
    计算菜谱在指定日期的成本

    使用截至指定日期的最新价格记录计算成本。
    """
    recipe = db.query(Recipe).filter(Recipe.id == recipe_id).first()
    if not recipe:
        return None

    # 循环检测：把自身菜谱纳入已访问集合，透传给制作菜谱回退
    visited = (visited or set()) | {recipe_id}

    total_cost = Decimal("0.00")
    cost_breakdown = []

    for recipe_ingredient in recipe.ingredients:
        ingredient = recipe_ingredient.ingredient

        # 检查食材是否已被合并，如果是，使用合并后的目标食材
        if ingredient and ingredient.is_merged and ingredient.merged_into_id:
            # 获取合并后的目标食材
            ingredient = db.query(Ingredient).filter(Ingredient.id == ingredient.merged_into_id).first()

        if not ingredient:
            continue

        # 首先通过ingredient_id查找所有商品（可能有多个品牌商品）
        products = db.query(Product).filter(
            Product.ingredient_id == ingredient.id,
            Product.is_active == True
        ).all()

        latest_record = None
        unit_price = None
        fallback_chain = None  # 回退链信息
        aggregation_chain = None  # 子食材聚合链信息
        recipe_chain = None  # 制作菜谱链信息（半成品成本传递）
        original_ingredient_name = ingredient.name  # 保存原始食材名称
        product = None
        weighted_participants = None  # 直接商品加权明细（透明追溯）

        if products:
            # 直接商品：与 range 版对齐，使用 _direct_cost_range_ppg 取每克单价
            # （走 _convert_record_to_price_per_gram 的 original 口径，
            #  对 standard_quantity 数据异常鲁棒；
            #  resolve 加权路径依赖 standard_quantity 可能放大数十倍导致成本虚高）
            dr_ppg = _direct_cost_range_ppg(db, ingredient, user_id, as_of_date, tz, region_id=region_id)
            if dr_ppg is not None:
                _min_ppg, _max_ppg, unit_price = dr_ppg
                # unit_price = avg_ppg，单位元/克；latest_record 留 None，
                # 下方单位转换走克路径（同 recipe_chain/aggregation_chain）
            else:
                # dr_ppg 返回 None 时不做 iterate 回退——
                # 让下方降级链 (fallback→name_match→recipe→contains) 统一处理，
                # 与 range 版 _ingredient_cost_range 对齐
                pass

            # 回退食材：与 range 版对齐，用 _fallback_cost_range_ppg
            # （取 fallback 食材全部记录的每克单价均值，而非单条记录）
            if unit_price is None:
                fb_range = _fallback_cost_range_ppg(db, ingredient, user_id, as_of_date, tz, region_id=region_id)
                if fb_range is not None:
                    _fb_min, _fb_max, unit_price = fb_range
                    # unit_price = avg_ppg，单位元/克
                    # 取 fallback_chain 用于前端展示
                    fb_full = _get_ingredient_fallback(db, ingredient, user_id, region_id=region_id)
                    if fb_full:
                        _, _, fallback_chain = fb_full
        else:
            # 没有商品：与 range 版对齐，用 _fallback_cost_range_ppg
            if unit_price is None:
                fb_range = _fallback_cost_range_ppg(db, ingredient, user_id, as_of_date, tz, region_id=region_id)
                if fb_range is not None:
                    _fb_min, _fb_max, unit_price = fb_range
                    fb_full = _get_ingredient_fallback(db, ingredient, user_id, region_id=region_id)
                    if fb_full:
                        _, _, fallback_chain = fb_full

            # 名称匹配：与 range 版对齐，用 _name_match_cost_range_ppg
            if unit_price is None:
                nm_range = _name_match_cost_range_ppg(db, ingredient, user_id, as_of_date, tz, region_id=region_id)
                if nm_range is not None:
                    _nm_min, _nm_max, unit_price = nm_range
                    # unit_price = avg_ppg，单位元/克

        # 尝试从制作菜谱推导成本（半成品，优先于子食材聚合）
        if not latest_record and unit_price is None:
            recipe_result = _get_cost_from_recipe(db, ingredient, user_id, as_of_date, visited, tz=tz, region_id=region_id)
            if recipe_result:
                unit_price, _mk_recipe, recipe_chain = recipe_result
                # unit_price 已经是元/克

        # 如果上述途径全部失败，尝试从包含关系的子食材中聚合成本
        if not latest_record and unit_price is None:
            child_agg = _get_aggregated_cost_from_children(db, ingredient, user_id, as_of_date, tz=tz, region_id=region_id)
            if child_agg:
                unit_price, aggregation_chain = child_agg
                # unit_price 已经是元/克

        if latest_record or unit_price is not None or aggregation_chain is not None or recipe_chain is not None:
            # 计算成本：单价 × 菜谱中的数量 = 成本
            # 计算成本：单价 × 菜谱中的数量 = 成本
            # 优先使用 quantity，如果为 None 则从 quantity_range 取平均值
            # 当使用 VAGUE_QUANTITY_GRAM_MAP 回退时，effective_unit_id 为克(3)
            quantity, effective_unit_id = _get_effective_quantity(recipe_ingredient)

            # 单位转换：将菜谱用量转换为价格记录的单位
            if quantity and effective_unit_id:
                if aggregation_chain is not None or recipe_chain is not None:
                    # 子食材聚合 或 制作菜谱 的 unit_price 是元/克，需要将菜谱用量转换为克
                    if effective_unit_id != 3:
                        recipe_unit = db.query(Unit).filter(Unit.id == effective_unit_id).first()
                        gram_unit = db.query(Unit).filter(Unit.id == 3).first()
                        if recipe_unit and gram_unit:
                            ucs = UnitConversionService(db)
                            converted = ucs.convert(
                                Decimal(str(quantity)),
                                recipe_unit.abbreviation,
                                gram_unit.abbreviation,
                                entity_type="ingredient",
                                entity_id=ingredient.id,
                            )
                            if converted:
                                quantity = float(converted[0])
                elif latest_record is None and unit_price is not None:
                    # 直接商品 range 版：unit_price 是元/克（同 recipe_chain/aggregation_chain），
                    # 将菜谱用量转换为克
                    if effective_unit_id != 3:
                        recipe_unit = db.query(Unit).filter(Unit.id == effective_unit_id).first()
                        gram_unit = db.query(Unit).filter(Unit.id == 3).first()
                        if recipe_unit and gram_unit:
                            ucs = UnitConversionService(db)
                            converted = ucs.convert(
                                Decimal(str(quantity)),
                                recipe_unit.abbreviation,
                                gram_unit.abbreviation,
                                entity_type="ingredient",
                                entity_id=ingredient.id,
                            )
                            if converted:
                                quantity = float(converted[0])
                elif latest_record:
                    price_unit_id = latest_record.standard_unit_id
                    recipe_unit_id = effective_unit_id
                    if price_unit_id and price_unit_id != recipe_unit_id:
                        price_unit = db.query(Unit).filter(Unit.id == price_unit_id).first()
                        recipe_unit = db.query(Unit).filter(Unit.id == recipe_unit_id).first()
                        if price_unit and recipe_unit:
                            ucs = UnitConversionService(db)
                            converted = ucs.convert(
                                Decimal(str(quantity)),
                                recipe_unit.abbreviation,
                                price_unit.abbreviation,
                                entity_type="ingredient",
                                entity_id=ingredient.id,
                            )
                            if converted:
                                quantity = float(converted[0])

            # 只有当数量大于0时才计算成本
            # 对于数量为0的食材，不计入成本（但可能需要显示在成本明细中）
            if quantity:
                try:
                    cost = unit_price * Decimal(str(quantity)) if unit_price else Decimal("0")
                    total_cost += cost

                    cost_breakdown.append({
                        "ingredient_name": ingredient.name,
                        "original_ingredient_name": original_ingredient_name,  # 添加原始食材名称
                        "ingredient_id": ingredient.id,
                        "recipe_ingredient_id": recipe_ingredient.id,  # 添加recipe_ingredient的ID
                        "quantity": str(quantity),
                        "unit_price": float(unit_price) if unit_price else 0.0,
                        "cost": float(cost),
                        "fallback_chain": fallback_chain,  # 回退链信息（如果有）
                        "aggregation_chain": aggregation_chain,  # 子食材聚合链信息（如果有）
                        "recipe_chain": recipe_chain,  # 制作菜谱链信息（如果有）
                        "cost_source": "recipe" if recipe_chain else ("contains_aggregation" if aggregation_chain else ("fallback" if fallback_chain else "direct"))
                    })
                except Exception as e:
                    # 数量解析失败，使用基础价格
                    cost = Decimal(str(latest_record.price))
                    total_cost += cost
                    cost_breakdown.append({
                        "ingredient_name": ingredient.name,
                        "ingredient_id": ingredient.id,
                        "recipe_ingredient_id": recipe_ingredient.id,  # 添加recipe_ingredient的ID
                        "quantity": "1",  # 默认为1
                        "unit_price": float(latest_record.price),
                        "cost": float(cost),
                        "fallback_chain": fallback_chain,  # 回退链信息（如果有）
                        "aggregation_chain": aggregation_chain,  # 子食材聚合链信息（如果有）
                        "recipe_chain": recipe_chain,  # 制作菜谱链信息（如果有）
                        "cost_source": "recipe" if recipe_chain else ("contains_aggregation" if aggregation_chain else ("fallback" if fallback_chain else "direct"))
                    })
            else:
                # 对于数量为0的食材，我们仍然添加到明细中但成本为0
                # 这样用户可以看到所有食材，即使它们的数量为0
                cost_breakdown.append({
                    "ingredient_name": ingredient.name,
                    "original_ingredient_name": original_ingredient_name,  # 添加原始食材名称
                    "ingredient_id": ingredient.id,
                    "recipe_ingredient_id": recipe_ingredient.id,  # 添加recipe_ingredient的ID
                    "quantity": str(quantity),
                    "unit_price": float(unit_price) if unit_price else 0.0,
                    "cost": 0.0,
                    "fallback_chain": fallback_chain,  # 回退链信息（如果有）
                    "aggregation_chain": aggregation_chain,  # 子食材聚合链信息（如果有）
                    "recipe_chain": recipe_chain,  # 制作菜谱链信息（如果有）
                    "cost_source": "recipe" if recipe_chain else ("contains_aggregation" if aggregation_chain else ("fallback" if fallback_chain else "direct"))
                })

    from app.services.currency_service import get_user_default_currency
    return {
        "total_cost": total_cost,
        "currency": get_user_default_currency(db, db.query(User).filter(User.id == user_id).first()),
        "cost_per_serving": total_cost / (recipe.servings or 1),
        "cost_breakdown": cost_breakdown
    }


def calculate_recipe_cost_trend(
    recipe_id: int,
    user_id: int,
    db: Session,
    days: int = 90,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> List[Dict]:
    """
    计算菜谱的成本趋势

    遍历指定日期范围，对于每一天，计算菜谱在该日期的成本。
    使用该日期之前的价格记录计算成本（向前查找）。

    Args:
        recipe_id: 菜谱ID
        user_id: 用户ID
        db: 数据库会话
        days: 查询天数（默认90天）

    Returns:
        成本趋势数据列表，每条记录包含：
        - date: 日期 (YYYY-MM-DD)
        - recorded_at: Unix 时间戳（秒）
        - total_cost: 总成本（分）
        - avg_cost: 平均成本（元）
    """
    recipe = db.query(Recipe).filter(Recipe.id == recipe_id).first()
    if not recipe:
        return []

    # 获取菜谱中的所有食材
    recipe_ingredients = db.query(RecipeIngredient).filter(
        RecipeIngredient.recipe_id == recipe_id,
        RecipeIngredient.is_optional != True  # 排除可选食材
    ).all()

    if not recipe_ingredients:
        return []

    # 获取最早的价格记录日期（跨用户公开价格）
    earliest_record = db.query(ProductRecord).order_by(
        ProductRecord.recorded_at.asc()
    ).first()

    if not earliest_record:
        return []

    # 确定日期范围
    end_date = utc_datetime_to_local_date(datetime.now(timezone.utc), tz)
    start_date = max(utc_datetime_to_local_date(earliest_record.recorded_at, tz), end_date - timedelta(days=days))

    # 生成日期列表
    date_list = []
    current_date = start_date
    while current_date <= end_date:
        date_list.append(current_date)
        current_date += timedelta(days=1)

    # 计算每一天的成本
    cost_trend = []
    for date in date_list:
        # 计算该日期 23:59:59 的成本（使用截至当天的最新价格）
        _, as_of_datetime = local_date_range_to_utc_range(date, date, tz)

        # 调用成本计算函数（不是 async）
        cost_result = calculate_recipe_cost_as_of(
            recipe_id, user_id, as_of_datetime, db, region_id=region_id
        )

        if cost_result and cost_result["total_cost"]:
            total_cost = cost_result["total_cost"]

            # 转换为分（整数存储）
            total_cost_cents = int(total_cost * 100)

            # 转换为 Unix 时间戳（使用当天 12:00）
            recorded_at = int((local_date_range_to_utc_range(date, date, tz)[0] + timedelta(hours=12)).replace(tzinfo=timezone.utc).timestamp())

            cost_trend.append({
                "date": date.strftime("%Y-%m-%d"),
                "recorded_at": recorded_at,
                "total_cost": total_cost_cents,
                "avg_cost": float(total_cost)
            })

    return cost_trend
