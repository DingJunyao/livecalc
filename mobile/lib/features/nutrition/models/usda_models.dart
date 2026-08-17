class UsdaFood {
  final int fdcId;
  final String description;
  final String? descriptionZh;
  final String dataType;
  final int nutrientCount;
  final List<UsdaNutrient> nutrients;

  const UsdaFood({
    required this.fdcId,
    required this.description,
    this.descriptionZh,
    this.dataType = '',
    this.nutrientCount = 0,
    this.nutrients = const [],
  });

  String get displayName =>
      descriptionZh?.isNotEmpty == true ? descriptionZh! : description;

  factory UsdaFood.fromJson(Map<String, dynamic> json) {
    return UsdaFood(
      fdcId: _asInt(json['fdc_id'] ?? json['fdcId']) ?? 0,
      description: json['description']?.toString() ?? '',
      descriptionZh: json['description_zh']?.toString(),
      dataType: json['data_type']?.toString() ?? '',
      nutrientCount: _asInt(json['nutrient_count']) ?? 0,
      nutrients: [
        for (final item in (json['nutrients'] as List? ?? const []))
          UsdaNutrient.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class UsdaNutrient {
  final String name;
  final String? nameZh;
  final double amount;
  final String unit;

  const UsdaNutrient({
    required this.name,
    this.nameZh,
    required this.amount,
    required this.unit,
  });

  String get displayName => nameZh?.isNotEmpty == true ? nameZh! : name;

  factory UsdaNutrient.fromJson(Map<String, dynamic> json) {
    return UsdaNutrient(
      name: json['name']?.toString() ?? '',
      nameZh: json['name_zh']?.toString(),
      amount: _asDouble(json['amount']) ?? 0,
      unit: json['unit_name']?.toString() ?? json['unit']?.toString() ?? '',
    );
  }
}

/// 后端在 message 中区分管理员直写、补空自动通过和待审核。
class MutationReviewResult {
  final bool applied;
  final bool pending;
  final String message;
  final Map<String, dynamic> raw;

  const MutationReviewResult({
    required this.applied,
    required this.pending,
    required this.message,
    required this.raw,
  });

  factory MutationReviewResult.fromJson(Map<String, dynamic> json) {
    final message = json['message']?.toString() ?? '';
    final status = json['status']?.toString().toLowerCase() ?? '';
    final pending = status == 'pending' ||
        message.contains('待管理员审核') ||
        message.contains('status=pending');
    return MutationReviewResult(
      applied: !pending,
      pending: pending,
      message: message,
      raw: json,
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
