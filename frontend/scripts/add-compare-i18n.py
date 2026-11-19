#!/usr/bin/env python3
"""为三个语言文件插入跨地区物价对比的 i18n 键（一期）。

一次性脚本：在 charts.byMerchant 后加 byRegion；nav/routes 末尾加 compare；
在顶层 plans 命名空间前插入完整的 compare 命名空间。幂等（已有键时跳过）。
"""
import json
import sys
from pathlib import Path

LOCALES = {
    "zh-CN": Path("src/locales/zh-CN.json"),
    "en-US": Path("src/locales/en-US.json"),
    "ar": Path("src/locales/ar.json"),
}

NAV_COMPARE = {"zh-CN": "物价对比", "en-US": "Price comparison", "ar": "مقارنة الأسعار"}
ROUTES_COMPARE = NAV_COMPARE
CHARTS_BY_REGION = {"zh-CN": "按地区", "en-US": "By region", "ar": "حسب المنطقة"}

COMPARE_NS = {
    "zh-CN": {
        "tabOverview": "概览",
        "tabPrices": "原料·商品",
        "tabRecipes": "菜谱·试算",
        "regionSelector": "选择对比地区",
        "baseRegionNote": "{base} 为基准地区（物价指数 = 100）",
        "needTwoRegions": "选择至少两个地区开始对比",
        "lowestIndex": "指数最低",
        "priceIndexUnit": "物价指数",
        "recordCount": "{count} 条价格记录",
        "entityCount": "{count} 种商品",
        "priceIndexTitle": "物价指数（{base} = 100）",
        "basketNote": "篮子含 {count} 种商品（基准地区近一年有记录的商品）",
        "basketTrendTitle": "篮子均价趋势",
        "trendUnitJin": "斤",
        "noBasketData": "暂无篮子价格数据",
        "entityTypeIngredient": "原料",
        "entityTypeProduct": "商品",
        "selectEntities": "选择原料或商品",
        "searchEntityPlaceholder": "搜索名称",
        "noEntityMatch": "没有匹配项",
        "matrixTitle": "各地区价格对比",
        "matrixUnitNote": "每标准单位价，最低绿色加粗",
        "noMatrixData": "选择地区与实体后展示比价矩阵",
        "matrixEntityCol": "实体",
        "unassignedMerchantsNote": "未分配地区的商家计入所有地区",
        "staleRecord": "最近记录 {days} 天前",
        "noRegionData": "所选地区暂无该实体价格",
        "unknownRegion": "未知地区",
        "recipesSection": "菜谱成本",
        "selectRecipes": "选择菜谱",
        "recipeMatrixTitle": "各地区菜谱成本对比",
        "recipeMatrixUnitNote": "每份成本，最低绿色加粗；点击行看多地区趋势",
        "recipeTrendTitle": "{name} 的各地区成本趋势",
        "plansSection": "试算合计",
        "selectPlans": "选择试算方案",
        "planMatrixTitle": "各地区试算成本对比",
        "planMatrixUnitNote": "合计成本，最低绿色加粗；点击行看营养对照",
        "planNutrientTitle": "{name} 的各地区合计对照",
        "metricCost": "成本",
        "metricCalories": "热量 (kcal)",
        "metricProtein": "蛋白质 (g)",
        "metricCarbs": "碳水 (g)",
        "metricFat": "脂肪 (g)",
        "dimensionCurrent": "当前",
        "regionCol": "地区",
        "planTrendTitle": "各地区成本趋势",
        "tabHeatmap": "热力图",
        "heatmapModeItem": "单品物价",
        "heatmapModeOverall": "整体物价",
        "heatmapPickEntity": "选择原料或商品",
        "heatmapOverallNote": "不选单品，按共同商品篮子显示每个商家的整体物价指数（中位数=100）",
        "heatmapEmpty": "所选地区暂无有坐标的商家价格数据",
        "staleHint": "价格已超期",
        "sampleCountUnit": "种商品",
        "customScopeQuick": "自定义范围",
        "addScopeItem": "加入自定义范围",
    },
    "en-US": {
        "tabOverview": "Overview",
        "tabPrices": "Ingredients & products",
        "tabRecipes": "Recipes & plans",
        "regionSelector": "Regions to compare",
        "baseRegionNote": "{base} is the base region (price index = 100)",
        "needTwoRegions": "Pick at least two regions to start comparing",
        "lowestIndex": "Lowest index",
        "priceIndexUnit": "price index",
        "recordCount": "{count} price records",
        "entityCount": "{count} products",
        "priceIndexTitle": "Price index ({base} = 100)",
        "basketNote": "Basket covers {count} products priced in the base region within a year",
        "basketTrendTitle": "Basket average price trend",
        "trendUnitJin": "jin (500 g)",
        "noBasketData": "No basket price data yet",
        "entityTypeIngredient": "Ingredients",
        "entityTypeProduct": "Products",
        "selectEntities": "Select ingredients or products",
        "searchEntityPlaceholder": "Search by name",
        "noEntityMatch": "No matches",
        "matrixTitle": "Region price comparison",
        "matrixUnitNote": "per standard unit, lowest in bold green",
        "noMatrixData": "Pick regions and items to see the comparison",
        "matrixEntityCol": "Item",
        "unassignedMerchantsNote": "Merchants without a region count in every region",
        "staleRecord": "Last record {days} days ago",
        "noRegionData": "No price data in the selected regions",
        "unknownRegion": "Unknown region",
        "recipesSection": "Recipe costs",
        "selectRecipes": "Select recipes",
        "recipeMatrixTitle": "Recipe costs by region",
        "recipeMatrixUnitNote": "per serving, lowest in bold green; click a row for trends",
        "recipeTrendTitle": "Cost trend of {name} by region",
        "plansSection": "Plan totals",
        "selectPlans": "Select plans",
        "planMatrixTitle": "Plan costs by region",
        "planMatrixUnitNote": "total cost, lowest in bold green; click a row for nutrients",
        "planNutrientTitle": "Totals of {name} by region",
        "metricCost": "Cost",
        "metricCalories": "Calories (kcal)",
        "metricProtein": "Protein (g)",
        "metricCarbs": "Carbs (g)",
        "metricFat": "Fat (g)",
        "dimensionCurrent": "Current",
        "regionCol": "Region",
        "planTrendTitle": "Cost trend by region",
        "tabHeatmap": "Heatmap",
        "heatmapModeItem": "Item prices",
        "heatmapModeOverall": "Overall price level",
        "heatmapPickEntity": "Pick an ingredient or product",
        "heatmapOverallNote": "No single item — each merchant colored by its basket price index (median = 100)",
        "heatmapEmpty": "No geocoded merchant prices in the selected regions",
        "staleHint": "Price is stale",
        "sampleCountUnit": "items",
        "customScopeQuick": "Custom scope",
        "addScopeItem": "Add custom scope",
    },
    "ar": {
        "tabOverview": "نظرة عامة",
        "tabPrices": "المواد والمنتجات",
        "tabRecipes": "الوصفات والخطط",
        "regionSelector": "المناطق المقارَنة",
        "baseRegionNote": "{base} هي المنطقة المرجعية (مؤشر الأسعار = 100)",
        "needTwoRegions": "اختر منطقتين على الأقل لبدء المقارنة",
        "lowestIndex": "أدنى مؤشر",
        "priceIndexUnit": "مؤشر الأسعار",
        "recordCount": "{count} سجل أسعار",
        "entityCount": "{count} منتج",
        "priceIndexTitle": "مؤشر الأسعار ({base} = 100)",
        "basketNote": "السلة تغطي {count} منتج له أسعار في المنطقة المرجعية خلال سنة",
        "basketTrendTitle": "اتجاه متوسط سعر السلة",
        "trendUnitJin": "جين (500 غ)",
        "noBasketData": "لا توجد بيانات أسعار للسلة بعد",
        "entityTypeIngredient": "المواد",
        "entityTypeProduct": "المنتجات",
        "selectEntities": "اختر المواد أو المنتجات",
        "searchEntityPlaceholder": "ابحث بالاسم",
        "noEntityMatch": "لا توجد نتائج",
        "matrixTitle": "مقارنة الأسعار حسب المنطقة",
        "matrixUnitNote": "لكل وحدة قياسية، الأدنى بالخط العريض الأخضر",
        "noMatrixData": "اختر المناطق والعناصر لعرض المقارنة",
        "matrixEntityCol": "العنصر",
        "unassignedMerchantsNote": "التجار بدون منطقة تُحتسب في كل منطقة",
        "staleRecord": "آخر سجل قبل {days} يوم",
        "noRegionData": "لا توجد بيانات أسعار في المناطق المحددة",
        "unknownRegion": "منطقة غير معروفة",
        "recipesSection": "تكلفة الوصفات",
        "selectRecipes": "اختر الوصفات",
        "recipeMatrixTitle": "تكلفة الوصفات حسب المنطقة",
        "recipeMatrixUnitNote": "لكل حصة، الأدنى بالخط العريض الأخضر؛ انقر صفًا لعرض الاتجاه",
        "recipeTrendTitle": "اتجاه تكلفة {name} حسب المنطقة",
        "plansSection": "إجماليات الخطط",
        "selectPlans": "اختر الخطط",
        "planMatrixTitle": "تكلفة الخطط حسب المنطقة",
        "planMatrixUnitNote": "التكلفة الإجمالية، الأدنى بالخط العريض الأخضر؛ انقر صفًا لعرض العناصر الغذائية",
        "planNutrientTitle": "إجماليات {name} حسب المنطقة",
        "metricCost": "التكلفة",
        "metricCalories": "السعرات (kcal)",
        "metricProtein": "البروتين (غ)",
        "metricCarbs": "الكربوهيدرات (غ)",
        "metricFat": "الدهون (غ)",
        "dimensionCurrent": "الحالي",
        "regionCol": "المنطقة",
        "planTrendTitle": "اتجاه التكلفة حسب المنطقة",
        "tabHeatmap": "الخريطة الحرارية",
        "heatmapModeItem": "أسعار عنصر",
        "heatmapModeOverall": "المستوى العام للأسعار",
        "heatmapPickEntity": "اختر مادة أو منتجًا",
        "heatmapOverallNote": "بدون عنصر واحد — يُلوَّن كل تاجر حسب مؤشر سلة أسعاره (الوسيط = 100)",
        "heatmapEmpty": "لا توجد أسعار تجار بإحداثيات في المناطق المحددة",
        "staleHint": "السعر قديم",
        "sampleCountUnit": "منتجات",
        "customScopeQuick": "نطاق مخصص",
        "addScopeItem": "إضافة نطاق مخصص",
    },
}


