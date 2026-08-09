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
      aliases: (json['aliases'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      tags: (json['tags'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: json['created_at'] as String?,
      latestPriceDate: json['latest_price_date'] as String?,
    );
  }
}
