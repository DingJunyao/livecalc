"""跨地区物价对比的响应 schema。"""
from typing import Dict, List, Optional

from pydantic import BaseModel


class RegionCandidate(BaseModel):
    """有价格记录的地区候选。"""

    region_id: int
    code: Optional[str] = None
    name: str
    name_en: Optional[str] = None
    display_name: str
    level: int
    path: Optional[str] = None
    record_count: int
    merchant_count: int


class RegionCandidatesResponse(BaseModel):
    regions: List[RegionCandidate]


class RegionSummaryItem(BaseModel):
    """单地区概览：记录/商品规模 + 物价指数 + 篮子日均价趋势。"""

    region_id: int
    name: str
    display_name: str
    record_count: int
    entity_count: int
    # 物价指数：基准地区=100，共同商品单价比率的中位数 ×100；无共同商品时为 None
    price_index: Optional[float] = None
    # 共同商品篮子的日均价序列（¥/斤，用户币种，前向填充到今天）
    trend: List[float] = []


class ComparisonSummaryResponse(BaseModel):
    currency: str
    base_region_id: int
    basket_size: int
    regions: List[RegionSummaryItem]


class EntityRegionPrice(BaseModel):
    """单实体×单地区：卡片价（每标准单位，与综合价同口径）+ 趋势（¥/斤）。"""

    price: Optional[float] = None
    is_stale: bool = False
    days_since_record: Optional[int] = None
    participant_count: int = 0
    unit: Optional[str] = None
    trend: List[float] = []


class EntityPriceRow(BaseModel):
    entity_id: int
    name: str
    unit: Optional[str] = None
    # 键为 region_id 字符串；该地区无数据时值为 None
    regions: Dict[str, Optional[EntityRegionPrice]]


class RegionMeta(BaseModel):
    """对比涉及的地区元数据（前端渲染列头/卡片名用）。"""

    region_id: int
    name: str
    display_name: str
    level: int


class EntityPricesResponse(BaseModel):
    currency: str
    # 趋势序列的归一单位（¥/斤，与列表迷你图同口径）
    trend_unit: str = "斤"
    regions: List[RegionMeta] = []
    entities: List[EntityPriceRow]
