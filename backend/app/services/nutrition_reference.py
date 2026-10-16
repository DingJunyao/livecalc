"""营养素参考值（NRV）与核心营养素口径。

来源：GB 28050-2011《食品安全国家标准 预包装食品营养标签通则》成人每日推荐摄入量。
- `NRV_REFERENCE_VALUES`：中文名 → 标准值（与 `recipe_service.calculate_recipe_nutrition` 同口径，
  该函数已改为从这里 import，避免两处维护）。
- `CORE_NUTRIENTS`：中文名 → (英文 key, 单位)，用于把 all_nutrients（英文 key）与
  前端「营养成分」表的展示口径对齐。
"""
from typing import Dict, Optional

NRV_REFERENCE_VALUES: Dict[str, float] = {
    "能量": 2000.0,  # kcal
    "蛋白质": 60.0,  # g
    "脂肪": 60.0,  # g
    "碳水化合物": 300.0,  # g
    "膳食纤维": 25.0,  # g
    "钙": 800.0,  # mg
    "铁": 15.0,  # mg
    "钠": 2000.0,  # mg
    "钾": 2000.0,  # mg
    "维生素A": 800.0,  # μg
    "维生素C": 100.0,  # mg
    "维生素B1": 1.2,  # mg
    "维生素B2": 1.4,  # mg
    "维生素B12": 2.4,  # μg
    "维生素D": 5.0,  # μg
    "维生素E": 14.0,  # mg
    "维生素K": 80.0,  # μg
}

# 中文名 → (英文 key, 单位)
CORE_NUTRIENTS = [
    ("能量", "energy", "kcal"),
    ("蛋白质", "protein", "g"),
    ("脂肪", "fat", "g"),
    ("碳水化合物", "carbohydrate", "g"),
    ("膳食纤维", "fiber", "g"),
    ("钙", "calcium", "mg"),
    ("铁", "iron", "mg"),
    ("钠", "sodium", "mg"),
    ("钾", "potassium", "mg"),
    ("维生素A", "vitamin_a_rae", "μg"),
    ("维生素C", "vitamin_c", "mg"),
    ("维生素B1", "vitamin_b1", "mg"),
    ("维生素B2", "vitamin_b2", "mg"),
    ("维生素B12", "vitamin_b12", "μg"),
    ("维生素D", "vitamin_d", "μg"),
    ("维生素E", "vitamin_e", "mg"),
    ("维生素K", "vitamin_k", "μg"),
]

NAME_BY_KEY: Dict[str, str] = {key: name for name, key, _ in CORE_NUTRIENTS}
KEY_BY_NAME: Dict[str, str] = {name: key for name, key, _ in CORE_NUTRIENTS}
UNIT_BY_KEY: Dict[str, str] = {key: unit for _, key, unit in CORE_NUTRIENTS}
NRV_BY_KEY: Dict[str, float] = {
    KEY_BY_NAME[name]: value
    for name, value in NRV_REFERENCE_VALUES.items()
    if name in KEY_BY_NAME
}

# kJ → kcal（营养数据里能量可能是 kJ）
KCAL_PER_KJ = 0.239006


def energy_to_kcal(value: Optional[float], unit: Optional[str]) -> float:
    """把能量值统一成 kcal（单位缺失/异常时按原值返回）。"""
    if value is None:
        return 0.0
    try:
        number = float(value)
    except (TypeError, ValueError):
        return 0.0
    if unit and "j" in str(unit).lower() and "k" in str(unit).lower() and "kcal" not in str(unit).lower():
        return number * KCAL_PER_KJ
    return number


def nrv_pct(key: str, value: Optional[float]) -> Optional[float]:
    """NRV 百分比 = 数值 / NRV 标准值 × 100；没有标准值的营养素返回 None。"""
    reference = NRV_BY_KEY.get(key)
    if not reference or value is None:
        return None
    try:
        return round(float(value) / reference * 100, 2)
    except (TypeError, ValueError):
        return None
