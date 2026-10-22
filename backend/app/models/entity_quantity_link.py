"""商品/原料之间的数量关联。

一条关联就是一句等式：

    from_quantity [from_unit] of from_entity
        = to_quantity [to_unit] of to_entity

例如「1 提 五连包 = 5 包 单包」或「3 kg 鲜香菇 = 1 kg 干香菇」。

设计约束（与旧包装组方案的区别）：
- 不合并商品/原料，不引入「基准 / 成员 / 组」；
- 关联只用于单位折克和缺价时的价格折算，不写回真实价格记录；
- 多态端点（product / ingredient）不做 DB 外键，应用层校验存在性与 active。
"""
from sqlalchemy import Column, Index, Integer, Numeric, String
from app.core.base_model import AuditMixin
from app.core.database import Base


class EntityQuantityLink(Base, AuditMixin):
    """两两数量关联（双向可用）。"""

    __tablename__ = "entity_quantity_links"

    id = Column(Integer, primary_key=True, index=True)
    from_type = Column(String(20), nullable=False)  # product | ingredient
    from_id = Column(Integer, nullable=False)
    from_quantity = Column(Numeric(15, 6), nullable=False, default=1)
    from_unit = Column(String(50), nullable=False)
    to_type = Column(String(20), nullable=False)  # product | ingredient
    to_id = Column(Integer, nullable=False)
    to_quantity = Column(Numeric(15, 6), nullable=False, default=1)
    to_unit = Column(String(50), nullable=False)
    note = Column(String(200), nullable=True)

    __table_args__ = (
        Index("ix_entity_quantity_link_from", "from_type", "from_id"),
        Index("ix_entity_quantity_link_to", "to_type", "to_id"),
        Index(
            "ix_entity_quantity_link_from_active",
            "from_type", "from_id", "is_active",
        ),
        Index(
            "ix_entity_quantity_link_to_active",
            "to_type", "to_id", "is_active",
        ),
    )

    def __repr__(self):  # pragma: no cover - 调试用
        return (
            f"<EntityQuantityLink(id={self.id}, "
            f"{self.from_type}/{self.from_id} {self.from_quantity}{self.from_unit} = "
            f"{self.to_type}/{self.to_id} {self.to_quantity}{self.to_unit})>"
        )
