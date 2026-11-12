"""用户自定义计算范围 Pydantic 模型。"""
from typing import Optional

from pydantic import BaseModel, Field


class CalcScopeRegionItem(BaseModel):
    """范围内单个行政区划（供前端展示/回填，display_name 按请求语言）"""
    id: int
    name: str
    display_name: str
    level: int


class CalcScopeResponse(BaseModel):
    id: int
    name: str
    region_ids: list[int]
    regions: list[CalcScopeRegionItem] = []
    is_default: bool = False  # 是否为当前用户默认计算范围（users.default_calc_scope_id 派生）


class CalcScopeCreate(BaseModel):
    """创建自定义计算范围。业务校验（非空/去重/存在性/限额）在端点内做，400 返回。"""
    name: str = Field(..., max_length=100)
    region_ids: list[int]


class CalcScopeUpdate(BaseModel):
    """更新自定义计算范围。字段全部可选，传了才改。"""
    name: Optional[str] = Field(None, max_length=100)
    region_ids: Optional[list[int]] = None
