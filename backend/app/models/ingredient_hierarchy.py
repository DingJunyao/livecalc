from enum import Enum
from sqlalchemy import Column, Integer, String, DateTime, Numeric, ForeignKey, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.core.base_model import AuditMixin


class HierarchyRelationType(Enum):
    CONTAINS = "contains"          # 包含关系（父类包含子类）
    SUBSTITUTABLE = "substitutable" # 可替代关系（可以相互替代）
    FALLBACK = "fallback"          # 回退关系（找不到子类时可用父类替代）


class IngredientHierarchy(Base, AuditMixin):
    """食材层级关系模型"""

    __tablename__ = "ingredient_hierarchies"

    id = Column(Integer, primary_key=True, index=True)
    parent_id = Column(Integer, ForeignKey("ingredients.id"), nullable=False, index=True)
    child_id = Column(Integer, ForeignKey("ingredients.id"), nullable=False, index=True)
    relation_type = Column(String(20), nullable=False)  # 关系类型
    strength = Column(Integer, default=50)  # 关系强度（0-100）

    # 可选换算系数（NULL = 1:1，与历史行为一致）。
    # 语义：factor_parent_quantity [factor_parent_unit] 父 = factor_child_quantity [factor_child_unit] 子
    # 例：1 kg 干(父) = 3 kg 鲜(子) → 子缺价时 ppg_子 = ppg_父 × (q父×g父)/(q子×g子) = ppg_父 / 3
    factor_parent_quantity = Column(Numeric(15, 6), nullable=True)
    factor_parent_unit = Column(String(50), nullable=True)
    factor_child_quantity = Column(Numeric(15, 6), nullable=True)
    factor_child_unit = Column(String(50), nullable=True)

    # 关系
    parent = relationship("Ingredient", foreign_keys=[parent_id], back_populates="hierarchy_children")
    child = relationship("Ingredient", foreign_keys=[child_id], back_populates="hierarchy_parents")