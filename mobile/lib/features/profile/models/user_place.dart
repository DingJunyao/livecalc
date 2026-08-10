class UserPlace {
  final int id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String? kind; // home, work, custom
  final bool isDefault;
  final double? viewRadiusKm;

  const UserPlace({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.kind,
    this.isDefault = false,
    this.viewRadiusKm,
  });

  factory UserPlace.fromJson(Map<String, dynamic> json) {
    return UserPlace(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      kind: json['kind'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      viewRadiusKm: (json['view_radius_km'] as num?)?.toDouble(),
    );
  }

  UserPlace copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? kind,
    bool? isDefault,
    double? viewRadiusKm,
  }) {
    return UserPlace(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      kind: kind ?? this.kind,
      isDefault: isDefault ?? this.isDefault,
      viewRadiusKm: viewRadiusKm ?? this.viewRadiusKm,
    );
  }
}
