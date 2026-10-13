double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class EntityUnit {
  final int id;
  final String unitName;
  final double? conversionFactor;
  final double? weightPerUnit;
  final bool isDefault;
  final String? source;
  final bool isPending;

  /// 每单位量指向的全局质量/体积单位（g/kg/斤/mL…）。
  final int? weightUnitId;

  /// 每单位量指向的本实体另一个自定义单位（嵌套，如 1箱 = 12盒）。
  /// 与 [weightUnitId] 互斥；都为空时按克处理。
  final int? weightUnitOverrideId;

  // 每单位量为体积语义（1瓶=500mL）；由 provider 依据全局单位表标注
  final bool isVolumeWeight;

  const EntityUnit({
    required this.id,
    required this.unitName,
    this.conversionFactor,
    this.weightPerUnit,
    this.isDefault = false,
    this.source,
    this.isPending = false,
    this.weightUnitId,
    this.weightUnitOverrideId,
    this.isVolumeWeight = false,
  });

  factory EntityUnit.fromJson(Map<String, dynamic> json) {
    return EntityUnit(
      id: (json['id'] as num?)?.toInt() ?? 0,
      unitName: json['unit_name'] as String? ?? '',
      conversionFactor: _toDouble(json['conversion_factor']),
      weightPerUnit: _toDouble(json['weight_per_unit']),
      isDefault: json['is_default'] as bool? ?? false,
      source: json['source'] as String?,
      isPending: false,
      weightUnitId: (json['weight_unit_id'] as num?)?.toInt(),
      weightUnitOverrideId:
          (json['weight_unit_override_id'] as num?)?.toInt(),
    );
  }

  EntityUnit copyWith({
    bool? isVolumeWeight,
  }) {
    return EntityUnit(
      id: id,
      unitName: unitName,
      conversionFactor: conversionFactor,
      weightPerUnit: weightPerUnit,
      isDefault: isDefault,
      source: source,
      isPending: isPending,
      weightUnitId: weightUnitId,
      weightUnitOverrideId: weightUnitOverrideId,
      isVolumeWeight: isVolumeWeight ?? this.isVolumeWeight,
    );
  }
}

/// 可选作「重量单位」的全局单位（质量/体积），用于单位表单下拉。
class GlobalUnitOption {
  final int id;
  final String name;
  final String abbreviation;
  final String unitType; // mass / volume
  final double siFactor;

  const GlobalUnitOption({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.unitType,
    required this.siFactor,
  });

  bool get isVolume => unitType == 'volume';

  factory GlobalUnitOption.fromJson(Map<String, dynamic> json) {
    return GlobalUnitOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      abbreviation: json['abbreviation'] as String? ?? '',
      unitType: json['unit_type'] as String? ?? '',
      siFactor: _toDouble(json['si_factor']) ?? 0,
    );
  }
}

class UnmappedUnit {
  final int unitId;
  final String unitName;
  final int usageCount;

  const UnmappedUnit({
    required this.unitId,
    required this.unitName,
    this.usageCount = 0,
  });

  factory UnmappedUnit.fromJson(Map<String, dynamic> json) {
    return UnmappedUnit(
      unitId: (json['unit_id'] as num?)?.toInt() ?? 0,
      unitName: json['unit_name'] as String? ?? '',
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class EntityDensity {
  final int id;
  final double density;
  final double? temperature;
  final String? condition;
  final String? source;
  final bool isPending;

  const EntityDensity({
    required this.id,
    required this.density,
    this.temperature,
    this.condition,
    this.source,
    this.isPending = false,
  });

  factory EntityDensity.fromJson(Map<String, dynamic> json) {
    return EntityDensity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      density: _toDouble(json['density']) ?? 0,
      temperature: _toDouble(json['temperature']),
      condition: json['condition'] as String?,
      source: json['source'] as String?,
      isPending: false,
    );
  }
}
