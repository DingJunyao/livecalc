"""币种与汇率 API。"""
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user, get_current_admin_user
from app.models.currency import Currency
from app.services import exchange_rate_service
from app.services.exchange_rate_service import get_snapshot, store_snapshot

router = APIRouter()


class ManualRateIn(BaseModel):
    rate_date: date
    base_currency: str
    rates: dict[str, float]


class CurrencyIn(BaseModel):
    code: str = Field(pattern=r"^[A-Z]{3}$", description="3 位大写字母币种代码")
    name: str
    symbol: str | None = None
    decimals: int = 2
    is_active: bool = True


class CurrencyUpdate(BaseModel):
    name: str | None = None
    symbol: str | None = None
    decimals: int | None = None
    is_active: bool | None = None


def _currency_dict(cur: Currency) -> dict:
    return {
        "code": cur.code,
        "name": cur.name,
        "symbol": cur.symbol,
        "decimals": cur.decimals,
        "is_active": cur.is_active,
    }


@router.get("/currencies")
def list_currencies(db: Session = Depends(get_db), _=Depends(get_current_user)):
    rows = db.query(Currency).filter(Currency.is_active == True).order_by(Currency.code).all()  # noqa: E712
    return [{"code": r.code, "name": r.name, "symbol": r.symbol, "decimals": r.decimals} for r in rows]


@router.get("/admin/currencies")
def list_admin_currencies(db: Session = Depends(get_db), _=Depends(get_current_admin_user)):
    """管理员：列出全部币种（含停用），供管理页维护。"""
    rows = db.query(Currency).order_by(Currency.code).all()
    return [_currency_dict(r) for r in rows]


@router.post("/admin/currencies")
def upsert_currency(body: CurrencyIn, db: Session = Depends(get_db), _=Depends(get_current_admin_user)):
    """管理员：upsert 币种（存在则更新，不存在则创建）。"""
    cur = db.query(Currency).filter(Currency.code == body.code).first()
    if cur:
        cur.name = body.name
        cur.symbol = body.symbol
        cur.decimals = body.decimals
        cur.is_active = body.is_active
    else:
        cur = Currency(
            code=body.code,
            name=body.name,
            symbol=body.symbol,
            decimals=body.decimals,
            is_active=body.is_active,
        )
        db.add(cur)
    db.commit()
    db.refresh(cur)
    return _currency_dict(cur)


@router.put("/admin/currencies/{code}")
def update_currency(code: str, body: CurrencyUpdate, db: Session = Depends(get_db), _=Depends(get_current_admin_user)):
    """管理员：部分更新币种（name/symbol/decimals/is_active）。"""
    cur = db.query(Currency).filter(Currency.code == code).first()
    if not cur:
        raise HTTPException(status_code=404, detail="币种不存在")
    data = body.model_dump(exclude_unset=True)
    if "name" in data and data["name"] is not None:
        cur.name = data["name"]
    if "symbol" in data:
        cur.symbol = data["symbol"]
    if "decimals" in data and data["decimals"] is not None:
        cur.decimals = data["decimals"]
    if "is_active" in data and data["is_active"] is not None:
        cur.is_active = data["is_active"]
    db.commit()
    db.refresh(cur)
    return _currency_dict(cur)


@router.delete("/admin/currencies/{code}")
def delete_currency(code: str, db: Session = Depends(get_db), _=Depends(get_current_admin_user)):
    """管理员：软删除币种（is_active=False）。"""
    cur = db.query(Currency).filter(Currency.code == code).first()
    if not cur:
        raise HTTPException(status_code=404, detail="币种不存在")
    cur.is_active = False
    db.commit()
    return {"code": cur.code, "is_active": False}


@router.get("/exchange-rates/status")
def status(db: Session = Depends(get_db), _=Depends(get_current_user)):
    snap = get_snapshot(db, date.today(), "EUR")
    return {"latest": snap.rate_date.isoformat() if snap else None, "source": snap.source if snap else None}


@router.post("/admin/exchange-rates/refresh")
def refresh(db: Session = Depends(get_db), _=Depends(get_current_admin_user)):
    try:
        return exchange_rate_service.fetch_and_store_daily(db)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"汇率拉取失败: {str(e)}")


@router.post("/admin/exchange-rates/manual")
def manual(body: ManualRateIn, db: Session = Depends(get_db), _=Depends(get_current_admin_user)):
    rates = {k: float(v) for k, v in body.rates.items()}
    snap = store_snapshot(db, body.rate_date, body.base_currency, rates, source="manual")
    db.commit()
    return {"date": snap.rate_date.isoformat(), "base": snap.base_currency, "count": len(snap.rates)}
