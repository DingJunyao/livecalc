"""币种与地区推导服务。"""
from sqlalchemy.orm import Session

DEFAULT_CURRENCY = "CNY"


def currency_symbol(db: Session, code: str) -> str:
    from app.models.currency import Currency

    if not code:
        return DEFAULT_CURRENCY
    c = db.query(Currency).filter(Currency.code == code).first()
    return c.symbol if c and c.symbol else code


def get_region_default_currency(db: Session, region) -> str:
    """沿行政区划祖先链找到国家节点，取其默认币种；兜底全局默认。"""
    from app.models.administrative_region import AdministrativeRegion
    from app.models.region_unit_setting import RegionUnitSetting

    node = region
    while node is not None:
        iso = getattr(node, "iso_country", None)
        if iso:
            rs = db.query(RegionUnitSetting).filter(RegionUnitSetting.region_code == iso).first()
            if rs and rs.default_currency:
                return rs.default_currency
        if getattr(node, "parent_id", None) is None:
            break
        node = db.query(AdministrativeRegion).filter(AdministrativeRegion.id == node.parent_id).first()
    return DEFAULT_CURRENCY


def get_merchant_default_currency(db: Session, merchant) -> str:
    if getattr(merchant, "default_currency", None):
        return merchant.default_currency
    if getattr(merchant, "region_id", None):
        from app.models.administrative_region import AdministrativeRegion
        region = db.query(AdministrativeRegion).filter(AdministrativeRegion.id == merchant.region_id).first()
        if region:
            return get_region_default_currency(db, region)
    return DEFAULT_CURRENCY


def get_user_default_currency(db: Session, user, *, ignore_session: bool = False) -> str:
    if not ignore_session:
        from app.services.session_context import get_session_currency
        sess = get_session_currency()
        if sess:
            return sess
    if getattr(user, "default_currency", None):
        return user.default_currency
    if getattr(user, "region_id", None):
        from app.models.administrative_region import AdministrativeRegion
        region = db.query(AdministrativeRegion).filter(AdministrativeRegion.id == user.region_id).first()
        if region:
            return get_region_default_currency(db, region)
    return DEFAULT_CURRENCY


def recompute_user_records(db: Session, user_id: int, new_currency: str) -> dict:
    """用户有效币种变化后，按其记录日期重算所有价格记录的 exchange_rate/user_currency 快照。

    幂等；单条缺历史汇率快照时跳过并保留原值（下次再补）。
    """
    from datetime import date
    from decimal import Decimal

    from app.models.product import ProductRecord
    from app.scripts.recompute_user_currency import compute_exchange_factor

    records = db.query(ProductRecord).filter(
        ProductRecord.user_id == user_id,
        ProductRecord.is_active == True,  # noqa: E712
    ).all()
    updated = skipped = 0
    for r in records:
        try:
            if not r.currency or r.currency == new_currency:
                rate = Decimal("1")
            else:
                d = r.recorded_at.date() if r.recorded_at else date.today()
                rate = compute_exchange_factor(db, r.currency, new_currency, d)
            r.exchange_rate = rate
            r.user_currency = new_currency
            updated += 1
        except Exception:
            skipped += 1  # 缺历史汇率快照，保留原值
    if updated:
        db.commit()
    return {"updated": updated, "skipped": skipped}


def ensure_user_currency_snapshots(db: Session) -> dict:
    """启动时把各用户价格记录快照对齐到其当前有效币种（幂等：不一致才重算）。"""
    from sqlalchemy import or_

    from app.models.product import ProductRecord
    from app.models.user import User

    user_ids = [
        row[0]
        for row in db.query(ProductRecord.user_id)
        .filter(ProductRecord.user_id.isnot(None))
        .distinct()
        .all()
    ]
    results = {"users": 0, "updated": 0, "skipped": 0}
    for uid in user_ids:
        user = db.query(User).filter(User.id == uid).first()
        if user is None:
            continue
        effective = get_user_default_currency(db, user)
        stale = db.query(ProductRecord.id).filter(
            ProductRecord.user_id == uid,
            ProductRecord.is_active == True,  # noqa: E712
            or_(
                ProductRecord.user_currency.is_(None),
                ProductRecord.user_currency != effective,
            ),
        ).first()
        if stale is None:
            continue
        results["users"] += 1
        res = recompute_user_records(db, uid, effective)
        results["updated"] += res["updated"]
        results["skipped"] += res["skipped"]
    return results
