import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

/// 营养成分默认展示项（与 Web 端 coreNutritionItems 一致）
const defaultNutrientKeys = ['能量', '蛋白质', '脂肪', '碳水化合物', '钠'];

/// 展开时营养素排序顺序（英文键已预先转为中文）
const nutrientSortOrder = [
  '能量',
  '蛋白质',
  '脂肪',
  '碳水化合物',
  '钠',
  '膳食纤维',
  '钙',
  '磷',
  '钾',
  '镁',
  '铁',
  '锌',
  '硒',
  '铜',
  '锰',
  '维生素A',
  '维生素B1',
  '维生素B2',
  '维生素B6',
  '维生素B12',
  '维生素C',
  '维生素D',
  '维生素E',
  '维生素K',
  '叶酸',
  '烟酸',
  '胆固醇',
  '饱和脂肪',
];

/// 英文 → 中文 营养素名映射
const englishToChineseNutrient = <String, String>{
  'energy': '能量',
  'calories': '能量',
  'protein': '蛋白质',
  'fat': '脂肪',
  'carbohydrate': '碳水化合物',
  'carbs': '碳水化合物',
  'sodium': '钠',
  'fiber': '膳食纤维',
  'calcium': '钙',
  'phosphorus': '磷',
  'potassium': '钾',
  'magnesium': '镁',
  'iron': '铁',
  'zinc': '锌',
  'selenium': '硒',
  'copper': '铜',
  'manganese': '锰',
  'vitamin_a': '维生素A',
  'vitamin_b1': '维生素B1',
  'thiamin': '维生素B1',
  'vitamin_b2': '维生素B2',
  'riboflavin': '维生素B2',
  'vitamin_b6': '维生素B6',
  'vitamin_b12': '维生素B12',
  'vitamin_c': '维生素C',
  'vitamin_d': '维生素D',
  'vitamin_e': '维生素E',
  'vitamin_k': '维生素K',
  'folate': '叶酸',
  'niacin': '烟酸',
  'cholesterol': '胆固醇',
  'saturated_fat': '饱和脂肪',
};

/// 中文键 → 展示标签（用于未挂载本地化上下文的兼容路径）
String nutrientDisplayLabel(String key) {
  switch (key) {
    case '热量':
      return '能量';
    default:
      return key;
  }
}

/// 中文营养素键/标签 → 当前 UI 语言展示名。
/// 传入的键值仍是稳定存储键，仅展示边界本地化。
String localizedNutrientLabel(String label, AppLocalizations l10n) {
  return switch (label) {
    '能量' || '热量' => l10n.nutritionNutrientEnergy,
    '蛋白质' => l10n.nutritionNutrientProtein,
    '脂肪' => l10n.nutritionNutrientFat,
    '碳水化合物' => l10n.nutritionNutrientCarbohydrate,
    '膳食纤维' => l10n.nutritionNutrientDietaryFiber,
    '钠' => l10n.nutritionNutrientSodium,
    '磷' => l10n.nutritionNutrientPhosphorus,
    '钾' => l10n.nutritionNutrientPotassium,
    '镁' => l10n.nutritionNutrientMagnesium,
    '铁' => l10n.nutritionNutrientIron,
    '锌' => l10n.nutritionNutrientZinc,
    '硒' => l10n.nutritionNutrientSelenium,
    '铜' => l10n.nutritionNutrientCopper,
    '锰' => l10n.nutritionNutrientManganese,
    '维生素A' => l10n.nutritionNutrientVitaminA,
    '维生素B1' => l10n.nutritionNutrientVitaminB1,
    '维生素B2' => l10n.nutritionNutrientVitaminB2,
    '维生素B6' => l10n.nutritionNutrientVitaminB6,
    '维生素B12' => l10n.nutritionNutrientVitaminB12,
    '维生素C' => l10n.nutritionNutrientVitaminC,
    '维生素D' => l10n.nutritionNutrientVitaminD,
    '维生素E' => l10n.nutritionNutrientVitaminE,
    '维生素K' => l10n.nutritionNutrientVitaminK,
    '叶酸' => l10n.nutritionNutrientFolate,
    '烟酸' => l10n.nutritionNutrientNiacin,
    '胆固醇' => l10n.nutritionNutrientCholesterol,
    '饱和脂肪' => l10n.nutritionNutrientSaturatedFat,
    _ => label,
  };
}

/// 营养素排序：按 nutrientSortOrder 中的位置排序，未列出的排在最后
int compareNutrients(String a, String b) {
  final ia = nutrientSortOrder.indexOf(a);
  final ib = nutrientSortOrder.indexOf(b);
  if (ia == -1 && ib == -1) return a.compareTo(b);
  if (ia == -1) return 1;
  if (ib == -1) return -1;
  return ia - ib;
}
