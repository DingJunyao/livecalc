import '../../../shared/models/entity_pending_proposal.dart';

class Ingredient {
  final int id;
  final String name;
  final int? categoryId;
  final String? category;
  final String? categoryPath;
  final double? latestPrice;
  final String? unit;
  final List<String> aliases;
  final String? createdAt;
  final String? makingRecipeName;
  final EntityPendingProposal? pendingProposal;

  const Ingredient({
    required this.id,
    required this.name,
    this.categoryId,
    this.category,
    this.categoryPath,
    this.latestPrice,
    this.unit,
    this.aliases = const [],
    this.createdAt,
    this.makingRecipeName,
    this.pendingProposal,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      categoryId: json['category_id'] as int?,
      category: json['category'] as String?,
      categoryPath: json['category_path'] as String?,
      latestPrice: (json['latest_price'] as num?)?.toDouble(),
      unit: json['default_unit'] as String?,
      aliases: (json['aliases'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: json['created_at'] as String?,
      makingRecipeName: json['making_recipe_name'] as String?,
      pendingProposal: json['pending_proposal'] is Map<String, dynamic>
          ? EntityPendingProposal.fromJson(
              json['pending_proposal'] as Map<String, dynamic>)
          : null,
    );
  }

  Ingredient mergedWithPending() {
    final proposal = pendingProposal;
    if (proposal?.action != 'update') return this;
    final data = proposal!.updateData;
    return Ingredient(
      id: id,
      name: data['name']?.toString() ?? name,
      categoryId: data.containsKey('category_id')
          ? data['category_id'] as int?
          : categoryId,
      category: data.containsKey('category_id')
          ? (data['category']?.toString() ?? '分类 #${data['category_id']}')
          : category,
      categoryPath: categoryPath,
      latestPrice: latestPrice,
      unit: unit,
      aliases: data['aliases'] is List
          ? (data['aliases'] as List).map((e) => e.toString()).toList()
          : aliases,
      createdAt: createdAt,
      makingRecipeName: makingRecipeName,
      pendingProposal: proposal,
    );
  }

  List<String> get pendingModificationLabels {
    final proposal = pendingProposal;
    if (proposal?.action != 'update') return const [];
    return [
      for (final field in proposal!.updateData.keys)
        switch (field) {
          'name' => '名称',
          'category_id' => '分类',
          'aliases' => '别名',
          _ => field,
        },
    ];
  }
}
