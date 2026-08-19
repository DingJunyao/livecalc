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

  const EntityUnit({
    required this.id,
    required this.unitName,
    this.conversionFactor,
    this.weightPerUnit,
    this.isDefault = false,
    this.source,
    this.isPending = false,
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
