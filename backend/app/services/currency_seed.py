"""币种字典自动填充服务。

普通用户没有维护币种的权限，币种字典由系统在启动时自动补齐：
- 以汇率 provider（Frankfurter/ECB）覆盖的主流币种为基准，与
  backend/scripts/sql/20260823_multi_currency_*.sql 的 15 种对齐并补齐；
- 幂等：只补缺失项；除早期版本写入的 code 占位名称外，不覆盖管理员编辑。
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

# 地区默认币种会额外进入字典的 ISO 4217 代码中文名。
# 只用于新增缺失币种和回填历史占位名称，不覆盖管理员自定义名称。
CURRENCY_NAMES: dict[str, str] = {
    "AFN": "阿富汗尼",
    "ALL": "阿尔巴尼亚列克",
    "AMD": "亚美尼亚德拉姆",
    "ANG": "荷属安的列斯盾",
    "AOA": "安哥拉宽扎",
    "ARS": "阿根廷比索",
    "AWG": "阿鲁巴弗罗林",
    "AZN": "阿塞拜疆马纳特",
    "BAM": "波黑可兑换马克",
    "BBD": "巴巴多斯元",
    "BDT": "孟加拉塔卡",
    "BHD": "巴林第纳尔",
    "BIF": "布隆迪法郎",
    "BMD": "百慕大元",
    "BND": "文莱元",
    "BOB": "玻利维亚诺",
    "BSD": "巴哈马元",
    "BTN": "不丹努尔特鲁姆",
    "BWP": "博茨瓦纳普拉",
    "BYN": "白俄罗斯卢布",
    "BZD": "伯利兹元",
    "CDF": "刚果法郎",
    "CLP": "智利比索",
    "COP": "哥伦比亚比索",
    "CRC": "哥斯达黎加科朗",
    "CUP": "古巴比索",
    "CVE": "佛得角埃斯库多",
    "DJF": "吉布提法郎",
    "DOP": "多米尼加比索",
    "DZD": "阿尔及利亚第纳尔",
    "EGP": "埃及镑",
    "ERN": "厄立特里亚纳克法",
    "ETB": "埃塞俄比亚比尔",
    "FJD": "斐济元",
    "FKP": "福克兰群岛镑",
    "GEL": "格鲁吉亚拉里",
    "GHS": "加纳塞地",
    "GIP": "直布罗陀镑",
    "GMD": "冈比亚达拉西",
    "GNF": "几内亚法郎",
    "GTQ": "危地马拉格查尔",
    "GYD": "圭亚那元",
    "HNL": "洪都拉斯伦皮拉",
    "HTG": "海地古德",
    "IQD": "伊拉克第纳尔",
    "IRR": "伊朗里亚尔",
    "JMD": "牙买加元",
    "JOD": "约旦第纳尔",
    "KES": "肯尼亚先令",
    "KGS": "吉尔吉斯斯坦索姆",
    "KHR": "柬埔寨瑞尔",
    "KMF": "科摩罗法郎",
    "KPW": "朝鲜圆",
    "KWD": "科威特第纳尔",
    "KYD": "开曼群岛元",
    "KZT": "哈萨克斯坦坚戈",
    "LAK": "老挝基普",
    "LBP": "黎巴嫩镑",
    "LKR": "斯里兰卡卢比",
    "LRD": "利比里亚元",
    "LSL": "莱索托洛蒂",
    "LYD": "利比亚第纳尔",
    "MAD": "摩洛哥迪拉姆",
    "MDL": "摩尔多瓦列伊",
    "MGA": "马达加斯加阿里亚里",
    "MKD": "北马其顿第纳尔",
    "MMK": "缅甸元",
    "MNT": "蒙古图格里克",
    "MOP": "澳门元",
    "MRU": "毛里塔尼亚乌吉亚",
    "MUR": "毛里求斯卢比",
    "MVR": "马尔代夫拉菲亚",
    "MWK": "马拉维克瓦查",
    "MZN": "莫桑比克梅蒂卡尔",
    "NAD": "纳米比亚元",
    "NGN": "尼日利亚奈拉",
    "NIO": "尼加拉瓜科多巴",
    "NPR": "尼泊尔卢比",
    "OMR": "阿曼里亚尔",
    "PEN": "秘鲁索尔",
    "PGK": "巴布亚新几内亚基那",
    "PKR": "巴基斯坦卢比",
    "PYG": "巴拉圭瓜拉尼",
    "QAR": "卡塔尔里亚尔",
    "RSD": "塞尔维亚第纳尔",
    "RWF": "卢旺达法郎",
    "SAR": "沙特里亚尔",
    "SBD": "所罗门群岛元",
    "SCR": "塞舌尔卢比",
    "SDG": "苏丹镑",
    "SHP": "圣赫勒拿镑",
    "SLE": "塞拉利昂新利昂",
    "SOS": "索马里先令",
    "SRD": "苏里南元",
    "SSP": "南苏丹镑",
    "STN": "圣多美和普林西比多布拉",
    "SYP": "叙利亚镑",
    "SZL": "斯威士兰里兰吉尼",
    "TJS": "塔吉克斯坦索莫尼",
    "TMT": "土库曼斯坦马纳特",
    "TND": "突尼斯第纳尔",
    "TOP": "汤加潘加",
    "TTD": "特立尼达和多巴哥元",
    "TZS": "坦桑尼亚先令",
    "UAH": "乌克兰格里夫纳",
    "UGX": "乌干达先令",
    "UYU": "乌拉圭比索",
    "UZS": "乌兹别克斯坦苏姆",
    "VES": "委内瑞拉玻利瓦尔",
    "VUV": "瓦努阿图瓦图",
    "WST": "萨摩亚塔拉",
    "XAF": "中非法郎",
    "XCD": "东加勒比元",
    "XOF": "西非法郎",
    "XPF": "太平洋法郎",
    "YER": "也门里亚尔",
    "ZMW": "赞比亚克瓦查",
    "ZWG": "津巴布韦金币",
}

ZERO_DECIMAL_CURRENCIES = {
    "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW",
    "PYG", "VND", "VUV", "XAF", "XOF", "XPF",
}
THREE_DECIMAL_CURRENCIES = {"BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"}


def _fallback_currency(code: str) -> dict:
    if code in THREE_DECIMAL_CURRENCIES:
        decimals = 3
    elif code in ZERO_DECIMAL_CURRENCIES:
        decimals = 0
    else:
        decimals = 2
    return {
        "name": CURRENCY_NAMES.get(code, code),
        "symbol": code,
        "decimals": decimals,
    }


def ensure_currencies(db: Session) -> dict:
    """启动时补齐缺失币种，返回 {"created": int, "updated": int, "skipped": int}。

    幂等：已存在的币种保持不变；仅回填早期版本生成的 code 占位名称。
    覆盖 CURRENCIES（精选 35 种）与 REGION_CURRENCIES 用到的全部 ISO 4217 代码；
    非精选币种使用内置 ISO 4217 中文名兜底（汇率覆盖仍以 provider 支持为准）。
    """
    existing = {c.code: c for c in db.query(Currency).all()}
    needed = dict(CURRENCIES)
    for code in REGION_CURRENCIES.values():
        needed.setdefault(code, _fallback_currency(code))
    created = 0
    updated = 0
    for code, meta in needed.items():
        row = existing.get(code)
        if row is not None:
            if row.name == code and row.name != meta["name"]:
                row.name = meta["name"]
                updated += 1
            continue
        db.add(Currency(code=code, **meta))
        created += 1
    if created or updated:
        db.commit()
    return {
        "created": created,
        "updated": updated,
        "skipped": len(needed) - created - updated,
    }

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
