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


def get_user_default_currency(db: Session, user) -> str:
    if getattr(user, "default_currency", None):
        return user.default_currency
    if getattr(user, "region_id", None):
        from app.models.administrative_region import AdministrativeRegion
        region = db.query(AdministrativeRegion).filter(AdministrativeRegion.id == user.region_id).first()
        if region:
            return get_region_default_currency(db, region)
    return DEFAULT_CURRENCY
