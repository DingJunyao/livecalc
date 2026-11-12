"""用户自定义计算范围（多地区组合）。

语义：一个范围 = 名称 + 一组行政区划 id（层级可混合，如一个县 + 一个地级市）。
计算时按各地区子树（path 前缀）展开取并集去重过滤价格记录（见
app/services/price_region.py）。region_ids 存 JSON 数组，地区存在性由 API 层
校验（administrative_regions 由种子任务维护）。

用户可在「默认计算范围」中选用：users.default_calc_scope_id 指向本表，
与既有 default_calc_scope 层级档位互斥写入（设一方清另一方，见 patch_me）。
删除范围时由 API 层清空引用（users.default_calc_scope_id → NULL）。
"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, JSON, UniqueConstraint
from sqlalchemy.sql import func
from app.core.database import Base


class UserCalcScope(Base):
    __tablename__ = "user_calc_scopes"
    __table_args__ = (
        UniqueConstraint("user_id", "name", name="uq_user_calc_scopes"),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    region_ids = Column(JSON, nullable=False, default=list)  # administrative_regions.id 列表
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
