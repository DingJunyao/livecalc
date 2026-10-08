import '../../../core/api/api_client.dart';

/// 手动加入黑名单的原料条目（GET /blacklist）。
class BlacklistItem {
  final int id;
  final int ingredientId;
  final String? ingredientName;
  final String? reason;
  final String source;

  const BlacklistItem({
    required this.id,
    required this.ingredientId,
    this.ingredientName,
    this.reason,
    this.source = 'manual',
  });

  factory BlacklistItem.fromJson(Map<String, dynamic> json) {
    return BlacklistItem(
      id: _asInt(json['id']) ?? 0,
      ingredientId: _asInt(json['ingredient_id']) ?? 0,
      ingredientName: json['ingredient_name']?.toString(),
      reason: json['reason']?.toString(),
      source: json['source']?.toString() ?? 'manual',
    );
  }
}

/// 公开黑名单分组（GET /blacklist-groups，可订阅）。
class BlacklistGroup {
  final int id;
  final String name;
  final List<int> ingredientIds;

  const BlacklistGroup({
    required this.id,
    required this.name,
    this.ingredientIds = const [],
  });

  factory BlacklistGroup.fromJson(Map<String, dynamic> json) {
    return BlacklistGroup(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      ingredientIds: [
        for (final id in (json['ingredient_ids'] as List? ?? const []))
          if (_asInt(id) != null)
            _asInt(id)!,
      ],
    );
  }
}

/// 已订阅分组及其原料明细（GET /blacklist/groups）。
class SubscribedBlacklistGroup {
  final int id;
  final String name;
  final int ingredientCount;
  final List<BlacklistGroupIngredient> ingredients;

  const SubscribedBlacklistGroup({
    required this.id,
    required this.name,
    this.ingredientCount = 0,
    this.ingredients = const [],
  });

  factory SubscribedBlacklistGroup.fromJson(Map<String, dynamic> json) {
    return SubscribedBlacklistGroup(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      ingredientCount: _asInt(json['ingredient_count']) ?? 0,
      ingredients: [
        for (final item in (json['ingredients'] as List? ?? const []))
          BlacklistGroupIngredient.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class BlacklistGroupIngredient {
  final int id;
  final String name;

  const BlacklistGroupIngredient({required this.id, required this.name});

  factory BlacklistGroupIngredient.fromJson(Map<String, dynamic> json) {
    return BlacklistGroupIngredient(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

/// 个人黑名单（过敏原屏蔽）：分组订阅 + 手动增删。
/// 与 web 端 BlacklistDialog 走相同端点。
class BlacklistRepository {
  final ApiClient _client;
  BlacklistRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  Future<List<BlacklistItem>> getManualItems({int limit = 1000}) async {
    final response = await _client.dio.get(
      '/blacklist',
      queryParameters: {'limit': limit},
    );
    final data = response.data;
    final list = (data is List) ? data : ((data['items'] as List?) ?? const []);
    return list
        .map((e) => BlacklistItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BlacklistGroup>> getGroups() async {
    final response = await _client.dio.get('/blacklist-groups');
    final data = response.data;
    final list = (data is List) ? data : ((data['items'] as List?) ?? const []);
    return list
        .map((e) => BlacklistGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SubscribedBlacklistGroup>> getSubscribedGroups() async {
    final response = await _client.dio.get('/blacklist/groups');
    final data = response.data;
    final list = (data is List) ? data : ((data['items'] as List?) ?? const []);
    return list
        .map((e) => SubscribedBlacklistGroup.fromJson(
              e as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> subscribeGroup(int groupId) async {
    await _client.dio.post(
      '/blacklist/groups',
      data: {'group_ids': [groupId]},
    );
  }

  Future<void> unsubscribeGroup(int groupId) async {
    await _client.dio.delete('/blacklist/groups/$groupId');
  }

  Future<void> addManual({required int ingredientId}) async {
    await _client.dio.post('/blacklist', data: {'ingredient_id': ingredientId});
  }

  Future<void> removeManual({required int ingredientId}) async {
    await _client.dio.delete('/blacklist/$ingredientId');
  }
}
