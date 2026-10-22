"""商品/原料数量关联 API Schema。"""
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, Field


class EntityQuantityLinkCreate(BaseModel):
    to_type: str = Field(..., pattern="^(product|ingredient)$")
    to_id: int
    from_quantity: Decimal = Field(Decimal("1"), gt=0, le=Decimal("1000000"))
    from_unit: str = Field(..., min_length=1, max_length=50)
    to_quantity: Decimal = Field(Decimal("1"), gt=0, le=Decimal("1000000"))
    to_unit: str = Field(..., min_length=1, max_length=50)
    note: Optional[str] = Field(None, max_length=200)


class EntityQuantityLinkUpdate(BaseModel):
    from_quantity: Optional[Decimal] = Field(None, gt=0, le=Decimal("1000000"))
    from_unit: Optional[str] = Field(None, min_length=1, max_length=50)
    to_quantity: Optional[Decimal] = Field(None, gt=0, le=Decimal("1000000"))
    to_unit: Optional[str] = Field(None, min_length=1, max_length=50)
    note: Optional[str] = Field(None, max_length=200)


class EntityLinkSideOut(BaseModel):
    type: str
    id: int
    name: Optional[str] = None
    quantity: float
    unit: str
    ingredient_id: Optional[int] = None


class EntityQuantityLinkOut(BaseModel):
    id: int
    current: EntityLinkSideOut
    other: EntityLinkSideOut
    other_per_current: float
    current_per_other: float
    grams_per_current_unit: Optional[float] = None
    grams_per_other_unit: Optional[float] = None
    price_factor_current_to_other: Optional[float] = None
    resolvable: bool = False
    note: Optional[str] = None
    other_latest_price: Optional[float] = None
    other_latest_price_unit: Optional[str] = None
    equivalent_current_price: Optional[float] = None
    price_date: Optional[str] = None
    is_stale: bool = False
    pending: bool = False


class EntityQuantityLinkEnvelope(BaseModel):
    items: list[EntityQuantityLinkOut] = Field(default_factory=list)
