"""币种与汇率 API。"""
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
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


@router.get("/currencies")
def list_currencies(db: Session = Depends(get_db), _=Depends(get_current_user)):
    rows = db.query(Currency).filter(Currency.is_active == True).order_by(Currency.code).all()  # noqa: E712
    return [{"code": r.code, "name": r.name, "symbol": r.symbol, "decimals": r.decimals} for r in rows]


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