LOCAL_ERRORS = {
    "zh-CN": {
        "invalidIdList": "ID 列表格式无效",
        "idListRequired": "至少需要一个 ID",
        "idListTooLong": "一次最多 {limit} 个",
        "comparisonEntityTypeInvalid": "entity_type 无效",
        "heatmapEntityRequired": "单品热力图必须选择原料或商品",
    },
    "en-US": {
        "invalidIdList": "Invalid ID list",
        "idListRequired": "At least one ID is required",
        "idListTooLong": "At most {limit} at a time",
        "comparisonEntityTypeInvalid": "Invalid entity_type",
        "heatmapEntityRequired": "Pick an ingredient or product for item heatmap",
    },
    "ar": {
        "invalidIdList": "قائمة معرفات غير صالحة",
        "idListRequired": "مطلوب معرف واحد على الأقل",
        "idListTooLong": "{limit} كحد أقصى في كل مرة",
        "comparisonEntityTypeInvalid": "entity_type غير صالح",
        "heatmapEntityRequired": "اختر مادة أو منتجًا للخريطة الحرارية",
    },
}

REGION_PRICES = {
    "zh-CN": "各地区价格",
    "en-US": "Region prices",
    "ar": "الأسعار حسب المنطقة",
}


def insert_into_block(lines: list[str], block_key: str, new_key: str, new_value: str) -> int:
    """在顶层块 block_key 的最后一个键行后插入 new_key（处理逗号）。返回新行数。"""
    start = next(i for i, l in enumerate(lines) if l.rstrip("\n") == f'  "{block_key}": {{')
    end = next(i for i in range(start + 1, len(lines)) if lines[i].rstrip("\n") == "  },")
    # 最后一个键行（end 前一行，块内没有嵌套块，键行无逗号结尾）
    last_key_idx = end - 1
    last_line = lines[last_key_idx].rstrip("\n")
    if last_key_idx + 1 == end and not last_line.endswith(","):
        lines[last_key_idx] = last_line + ","
    lines.insert(end, f'    "{new_key}": "{new_value}"')
    return len(lines)


