/// 用户自定义计算范围（多地区组合）模型。
class CalcScopeRegion {
  final int id;
  final String name;
  final String displayName;
  final int level;

  const CalcScopeRegion({
    required this.id,
    required this.name,
    required this.displayName,
    required this.level,
  });

  factory CalcScopeRegion.fromJson(Map<String, dynamic> json) {
    return CalcScopeRegion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      level: (json['level'] as num?)?.toInt() ?? 0,
    );
  }
}

class CalcScope {
  final int id;
  final String name;
  final List<int> regionIds;
  final List<CalcScopeRegion> regions;

  /// 是否为当前用户默认计算范围（后端由 users.default_calc_scope_id 派生）。
  final bool isDefault;

  const CalcScope({
    required this.id,
    required this.name,
    required this.regionIds,
    this.regions = const [],
    this.isDefault = false,
  });

  factory CalcScope.fromJson(Map<String, dynamic> json) {
    final rawIds = json['region_ids'];
    final rawRegions = json['regions'];
    return CalcScope(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      regionIds: [
        if (rawIds is List)
          for (final v in rawIds)
            if (v is num) v.toInt(),
      ],
      regions: [
        if (rawRegions is List)
          for (final item in rawRegions)
            if (item is Map<String, dynamic>) CalcScopeRegion.fromJson(item),
      ],
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  /// 地区展示文案（display_name 优先，回退 name），供列表/卡片 subtitle。
  String get regionsSummary => regions
      .map((r) => r.displayName.isNotEmpty ? r.displayName : r.name)
      .join('、');
}
