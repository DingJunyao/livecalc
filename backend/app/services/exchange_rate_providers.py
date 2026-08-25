"""汇率 provider 注册表。"""
from typing import Optional
import httpx


class BaseRateProvider:
    name = "base"

    def fetch(self, base_url: str, base_currency: str) -> dict:
        raise NotImplementedError


class FrankfurterProvider(BaseRateProvider):
    name = "frankfurter"

    def fetch(self, base_url: str, base_currency: str) -> dict:
        url = f"{base_url.rstrip('/')}/v2/rates?base={base_currency}"
        resp = httpx.get(url, timeout=15.0)
        resp.raise_for_status()
        data = resp.json()
        if isinstance(data, list):
            # v2 /rates 返回按币种平铺的数组:
            # [{"date": "2026-08-25", "base": "EUR", "quote": "AED", "rate": 4.2903}, ...]
            # 与 v1 的 dict 结构（{"base", "date", "rates": {quote: rate}}）不同，
            # 这里统一转成 v1 语义的 dict，便于上层快照存储。
            return {
                "base": data[0]["base"],
                "date": max(row["date"] for row in data),
                "rates": {row["quote"]: row["rate"] for row in data},
            }
        return {
            "base": data["base"],
            "date": data["date"],
            "rates": data["rates"],
        }


_PROVIDERS = {"frankfurter": FrankfurterProvider}


def get_provider(name: str) -> BaseRateProvider:
    cls = _PROVIDERS.get(name)
    if cls is None:
        raise ValueError(f"未知汇率 provider: {name}")
    return cls()
