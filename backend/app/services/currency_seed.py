"""币种字典自动填充服务。

普通用户没有维护币种的权限，币种字典由系统在启动时自动补齐：
- 以汇率 provider（Frankfurter/ECB）覆盖的主流币种为基准，与
  backend/scripts/sql/20260823_multi_currency_*.sql 的 15 种对齐并补齐；
- 幂等：只补缺失项，不覆盖管理员已编辑的名称/符号/小数位/停用状态。
"""
from sqlalchemy.orm import Session

from app.models.currency import Currency

# code -> (中文名, 符号, 小数位)
# 小数位按 ISO 4217 次要单位（无小数位币种如 JPY/KRW/VND/HUF/ISK 为 0）。
CURRENCIES: dict[str, dict] = {
    # 原有 seed 15 种（20260823_multi_currency_*）
    "CNY": {"name": "人民币", "symbol": "¥", "decimals": 2},
    "USD": {"name": "美元", "symbol": "$", "decimals": 2},
    "EUR": {"name": "欧元", "symbol": "€", "decimals": 2},
    "GBP": {"name": "英镑", "symbol": "£", "decimals": 2},
    "JPY": {"name": "日元", "symbol": "¥", "decimals": 0},
    "HKD": {"name": "港币", "symbol": "HK$", "decimals": 2},
    "KRW": {"name": "韩元", "symbol": "₩", "decimals": 0},
    "SGD": {"name": "新加坡元", "symbol": "S$", "decimals": 2},
    "AUD": {"name": "澳大利亚元", "symbol": "A$", "decimals": 2},
    "CAD": {"name": "加拿大元", "symbol": "C$", "decimals": 2},
    "TWD": {"name": "新台币", "symbol": "NT$", "decimals": 2},
    "THB": {"name": "泰铢", "symbol": "฿", "decimals": 2},
    "MYR": {"name": "马来西亚林吉特", "symbol": "RM", "decimals": 2},
    "VND": {"name": "越南盾", "symbol": "₫", "decimals": 0},
    "RUB": {"name": "俄罗斯卢布", "symbol": "₽", "decimals": 2},
    # Frankfurter/ECB 其余主流币种
    "AED": {"name": "阿联酋迪拉姆", "symbol": "د.إ", "decimals": 2},
    "BGN": {"name": "保加利亚列弗", "symbol": "лв", "decimals": 2},
    "BRL": {"name": "巴西雷亚尔", "symbol": "R$", "decimals": 2},
    "CHF": {"name": "瑞士法郎", "symbol": "CHF", "decimals": 2},
    "CZK": {"name": "捷克克朗", "symbol": "Kč", "decimals": 2},
    "DKK": {"name": "丹麦克朗", "symbol": "kr", "decimals": 2},
    "HUF": {"name": "匈牙利福林", "symbol": "Ft", "decimals": 0},
    "IDR": {"name": "印度尼西亚盾", "symbol": "Rp", "decimals": 2},
    "ILS": {"name": "以色列新谢克尔", "symbol": "₪", "decimals": 2},
    "INR": {"name": "印度卢比", "symbol": "₹", "decimals": 2},
    "ISK": {"name": "冰岛克朗", "symbol": "kr", "decimals": 0},
    "MXN": {"name": "墨西哥比索", "symbol": "Mex$", "decimals": 2},
    "NOK": {"name": "挪威克朗", "symbol": "kr", "decimals": 2},
    "NZD": {"name": "新西兰元", "symbol": "NZ$", "decimals": 2},
    "PHP": {"name": "菲律宾比索", "symbol": "₱", "decimals": 2},
    "PLN": {"name": "波兰兹罗提", "symbol": "zł", "decimals": 2},
    "RON": {"name": "罗马尼亚列伊", "symbol": "lei", "decimals": 2},
    "SEK": {"name": "瑞典克朗", "symbol": "kr", "decimals": 2},
    "TRY": {"name": "土耳其里拉", "symbol": "₺", "decimals": 2},
    "ZAR": {"name": "南非兰特", "symbol": "R", "decimals": 2},
}


def ensure_currencies(db: Session) -> dict:
    """启动时补齐缺失币种，返回 {"created": int, "skipped": int}。

    幂等：已存在的币种（含管理员停用/改名）保持不变，只插入缺失项。
    """
    existing = {c.code for c in db.query(Currency).all()}
    created = 0
    for code, meta in CURRENCIES.items():
        if code in existing:
            continue
        db.add(Currency(code=code, **meta))
        created += 1
    if created:
        db.commit()
    return {"created": created, "skipped": len(CURRENCIES) - created}
