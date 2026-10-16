/// 营养素参考值（NRV）与能量单位换算。
///
/// 与后端 `app/services/nutrition_reference.py`、web `frontend/src/utils/nrv.ts` 同口径：
/// 一餐推荐接口只回「热量 / 蛋白质 / 碳水化合物 / 脂肪」四个值，没有服务端算好的 NRV%，
/// 所以餐卡自带一份常量自己补，保证与 web 展示一致。
///
/// NRV 来源：GB 28050-2011《食品安全国家标准 预包装食品营养标签通则》成人每日推荐摄入量。
library;

const Map<String, double> nrvReferenceValues = <String, double>{
  'energy': 2000,
  'protein': 60,
  'fat': 60,
  'carbohydrate': 300,
  'fiber': 25,
  'calcium': 800,
  'iron': 15,
  'sodium': 2000,
  'potassium': 2000,
  'vitamin_a_rae': 800,
  'vitamin_c': 100,
  'vitamin_b1': 1.2,
  'vitamin_b2': 1.4,
  'vitamin_b12': 2.4,
  'vitamin_d': 5,
  'vitamin_e': 14,
  'vitamin_k': 80,
};

/// NRV 百分比 = 数值 / 标准值 × 100（保留 2 位小数）；没有标准值或数值非法时返回 null。
double? nrvPct(String nutrientKey, double? value) {
  final reference = nrvReferenceValues[nutrientKey];
  if (reference == null || reference == 0 || value == null || !value.isFinite) {
    return null;
  }
  return (value / reference * 10000).roundToDouble() / 100;
}

/// 库存 kcal → 用户偏好单位（kJ 时 ×4.184 取整，对齐 web toDisplayCalorie）。
double toDisplayCalorie(double kcal, String energyUnit) =>
    energyUnit == 'kJ' ? (kcal * 4.184).roundToDouble() : kcal;

/// 用户偏好单位 → 库存 kcal（对齐 web fromDisplayCalorie）。
double fromDisplayCalorie(double value, String energyUnit) =>
    energyUnit == 'kJ' ? (value / 4.184).roundToDouble() : value;
