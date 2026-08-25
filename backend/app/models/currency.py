from sqlalchemy import Column, Integer, String, Boolean
from app.core.database import Base


class Currency(Base):
    __tablename__ = "currencies"

    code = Column(String(3), primary_key=True)
    name = Column(String(100), nullable=False)
    symbol = Column(String(10))
    decimals = Column(Integer, nullable=False, default=2)
    is_active = Column(Boolean, nullable=False, default=True)
