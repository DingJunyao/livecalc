import '../../../core/api/api_client.dart';

double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

int _asInt(dynamic v, [int fallback = 0]) => _toIntOrNull(v) ?? fallback;

bool _asBool(dynamic v, [bool fallback = false]) =>
    v is bool ? v : (v is String ? v == 'true' : fallback);

String? _asString(dynamic v) => v?.toString();

String? _firstImageUrl(Map<String, dynamic> json) {
  final List? urls = (json['image_urls'] is List)
      ? json['image_urls'] as List
      : (json['images'] is List ? json['images'] as List : null);
  if (urls == null || urls.isEmpty) return null;
  final raw = urls.first?.toString();
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http')) return raw;
  final base = ApiClient.instance.baseUrl;
  return base.isEmpty ? raw : '$base$raw';
}

/// 解析完整图片 URL 列表（image_urls 已是完整 URL；兼容 images 相对路径）
List<String> _imageUrls(Map<String, dynamic> json) {
  final List? urls = (json['image_urls'] is List)
      ? json['image_urls'] as List
      : (json['images'] is List ? json['images'] as List : null);
  if (urls == null) return const [];
  final base = ApiClient.instance.baseUrl;
  return urls
      .map((e) => e?.toString() ?? '')
      .where((s) => s.isNotEmpty)
      .map((s) => s.startsWith('http') ? s : (base.isEmpty ? s : '$base$s'))
      .toList();
}

class QuantityRange {
  final double min;
  final double max;
  const QuantityRange({required this.min, required this.max});

  factory QuantityRange.fromJson(dynamic v) {
    if (v is Map) {
      return QuantityRange(
        min: _toDoubleOrNull(v['min']) ?? 0,
        max: _toDoubleOrNull(v['max']) ?? 0,
      );
    }
    if (v is String) {
      final parts = v.split(RegExp(r'[-~]'));
      if (parts.length == 2) {
        return QuantityRange(
          min: double.tryParse(parts[0].trim()) ?? 0,
          max: double.tryParse(parts[1].trim()) ?? 0,
        );
      }
    }
    return const QuantityRange(min: 0, max: 0);
  }
}

class RecipeIngredient {
  final int? id;
  final int? ingredientId;
  final String name;
  final String? quantity;
  final QuantityRange? quantityRange;
  final String? unit;
  final bool isOptional;
  final String? note;
  final String? originalQuantity;

  const RecipeIngredient({
    this.id,
    this.ingredientId,
    required this.name,
    this.quantity,
    this.quantityRange,
    this.unit,
    this.isOptional = false,
    this.note,
    this.originalQuantity,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: _toIntOrNull(json['id']),
      ingredientId: _toIntOrNull(json['ingredient_id']),
      name: json['name'] as String? ?? json['ingredient_name'] as String? ?? '',
      quantity: json['quantity']?.toString(),
      quantityRange: json['quantity_range'] != null
          ? QuantityRange.fromJson(json['quantity_range'])
          : null,
      unit: _asString(json['unit']),
      isOptional: _asBool(json['is_optional']),
      note: _asString(json['note']),
      originalQuantity: json['original_quantity']?.toString(),
    );
  }
}

class RecipeStep {
  final int stepNumber;
  final String content;
  final String? imageUrl;
  final double? durationMinutes;
  final String? tips;

  const RecipeStep({
    required this.stepNumber,
    required this.content,
    this.imageUrl,
    this.durationMinutes,
    this.tips,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      stepNumber:
          _toIntOrNull(json['step']) ?? _toIntOrNull(json['step_number']) ?? 0,
      content: json['content'] as String? ?? '',
      imageUrl: _asString(json['image_url']),
      durationMinutes: _toDoubleOrNull(json['duration_minutes']),
      tips: _asString(json['tips']),
    );
  }
}

class RecipeDetail {
  final int id;
  final int? userId;
  final String name;
  final String? description;
  final String? category;
  final String? difficulty;
  final int servings;
  final int? totalTimeMinutes;
  final List<String> tags;
  final String? imageUrl;
  final List<String> imageUrls;
  final List<String> images;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final List<String> tips;
  final bool isPublic;
  final int? resultIngredientId;
  final List<RecipePendingProposal> pendingProposals;
  final RecipePendingProposal? pendingProposal;

  const RecipeDetail({
    required this.id,
    this.userId,
    required this.name,
    this.description,
    this.category,
    this.difficulty,
    this.servings = 1,
    this.totalTimeMinutes,
    this.tags = const [],
    this.imageUrl,
    this.imageUrls = const [],
    this.images = const [],
    this.ingredients = const [],
    this.steps = const [],
    this.tips = const [],
    this.isPublic = false,
    this.resultIngredientId,
    this.pendingProposals = const [],
    this.pendingProposal,
  });

  factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    final stepsJson = (json['cooking_steps'] is List)
        ? json['cooking_steps'] as List<dynamic>
        : (json['steps'] as List<dynamic>? ?? const []);
    final tipsRaw = json['tips'];
    final tipsList = <String>[];
    if (tipsRaw is List) {
      tipsList.addAll(
          tipsRaw.whereType<String>().where((s) => s.trim().isNotEmpty));
    } else if (tipsRaw is String && tipsRaw.trim().isNotEmpty) {
      tipsList.add(tipsRaw.trim());
    }
    final pendingProposalsJson = json['pending_proposals'];
    final pendingProposals = <RecipePendingProposal>[
      if (pendingProposalsJson is List)
        for (final item in pendingProposalsJson)
          if (item is Map<String, dynamic>)
            RecipePendingProposal.fromJson(item),
    ];
    final pendingProposalJson = json['pending_proposal'];
    if (pendingProposals.isEmpty &&
        pendingProposalJson is Map<String, dynamic>) {
      pendingProposals.add(RecipePendingProposal.fromJson(pendingProposalJson));
    }
    return RecipeDetail(
      id: _asInt(json['id']),
      userId: _toIntOrNull(json['user_id']),
      name: json['name'] as String? ?? '',
      description: _asString(json['description']),
      category: _asString(json['category']),
      difficulty: _asString(json['difficulty']),
      servings: _asInt(json['servings'], 1),
      totalTimeMinutes: _toIntOrNull(json['total_time_minutes']),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      imageUrl: _firstImageUrl(json),
      imageUrls: _imageUrls(json),
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      steps: stepsJson
          .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      tips: tipsList,
      isPublic: _asBool(json['is_public']),
      resultIngredientId: _toIntOrNull(json['result_ingredient_id']),
      pendingProposals: pendingProposals,
      pendingProposal: pendingProposals.isEmpty ? null : pendingProposals.last,
    );
  }

  /// Web 详情页把 recipe_edit 的 update_data 覆盖到当前详情后展示。
  RecipeDetail mergedWithPending() {
    var current = this;
    for (final proposal in pendingProposals) {
      current = current._mergedWithProposal(proposal);
    }
    return current;
  }

  String get pendingChangeSummary => [
        for (final field in {
          for (final proposal in pendingProposals) ...proposal.updateData.keys,
        })
          RecipePendingProposal.fieldLabel(field),
      ].join('、');

  RecipeDetail _mergedWithProposal(RecipePendingProposal proposal) {
    final data = proposal.updateData;
    return RecipeDetail(
      id: id,
      userId: userId,
      name: data['name']?.toString() ?? name,
      description: data.containsKey('description')
          ? _asString(data['description'])
          : description,
      category:
          data.containsKey('category') ? _asString(data['category']) : category,
      difficulty: data.containsKey('difficulty')
          ? _asString(data['difficulty'])
          : difficulty,
      servings: _toIntOrNull(data['servings']) ?? servings,
      totalTimeMinutes: data.containsKey('total_time_minutes')
          ? _toIntOrNull(data['total_time_minutes'])
          : totalTimeMinutes,
      tags: data['tags'] is List
          ? (data['tags'] as List).map((e) => e.toString()).toList()
          : tags,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      images: data['images'] is List
          ? (data['images'] as List).map((e) => e.toString()).toList()
          : images,
      ingredients: data['ingredients'] is List
          ? [
              for (final item in data['ingredients'] as List)
                if (item is Map<String, dynamic>)
                  RecipeIngredient.fromJson(item),
            ]
          : ingredients,
      steps: data['cooking_steps'] is List
          ? [
              for (final item in data['cooking_steps'] as List)
                if (item is Map<String, dynamic>) RecipeStep.fromJson(item),
            ]
          : steps,
      tips: data['tips'] is List
          ? (data['tips'] as List).map((e) => e.toString()).toList()
          : tips,
      isPublic: isPublic,
      resultIngredientId: data.containsKey('result_ingredient_id')
          ? _toIntOrNull(data['result_ingredient_id'])
          : resultIngredientId,
      pendingProposals: pendingProposals,
      pendingProposal: proposal,
    );
  }
}

class RecipePendingProposal {
  final int id;
  final String action;
  final Map<String, dynamic> updateData;

  static const _fieldLabels = {
    'name': '菜谱名称',
    'source': '来源',
    'category': '分类',
    'tags': '标签',
    'cooking_steps': '做法步骤',
    'total_time_minutes': '总时间',
    'difficulty': '难度',
    'servings': '份数',
    'tips': '小贴士',
    'description': '简介',
    'images': '配图',
    'ingredients': '原料',
    'result_ingredient_id': '成品产出原料',
  };

  const RecipePendingProposal({
    required this.id,
    required this.action,
    required this.updateData,
  });

  factory RecipePendingProposal.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    Map<String, dynamic> updateData = {};
    if (payload is Map<String, dynamic>) {
      final nested = payload['update_data'];
      if (nested is Map<String, dynamic>) {
        updateData = nested;
      } else {
        updateData = payload;
      }
    }
    return RecipePendingProposal(
      id: _asInt(json['id']),
      action: json['action']?.toString() ?? 'update',
      updateData: updateData,
    );
  }

  static String fieldLabel(String field) => _fieldLabels[field] ?? field;

  String get changeSummary => [
        for (final field in updateData.keys) fieldLabel(field),
      ].join('、');
}
