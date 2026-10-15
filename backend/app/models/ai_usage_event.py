"""AI 用量事件（轻量留痕，为配额与计费准备数据；设计 §4.8）。

status: ok（AI 输出通过校验）/ fallback（调用了但降级规则）/ error（调用异常）。
"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.sql import func
from app.core.database import Base


class AiUsageEvent(Base):
    __tablename__ = "ai_usage_events"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    scope = Column(String(40), nullable=False)  # 如 meal_plan
    method = Column(String(20), nullable=False)  # system_ai | user_ai
    provider = Column(String(20), nullable=True)
    status = Column(String(20), nullable=False)  # ok | fallback | error
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
