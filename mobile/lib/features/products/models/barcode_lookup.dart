class BarcodeLookupProduct {
  final int? id;
  final String? barcode;
  final String? name;
  final String? brand;
  final String? spec;
  final String? manufacturer;
  final String? imageUrl;

  const BarcodeLookupProduct({
    this.id,
    this.barcode,
    this.name,
    this.brand,
    this.spec,
    this.manufacturer,
    this.imageUrl,
  });

  factory BarcodeLookupProduct.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BarcodeLookupProduct();
    return BarcodeLookupProduct(
      id: json['id'] as int?,
      barcode: json['barcode'] as String?,
      name: json['name'] as String?,
      brand: json['brand'] as String?,
      spec: json['spec'] as String?,
      manufacturer: json['manufacturer'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class BarcodeLookupResult {
  final bool found;
  final String? source;
  final BarcodeLookupProduct product;
  final List<String> errors;

  const BarcodeLookupResult({
    required this.found,
    this.source,
    this.product = const BarcodeLookupProduct(),
    this.errors = const [],
  });

  factory BarcodeLookupResult.fromJson(Map<String, dynamic> json) {
    return BarcodeLookupResult(
      found: json['found'] as bool? ?? false,
      source: json['source'] as String?,
      product: BarcodeLookupProduct.fromJson(
        json['product'] is Map
            ? Map<String, dynamic>.from(json['product'] as Map)
            : null,
      ),
      errors: (json['errors'] as List?)
              ?.map((error) => error.toString())
              .toList() ??
          const [],
    );
  }
}
