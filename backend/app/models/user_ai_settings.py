"""用户级 AI 设置（通用，不限餐食推荐；设计 §4.8）。

method = NULL 表示跟随全局默认；user_ai 时 provider/base_url/model/api_key_enc 生效。
api_key_enc 为 Fernet 加密（key 由 SECRET_KEY 派生，见 services/ai_policy.py），
接口只回显打码值。
"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.sql import func
from app.core.database import Base


class UserAiSettings(Base):
    __tablename__ = "user_ai_settings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    method = Column(String(20), nullable=True)  # NULL = 跟随全局；rule|system_ai|user_ai
    provider = Column(String(20), nullable=True)  # user_ai 用：openai | anthropic
    base_url = Column(String(200), nullable=True)
    api_key_enc = Column(String(500), nullable=True)
    model = Column(String(100), nullable=True)
    daily_ai_limit_override = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
