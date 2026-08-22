from sqlalchemy import Column, DateTime, String, Text
from sqlalchemy.sql import func

from app.core.database import Base


class BarcodeLookupCache(Base):
    """Successful external barcode lookup payload cache."""

    __tablename__ = "barcode_lookup_cache"

    barcode = Column(String(50), primary_key=True)
    payload = Column(Text, nullable=False)
    source = Column(String(100), nullable=False)
    fetched_at = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    expires_at = Column(DateTime(timezone=True), nullable=False, index=True)
