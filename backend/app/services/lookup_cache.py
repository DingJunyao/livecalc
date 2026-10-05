"""请求级只读查询缓存（单位表 / 实体单位覆盖 / 密度 / 地区子树 / 地区默认币种）。

价格计算路径（菜谱成本、趋势、sparkline）会在一次请求内以几千次量级
重复读取同一批准静态小表；本模块把这些读取挂在 ``db.info`` 上
（SQLAlchemy Session 官方扩展点），生命周期与 Session（= 一次请求）一致：

- GET 计算路径内无写入，缓存天然安全；
- 写路径无需逐端点插失效钩子——模块底部注册 ``before_flush`` 事件，
  flush 中出现 Unit / EntityUnitOverride / EntityDensity /
  AdministrativeRegion / Product 实例时自动清空对应缓存。

缓存返回的是 ORM 实例本身，与直查完全同源，不改变任何计算语义。
"""
from typing import Optional

from sqlalchemy import event
from sqlalchemy.orm import Session

from app.models.unit import Unit

_CACHE_KEY = "_livecalc_lookup_cache"


def _cache(db: Session) -> dict:
    c = db.info.get(_CACHE_KEY)
    if c is None:
        c = {
            "unit_by_id": {},          # int -> Unit | None
            "unit_by_abbr": {},        # str -> Unit | None
            "overrides": {},           # (entity_type, entity_id) -> dict[unit_name -> override] | None
            "densities": {},           # (entity_type, entity_id) -> Decimal
            "product_ingredient_id": {},  # product_id -> ingredient_id | None（直连 + link 回退合并结果）
            "products_for_ingredient": {},  # ingredient_id -> list[Product]
        }
        db.info[_CACHE_KEY] = c
    return c


def clear(db: Session) -> None:
    """清空该 session 的全部请求级缓存（写路径失效钩子调用）。"""
    db.info.pop(_CACHE_KEY, None)
    db.info.pop(_region_cache_key(), None)


def unit_by_id(db: Session, unit_id) -> Optional[Unit]:
    if unit_id is None:
        return None
    c = _cache(db)
    if unit_id not in c["unit_by_id"]:
        c["unit_by_id"][unit_id] = db.query(Unit).filter(Unit.id == unit_id).first()
    return c["unit_by_id"][unit_id]


def unit_by_abbr(db: Session, abbreviation: str) -> Optional[Unit]:
    if not abbreviation:
        return None
    c = _cache(db)
    if abbreviation not in c["unit_by_abbr"]:
        c["unit_by_abbr"][abbreviation] = db.query(Unit).filter(
            Unit.abbreviation == abbreviation
        ).first()
    return c["unit_by_abbr"][abbreviation]


def unit_si_base(db: Session, unit_type: str) -> Optional[Unit]:
    """某类型的 SI 基准单位（mass→kg / volume→L），请求级缓存。

    与 ``filter(unit_type==x, is_si_base==True).first()`` 同源。"""
    c = _cache(db)
    bucket = c.setdefault("unit_si_base", {})
    if unit_type not in bucket:
        unit = (
            db.query(Unit)
            .filter(Unit.unit_type == unit_type, Unit.is_si_base == True)  # noqa: E712
            .first()
        )
        if unit is None and unit_type == "mass":
            # 兜底：无 is_si_base 标记时取 si_factor=1（与 convert_volume_to_mass 原逻辑一致）
            unit = (
                db.query(Unit)
                .filter(Unit.unit_type == unit_type, Unit.si_factor == 1)
                .first()
            )
        bucket[unit_type] = unit
    return bucket[unit_type]


def entity_override_map(db: Session, entity_type: str, entity_id: int) -> Optional[dict]:
    """某实体的全部 active 单位覆盖：{unit_name: EntityUnitOverride}；无记录缓存 None。

    与逐条 ``filter(unit_name==x).first()`` 同源（同一实体同一过滤条件集合），
    只是合并为一次查询。调用方按 unit_name 取值即可。
    """
    if not entity_type or entity_id is None:
        return None
    c = _cache(db)
    key = (entity_type, entity_id)
    if key not in c["overrides"]:
        rows = db.query(_override_model()).filter(
            _override_model().entity_type == entity_type,
            _override_model().entity_id == entity_id,
            _override_model().is_active.is_(True),
        ).all()
        # 同名多行时保留第一行，与逐条查询 .first() 的取行语义一致
        m: dict = {}
        for r in rows:
            if r.unit_name not in m:
                m[r.unit_name] = r
        c["overrides"][key] = m or None
    return c["overrides"][key]


def entity_density(db: Session, entity_type: str, entity_id: int):
    """EntityDensity 查询缓存；无记录不缓存（需区分 None 与「默认水密度」由调用方处理）。"""
    from app.models.entity_density import EntityDensity
    c = _cache(db)
    key = (entity_type, entity_id)
    if key not in c["densities"]:
        row = (
            db.query(EntityDensity)
            .filter(
                EntityDensity.entity_type == entity_type,
                EntityDensity.entity_id == entity_id,
                EntityDensity.is_active.is_(True),
            )
            .order_by(EntityDensity.confidence.desc())
            .first()
        )
        c["densities"][key] = row.density if row is not None else False  # False = 无记录（可缓存）
    return c["densities"][key]


