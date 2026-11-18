#!/usr/bin/env python3
"""为移动端三个 ARB 文件追加跨地区物价对比的文案（一期）。幂等。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "lib" / "l10n"

# (key, zh, en, ar, placeholders)  placeholders: 字段名列表
KEYS = [
    ("compareTitle", "物价对比", "Price comparison", "مقارنة الأسعار", []),
    ("compareTabOverview", "概览", "Overview", "نظرة عامة", []),
    ("compareTabPrices", "原料·商品", "Items", "العناصر", []),
    ("compareRegions", "对比地区", "Regions", "المناطق", []),
    ("compareNeedTwoRegions", "选择至少两个地区开始对比",
     "Pick at least two regions to compare", "اختر منطقتين على الأقل للمقارنة", []),
    ("compareLowestIndex", "指数最低", "Lowest", "الأدنى", []),
    ("compareRecordCount", "{count} 条价格记录", "{count} records", "{count} سجل", ["count"]),
    ("compareEntityCount", "{count} 种商品", "{count} products", "{count} منتج", ["count"]),
    ("comparePriceIndexTitle", "物价指数（{base} = 100）",
     "Price index ({base} = 100)", "مؤشر الأسعار ({base} = 100)", ["base"]),
    ("comparePriceIndexCaption", "物价指数", "price index", "مؤشر الأسعار", []),
    ("compareBasketNote", "篮子含 {count} 种商品（基准地区近一年有记录）",
     "Basket of {count} products priced in the base region within a year",
     "سلة من {count} منتج له أسعار في المنطقة المرجعية خلال سنة", ["count"]),
    ("compareBasketTrendTitle", "篮子均价趋势", "Basket price trend", "اتجاه سعر السلة", []),
    ("compareTrendUnit", "元/斤", "¥/jin (500 g)", "يوان/جين", []),
    ("compareByRegion", "按地区", "By region", "حسب المنطقة", []),
    ("compareRegionsSuffix", "等 {count} 个地区", "and {count} regions",
     "و {count} مناطق", ["count"]),
    ("compareEntityTypeIngredient", "原料", "Ingredients", "المواد", []),
    ("compareEntityTypeProduct", "商品", "Products", "المنتجات", []),
    ("compareSelectEntities", "添加实体", "Add items", "إضافة عناصر", []),
    ("compareSearchEntityHint", "搜索名称", "Search by name", "ابحث بالاسم", []),
    ("compareNoEntity", "没有匹配项", "No matches", "لا توجد نتائج", []),
    ("compareMatrixTitle", "各地区价格对比", "Region price comparison",
     "مقارنة الأسعار حسب المنطقة", []),
    ("compareMatrixEntityCol", "实体", "Item", "العنصر", []),
    ("compareNoMatrixData", "选择地区与实体后展示比价",
     "Pick regions and items to compare", "اختر المناطق والعناصر للمقارنة", []),
    ("compareUnassignedNote", "未分配地区的商家计入所有地区",
     "Merchants without a region count in every region",
     "التجار بدون منطقة تُحتسب في كل منطقة", []),
    ("compareStaleRecord", "最近记录 {days} 天前", "last recorded {days} days ago",
     "آخر سجل قبل {days} يوم", ["days"]),
    ("compareNoRegionData", "所选地区暂无该实体价格",
     "No price data in these regions", "لا توجد أسعار في هذه المناطق", []),
    ("compareUnknownRegion", "未知地区", "Unknown region", "منطقة غير معروفة", []),
    ("compareRegionPrices", "各地区价格", "Region prices", "الأسعار حسب المنطقة", []),
    ("compareSelectedCount", "已选", "selected", "محدد", []),
    ("navCompare", "物价对比", "Compare prices", "مقارنة الأسعار", []),
]


def main() -> int:
    for i, (locale_index, filename) in enumerate([("zh", "app_zh.arb"), ("en", "app_en.arb"), ("ar", "app_ar.arb")]):
        path = ROOT / filename
        text = path.read_text(encoding="utf-8")
        if '"compareTitle"' in text:
            print(f"[skip] {filename}: already present")
            continue
        stripped = text.rstrip()
        assert stripped.endswith("}"), filename
        # 去掉最外层 }，并确保最后一个键以逗号结尾
        body = stripped[:-1].rstrip()
        if not body.endswith(","):
            body += ","
        block_lines = []
        for key, zh, en, ar, placeholders in KEYS:
            value = {"zh": zh, "en": en, "ar": ar}[locale_index]
            block_lines.append(f'  "{key}": "{value}",')
            meta = {"placeholders": {p: {} for p in placeholders}} if placeholders else {}
            meta_json = json.dumps(meta, ensure_ascii=False)
            block_lines.append(f'  "@{key}": {meta_json},')
        # 最后一个键的 @元数据 行去掉尾逗号
        block_lines[-1] = block_lines[-1].rstrip(",")
        new_text = body + "\n" + "\n".join(block_lines) + "\n}\n"
        path.write_text(new_text, encoding="utf-8")
        data = json.loads(path.read_text(encoding="utf-8"))
        assert "compareTitle" in data and "navCompare" in data
        print(f"[ok] {filename}: {len(KEYS)} keys appended")
    return 0


if __name__ == "__main__":
    sys.exit(main())