def merge_into_compare_block(lines: list[str], ns: dict) -> int:
    """向已存在的顶层 compare 块末尾插入缺失键（保持其余行不动）。返回插入数。"""
    start = next(i for i, l in enumerate(lines) if l.rstrip("\n") == '  "compare": {')
    end = next(i for i in range(start + 1, len(lines)) if lines[i].rstrip("\n") == "  },")
    existing = set()
    for l in lines[start + 1:end]:
        s = l.strip()
        if s.startswith('"') and '":' in s:
            existing.add(s[1:s.index('"', 1)])
    added = 0
    for key, value in ns.items():
        if key in existing:
            continue
        line = f'    "{key}": {json.dumps(value, ensure_ascii=False)}'
        # 插入位置：end（即 "  }," 前），并把前一行补逗号
        last_idx = end - 1 + added
        if not lines[last_idx].rstrip("\n").endswith(","):
            lines[last_idx] = lines[last_idx].rstrip("\n") + ",\n"
        lines.insert(last_idx + 1, line + ",\n")
        added += 1
        end = end  # end 相对插入点随 added 偏移，用 last_idx 推进即可
    # 最后插入的键行不需要逗号（块尾）
    if added:
        tail_idx = end - 1 + added
        lines[tail_idx] = lines[tail_idx].rstrip("\n").rstrip(",") + "\n"
    return added