def product_ingredient_id(db: Session, product_id: int) -> Optional[int]:
    """商品的关联原料 id：直连 ingredient_id 优先，link 表回退。结果缓存。"""
    from app.models.product_entity import Product
    from app.models.product_ingredient_link import ProductIngredientLink

    c = _cache(db)
    if product_id not in c["product_ingredient_id"]:
        product = db.query(Product).filter(Product.id == product_id).first()
        ing_id = product.ingredient_id if product is not None else None
        if ing_id is None:
            link = (
                db.query(ProductIngredientLink)
                .filter(ProductIngredientLink.product_id == product_id)
                .first()
            )
            ing_id = link.ingredient_id if link is not None else None
        c["product_ingredient_id"][product_id] = ing_id
    return c["product_ingredient_id"][product_id]


def active_products_for_ingredient(db: Session, ingredient_id: int) -> list:
    """原料下的全部 active 商品（与 ``Product.ingredient_id==x, is_active`` 直查同源）。

    成本计算对同一原料会在 direct 层（外层判断 + 加权服务）反复取该列表，
    请求级缓存后每原料只查一次。写 Product 时由失效钩子清空。
    """
    from app.models.product_entity import Product

    c = _cache(db)
    bucket = c.setdefault("products_for_ingredient", {})
    if ingredient_id not in bucket:
        bucket[ingredient_id] = (
            db.query(Product)
            .filter(Product.ingredient_id == ingredient_id, Product.is_active == True)  # noqa: E712
            .all()
        )
    return bucket[ingredient_id]


def hierarchy_all(db: Session) -> list:
    """ingredient_hierarchies 全表（小表，趋势计算按原料反复过滤）。写路径由失效钩子清空。"""
    from app.models.ingredient_hierarchy import IngredientHierarchy

    c = _cache(db)
    if "hierarchy_all" not in c:
        c["hierarchy_all"] = db.query(IngredientHierarchy).filter(
            IngredientHierarchy.is_active == True  # noqa: E712
        ).all()
    return c["hierarchy_all"]


def making_recipe_for_ingredient(db: Session, ingredient_id: int):
    """反查把该原料当成品产出的 active 菜谱（半成品成本传递用），结果缓存。"""
    from app.models.recipe import Recipe

    c = _cache(db)
    bucket = c.setdefault("making_recipe", {})
    if ingredient_id not in bucket:
        bucket[ingredient_id] = (
            db.query(Recipe)
            .filter(Recipe.result_ingredient_id == ingredient_id, Recipe.is_active == True)  # noqa: E712
            .first()
        )
    return bucket[ingredient_id]


def memoize_result(db: Session, namespace: str, key, factory):
    """通用请求级结果缓存：key 未命中时调 factory() 并缓存（含 None/空结果）。

    用于与 as_of 无关的派生结果（如 _get_ingredient_fallback 的回退链选择、
    份重折克），90 天趋势循环里每天重算完全相同。
    """
    c = _cache(db)
    bucket = c.setdefault(f"memo:{namespace}", {})
    if key not in bucket:
        bucket[key] = factory()
    return bucket[key]


def _override_model():
    from app.models.entity_unit_override import EntityUnitOverride
    return EntityUnitOverride


def _region_cache_key():
    return "_livecalc_region_subtree_cache"


def _install_invalidation_hook() -> None:
    """flush 中出现相关实体写入时自动清缓存，覆盖所有写端点与 importer。"""

    @event.listens_for(Session, "before_flush")
    def _invalidate(session, flush_context, instances):
        targets = _invalidating_type_set()
        for obj in session.new:
            if type(obj) in targets:
                clear(session)
                return
        for obj in session.dirty:
            if type(obj) in targets:
                clear(session)
                return


_INVALIDATING_TYPES = None  # 延迟初始化，避免模块导入期循环依赖


def _invalidating_type_set():
    global _INVALIDATING_TYPES
    if _INVALIDATING_TYPES is None:
        from app.models.administrative_region import AdministrativeRegion
        from app.models.entity_density import EntityDensity
        from app.models.entity_unit_override import EntityUnitOverride
        from app.models.product_entity import Product
        from app.models.product_ingredient_link import ProductIngredientLink
        from app.models.ingredient_hierarchy import IngredientHierarchy
        from app.models.recipe import Recipe
        from app.models.nutrition import Ingredient
        from app.models.product import ProductRecord

        _INVALIDATING_TYPES = {
            Unit, EntityUnitOverride, EntityDensity,
            AdministrativeRegion, Product, ProductIngredientLink,
            IngredientHierarchy, Recipe, Ingredient, ProductRecord,
        }
    return _INVALIDATING_TYPES


_install_invalidation_hook()
