import '../../../shared/models/entity_pending_proposal.dart';

class Product {
  final int id;
  final String name;
  final int? ingredientId;
  final String? ingredientName;
  final double? latestPrice;
  final String? unit;
  final String? barcode;
  final String? brand;
  final List<String> aliases;
  final List<String> tags;
  final String? createdAt;
  final String? latestPriceDate;
  final EntityPendingProposal? pendingProposal;

  const Product({
    required this.id,
    required this.name,
    this.ingredientId,
    this.ingredientName,
    this.latestPrice,
    this.unit,
    this.barcode,
    this.brand,
    this.aliases = const [],
    this.tags = const [],
    this.createdAt,
    this.latestPriceDate,
    this.pendingProposal,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      ingredientId: json['ingredient_id'] as int?,
      ingredientName: json['ingredient_name'] as String?,
      latestPrice: (json['latest_price'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      barcode: json['barcode'] as String?,
      brand: json['brand'] as String?,
      aliases: (json['aliases'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: json['created_at'] as String?,
      latestPriceDate: json['latest_price_date'] as String?,
      pendingProposal: json['pending_proposal'] is Map<String, dynamic>
          ? EntityPendingProposal.fromJson(
              json['pending_proposal'] as Map<String, dynamic>)
          : null,
    );
  }

  Product mergedWithPending() {
    final proposal = pendingProposal;
    if (proposal?.action != 'update') return this;
    final data = proposal!.updateData;
    return Product(
      id: id,
      name: data['name']?.toString() ?? name,
      ingredientId: data.containsKey('ingredient_id')
          ? data['ingredient_id'] as int?
          : ingredientId,
      ingredientName: data.containsKey('ingredient_id')
          ? (data['ingredient_name']?.toString() ??
              ingredientName ??
              '原料 #${data['ingredient_id']}')
          : ingredientName,
      latestPrice: latestPrice,
      unit: unit,
      barcode:
          data.containsKey('barcode') ? data['barcode']?.toString() : barcode,
      brand: data.containsKey('brand') ? data['brand']?.toString() : brand,
      aliases: data['aliases'] is List
          ? (data['aliases'] as List).map((e) => e.toString()).toList()
          : aliases,
      tags: data['tags'] is List
          ? (data['tags'] as List).map((e) => e.toString()).toList()
          : tags,
      createdAt: createdAt,
      latestPriceDate: latestPriceDate,
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
          'brand' => '品牌',
          'barcode' => '条码',
          'ingredient_id' => '关联原料',
          'aliases' => '别名',
          'tags' => '标签',
          _ => field,
        },
    ];
  }
}