def main() -> int:
    for locale, path in LOCALES.items():
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines(keepends=True)

        # 0) compare 命名空间：不存在则整体插入；存在则合并缺失键（二期新增）
        if '  "compare": {' in text:
            added = merge_into_compare_block(lines, COMPARE_NS[locale])
            print(f"[merge] {locale}: +{added} compare keys")
        else:
            idx = next(i for i, l in enumerate(lines) if '"byMerchant"' in l)
            lines.insert(idx + 1, f'    "byRegion": "{CHARTS_BY_REGION[locale]}",\n')
            insert_into_block(lines, "nav", "compare", NAV_COMPARE[locale])
            insert_into_block(lines, "routes", "compare", ROUTES_COMPARE[locale])
            plans_idx = next(i for i, l in enumerate(lines) if l.rstrip("\n") == '  "plans": {')
            ns_json = json.dumps({"compare": COMPARE_NS[locale]}, ensure_ascii=False, indent=2)
            ns_lines = ns_json.splitlines()[1:-1]
            ns_lines[-1] = ns_lines[-1] + ","
            lines[plans_idx:plans_idx] = [l + "\n" for l in ns_lines]
            print(f"[ok] {locale}: compare namespace inserted")

        text = "".join(lines)
        # localErrors 键（幂等逐个补）
        lines = text.splitlines(keepends=True)
        for key, value in LOCAL_ERRORS[locale].items():
            if f'"{key}"' in "".join(lines):
                continue
            insert_into_block(lines, "localErrors", key, value)
        if not any('"regionPrices"' in l for l in lines):
            insert_into_block(lines, "ingredients", "regionPrices", REGION_PRICES[locale])
            insert_into_block(lines, "products", "regionPrices", REGION_PRICES[locale])
        path.write_text("".join(lines), encoding="utf-8")

        data = json.loads(path.read_text(encoding="utf-8"))
        assert "compare" in data and "byRegion" in data["charts"]
        assert "invalidIdList" in data["localErrors"]
        assert data["ingredients"]["regionPrices"] == REGION_PRICES[locale]
        assert data["products"]["regionPrices"] == REGION_PRICES[locale]
        print(f"[ok] {locale}: compare={len(data['compare'])} keys, json valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
