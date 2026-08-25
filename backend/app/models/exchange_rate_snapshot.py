from sqlalchemy import Column, Integer, String, Date, DateTime, UniqueConstraint
from sqlalchemy.dialects.sqlite import JSON as SQLiteJSON
from sqlalchemy.ext.mutable import MutableDict
from sqlalchemy.sql import func
from app.core.database import Base


class ExchangeRateSnapshot(Base):
    __tablename__ = "exchange_rate_snapshots"
    __table_args__ = (UniqueConstraint("rate_date", "base_currency", name="uq_snapshot_date_base"),)

    id = Column(Integer, primary_key=True, index=True)
    rate_date = Column(Date, nullable=False, index=True)
    base_currency = Column(String(3), nullable=False)
    rates = Column(MutableDict.as_mutable(SQLiteJSON), nullable=False, default=dict)
    source = Column(String(50))
    fetched_at = Column(DateTime(timezone=True), server_default=func.now())
