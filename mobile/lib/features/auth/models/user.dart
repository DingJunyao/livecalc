import '../../../core/api/api_client.dart';

/// 单位偏好中的一个单位（后端 UnitPreference：id/name/abbreviation）。
class UnitPreference {
  final int id;
  final String name;
  final String abbreviation;

  const UnitPreference({
    required this.id,
    required this.name,
    required this.abbreviation,
  });

  factory UnitPreference.fromJson(Map<String, dynamic> json) {
    return UnitPreference(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      abbreviation: json['abbreviation'] as String? ?? '',
    );
  }
}

/// 用户的单位偏好（后端 unit_preferences，字段均可为 null）。
class UnitPreferences {
  final String? energyUnit; // kcal | kJ
  final UnitPreference? massUnit;
  final UnitPreference? volumeUnit;
  final UnitPreference? priceUnit;

  const UnitPreferences({
    this.energyUnit,
    this.massUnit,
    this.volumeUnit,
    this.priceUnit,
  });

  factory UnitPreferences.fromJson(Map<String, dynamic> json) {
    UnitPreference? pref(String key) {
      final v = json[key];
      if (v is Map<String, dynamic>) return UnitPreference.fromJson(v);
      return null;
    }

    return UnitPreferences(
      energyUnit: json['energy_unit'] as String?,
      massUnit: pref('mass_unit'),
      volumeUnit: pref('volume_unit'),
      priceUnit: pref('price_unit'),
    );
  }
}

class User {
  final int id;
  final String username;
  final String email;
  final String? phone;
  final bool isAdmin;
  final String? avatar;
  final String? nickname;
  final Map<String, double?> nutritionGoals;
  final double? dailyBudget;
  final UnitPreferences? unitPreferences;

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
    this.isAdmin = false,
    this.avatar,
    this.nickname,
    this.nutritionGoals = const {},
    this.dailyBudget,
    this.unitPreferences,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final goals = <String, double?>{};
    final rawGoals = json['nutrition_goals'];
    if (rawGoals is Map<String, dynamic>) {
      rawGoals.forEach((key, value) {
        goals[key] = (value as num?)?.toDouble();
      });
    }
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      avatar: json['avatar'] as String?,
      nickname: json['nickname'] as String?,
      nutritionGoals: goals,
      dailyBudget: (json['daily_budget'] as num?)?.toDouble(),
      unitPreferences: json['unit_preferences'] is Map<String, dynamic>
          ? UnitPreferences.fromJson(
              json['unit_preferences'] as Map<String, dynamic>)
          : null,
    );
  }

  /// 显示名：昵称优先，无昵称回退用户名（对齐 web displayName）。
  String get displayName {
    final n = nickname;
    return (n != null && n.isNotEmpty) ? n : username;
  }

  /// 头像 URL：avatar 是 storage key，经 /api/v1/images/ 公开重定向加载。
  String? get avatarUrl {
    final a = avatar;
    if (a == null || a.isEmpty) return null;
    return '${ApiClient.instance.baseUrl}/api/v1/images/$a';
  }
}
