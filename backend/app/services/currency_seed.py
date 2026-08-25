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
    覆盖 CURRENCIES（精选 35 种）与 REGION_CURRENCIES 用到的全部 ISO 4217 代码；
    非精选币种用 code 本身作为名称/符号兜底（汇率覆盖仍以 provider 支持为准）。
    """
    existing = {c.code for c in db.query(Currency).all()}
    needed = dict(CURRENCIES)
    for code in REGION_CURRENCIES.values():
        needed.setdefault(code, {"name": code, "symbol": code, "decimals": 2})
    created = 0
    for code, meta in needed.items():
        if code in existing:
            continue
        db.add(Currency(code=code, **meta))
        created += 1
    if created:
        db.commit()
    return {"created": created, "skipped": len(needed) - created}

# ISO 3166-1 alpha-2 -> 默认币种（覆盖全部 249 个国家/地区；
# 南极洲 AQ 无官方货币，按科考站惯例 USD；汇率覆盖以 provider 支持为准）
REGION_CURRENCIES: dict[str, str] = {
    "AF": "AFN", "AX": "EUR", "AL": "ALL", "DZ": "DZD", "AS": "USD", "AD": "EUR", "AO": "AOA", "AI": "XCD", "AQ": "USD", "AG": "XCD",
    "AR": "ARS", "AM": "AMD", "AW": "AWG", "AU": "AUD", "AT": "EUR", "AZ": "AZN", "BS": "BSD", "BH": "BHD", "BD": "BDT", "BB": "BBD",
    "BY": "BYN", "BE": "EUR", "BZ": "BZD", "BJ": "XOF", "BM": "BMD", "BT": "BTN", "BO": "BOB", "BQ": "USD", "BA": "BAM", "BW": "BWP",
    "BV": "NOK", "BR": "BRL", "IO": "USD", "BN": "BND", "BG": "BGN", "BF": "XOF", "BI": "BIF", "CV": "CVE", "KH": "KHR", "CM": "XAF",
    "CA": "CAD", "KY": "KYD", "CF": "XAF", "TD": "XAF", "CL": "CLP", "CN": "CNY", "CX": "AUD", "CC": "AUD", "CO": "COP", "KM": "KMF",
    "CG": "XAF", "CD": "CDF", "CK": "NZD", "CR": "CRC", "CI": "XOF", "HR": "EUR", "CU": "CUP", "CW": "ANG", "CY": "EUR", "CZ": "CZK",
    "DK": "DKK", "DJ": "DJF", "DM": "XCD", "DO": "DOP", "EC": "USD", "EG": "EGP", "SV": "USD", "GQ": "XAF", "ER": "ERN", "EE": "EUR",
    "SZ": "SZL", "ET": "ETB", "FK": "FKP", "FO": "DKK", "FJ": "FJD", "FI": "EUR", "FR": "EUR", "GF": "EUR", "PF": "XPF", "TF": "EUR",
    "GA": "XAF", "GM": "GMD", "GE": "GEL", "DE": "EUR", "GH": "GHS", "GI": "GIP", "GR": "EUR", "GL": "DKK", "GD": "XCD", "GP": "EUR",
    "GU": "USD", "GT": "GTQ", "GG": "GBP", "GN": "GNF", "GW": "XOF", "GY": "GYD", "HT": "HTG", "HM": "AUD", "VA": "EUR", "HN": "HNL",
    "HK": "HKD", "HU": "HUF", "IS": "ISK", "IN": "INR", "ID": "IDR", "IR": "IRR", "IQ": "IQD", "IE": "EUR", "IM": "GBP", "IL": "ILS",
    "IT": "EUR", "JM": "JMD", "JP": "JPY", "JE": "GBP", "JO": "JOD", "KZ": "KZT", "KE": "KES", "KI": "AUD", "KP": "KPW", "KR": "KRW",
    "KW": "KWD", "KG": "KGS", "LA": "LAK", "LV": "EUR", "LB": "LBP", "LS": "LSL", "LR": "LRD", "LY": "LYD", "LI": "CHF", "LT": "EUR",
    "LU": "EUR", "MO": "MOP", "MG": "MGA", "MW": "MWK", "MY": "MYR", "MV": "MVR", "ML": "XOF", "MT": "EUR", "MH": "USD", "MQ": "EUR",
    "MR": "MRU", "MU": "MUR", "YT": "EUR", "MX": "MXN", "FM": "USD", "MD": "MDL", "MC": "EUR", "MN": "MNT", "ME": "EUR", "MS": "XCD",
    "MA": "MAD", "MZ": "MZN", "MM": "MMK", "NA": "NAD", "NR": "AUD", "NP": "NPR", "NL": "EUR", "NC": "XPF", "NZ": "NZD", "NI": "NIO",
    "NE": "XOF", "NG": "NGN", "NU": "NZD", "NF": "AUD", "MK": "MKD", "MP": "USD", "NO": "NOK", "OM": "OMR", "PK": "PKR", "PW": "USD",
    "PS": "ILS", "PA": "USD", "PG": "PGK", "PY": "PYG", "PE": "PEN", "PH": "PHP", "PN": "NZD", "PL": "PLN", "PT": "EUR", "PR": "USD",
    "QA": "QAR", "RE": "EUR", "RO": "RON", "RU": "RUB", "RW": "RWF", "BL": "EUR", "SH": "SHP", "KN": "XCD", "LC": "XCD", "MF": "EUR",
    "PM": "EUR", "VC": "XCD", "WS": "WST", "SM": "EUR", "ST": "STN", "SA": "SAR", "SN": "XOF", "RS": "RSD", "SC": "SCR", "SL": "SLE",
    "SG": "SGD", "SX": "ANG", "SK": "EUR", "SI": "EUR", "SB": "SBD", "SO": "SOS", "ZA": "ZAR", "GS": "GBP", "SS": "SSP", "ES": "EUR",
    "LK": "LKR", "SD": "SDG", "SR": "SRD", "SJ": "NOK", "SE": "SEK", "CH": "CHF", "SY": "SYP", "TW": "TWD", "TJ": "TJS", "TZ": "TZS",
    "TH": "THB", "TL": "USD", "TG": "XOF", "TK": "NZD", "TO": "TOP", "TT": "TTD", "TN": "TND", "TR": "TRY", "TM": "TMT", "TC": "USD",
    "TV": "AUD", "UG": "UGX", "UA": "UAH", "AE": "AED", "GB": "GBP", "US": "USD", "UM": "USD", "UY": "UYU", "UZ": "UZS", "VU": "VUV",
    "VE": "VES", "VN": "VND", "VG": "USD", "VI": "USD", "WF": "XPF", "EH": "MAD", "YE": "YER", "ZM": "ZMW", "ZW": "ZWG",
}





def ensure_region_currencies(db: Session) -> dict:
    """启动时按国家补齐地区默认币种，返回 {"filled": int, "total": int}。

    幂等：只填空缺/新建（仅对行政区划中已存在的国家），不覆盖已设值，
    管理员后续可在 region_unit_settings 手工调整。
    """
    from app.models.administrative_region import AdministrativeRegion
    from app.models.region_unit_setting import RegionUnitSetting

    existing = {r.region_code: r for r in db.query(RegionUnitSetting).all()}
    filled = 0
    for code, currency in REGION_CURRENCIES.items():
        row = existing.get(code)
        if row is not None and row.default_currency:
            continue
        region = (
            db.query(AdministrativeRegion)
            .filter(
                AdministrativeRegion.iso_country == code,
                AdministrativeRegion.level == 0,
            )
            .first()
        )
        if region is None:
            continue
        if row is None:
            row = RegionUnitSetting(
                region_code=code,
                region_name=region.name,
                default_currency=currency,
            )
            db.add(row)
        else:
            row.region_name = region.name
            row.default_currency = currency
        filled += 1
    if filled:
        db.commit()
    return {"filled": filled, "total": len(REGION_CURRENCIES)}
