from sqlalchemy import Column, Integer, String, Text, DateTime, UniqueConstraint
from sqlalchemy.sql import func
from app.core.database import Base


class EmailTemplate(Base):
    """邮件模板配置。"""
    __tablename__ = "email_templates"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String(50), nullable=False)
    locale = Column(String(10), nullable=False, default="zh-CN", server_default="zh-CN")
    name = Column(String(100), nullable=False)
    subject = Column(String(255), nullable=False)
    body_html = Column(Text, nullable=False)
    description = Column(String(500), default="")
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("key", "locale", name="uq_email_templates_key_locale"),
    )
