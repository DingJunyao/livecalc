"""请求级会话上下文：X-Currency 临时币种覆盖（仅当前请求有效，不落库）。

前端在导航栏临时切换币种后，通过请求头 X-Currency 下发；后端在价格计算
与序列化时按「用户币种 → 会话币种」当日汇率折算，用户配置不变。
"""
from contextvars import ContextVar
from typing import Optional

_session_currency: ContextVar[Optional[str]] = ContextVar("session_currency", default=None)
_session_rate: ContextVar[Optional[float]] = ContextVar("session_rate", default=None)


def set_session_currency(code: Optional[str], rate: Optional[float]) -> None:
    """设置会话币种覆盖及其相对用户币种的当日汇率（user -> session）。"""
    _session_currency.set(code)
    _session_rate.set(rate)


def reset_session_currency() -> None:
    _session_currency.set(None)
    _session_rate.set(None)


def get_session_currency() -> Optional[str]:
    return _session_currency.get()


def get_session_rate() -> Optional[float]:
    return _session_rate.get()


_session_region: ContextVar[Optional[int]] = ContextVar("session_region", default=None)
# None 同时可能表示“没有覆盖”和“明确选择全部地区”，故单独记录是否有覆盖。
_session_region_overridden: ContextVar[bool] = ContextVar("session_region_overridden", default=False)


def set_session_region(region_id: Optional[int]) -> None:
    """设置会话地区覆盖（None 表示明确选择“全部地区”）。"""
    _session_region.set(region_id)
    _session_region_overridden.set(True)


def get_session_region() -> Optional[int]:
    return _session_region.get()


def has_session_region_override() -> bool:
    return _session_region_overridden.get()


def reset_session_region() -> None:
    _session_region.set(None)
    _session_region_overridden.set(False)
