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
