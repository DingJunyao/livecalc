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
}
