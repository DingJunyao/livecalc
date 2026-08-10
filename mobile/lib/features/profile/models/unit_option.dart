/// GET /units/ 返回的单位条目（只取界面需要的字段）。
class UnitOption {
  final int id;
  final String name;
  final String abbreviation;
  final String unitType; // mass/volume/length/count/vague

  const UnitOption({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.unitType,
  });

  factory UnitOption.fromJson(Map<String, dynamic> json) {
    return UnitOption(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      abbreviation: json['abbreviation'] as String? ?? '',
      unitType: json['unit_type'] as String? ?? '',
    );
  }
}
