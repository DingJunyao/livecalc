/// 商品/原料两两数量关联：一条关联 = 一句等式。
///
/// 语义：q_current [u_current] current = q_other [u_other] other
/// 与后端 entity_link_service / Web utils/entityLinks 同口径。
class EntityLinkSide {
  final String type;
  final int id;
  final String? name;
  final double quantity;
  final String unit;
  final int? ingredientId;

  const EntityLinkSide({
    required this.type,
    required this.id,
    this.name,
    required this.quantity,
    required this.unit,
    this.ingredientId,
  });

  factory EntityLinkSide.fromJson(Map<String, dynamic> json) {
    return EntityLinkSide(
      type: json['type']?.toString() ?? 'product',
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit']?.toString() ?? '',
      ingredientId: (json['ingredient_id'] as num?)?.toInt(),
    );
  }

  String get typeLabel => type;
}

class EntityQuantityLink {
  final int id;
  final EntityLinkSide current;
  final EntityLinkSide other;
  final double otherPerCurrent;
  final double currentPerOther;
  final double? gramsPerCurrentUnit;
  final double? gramsPerOtherUnit;
  final bool resolvable;
  final String? note;
  final double? otherLatestPrice;
  final String? otherLatestPriceUnit;
  final double? equivalentCurrentPrice;
  final bool isStale;
  final bool pending;

  const EntityQuantityLink({
    required this.id,
    required this.current,
    required this.other,
    required this.otherPerCurrent,
    required this.currentPerOther,
    this.gramsPerCurrentUnit,
    this.gramsPerOtherUnit,
    this.resolvable = false,
    this.note,
    this.otherLatestPrice,
    this.otherLatestPriceUnit,
    this.equivalentCurrentPrice,
    this.isStale = false,
    this.pending = false,
  });

  factory EntityQuantityLink.fromJson(Map<String, dynamic> json) {
    final current = Map<String, dynamic>.from(json['current'] as Map);
    final other = Map<String, dynamic>.from(json['other'] as Map);
    return EntityQuantityLink(
      id: (json['id'] as num?)?.toInt() ?? 0,
      current: EntityLinkSide.fromJson(current),
      other: EntityLinkSide.fromJson(other),
      otherPerCurrent: (json['other_per_current'] as num?)?.toDouble() ?? 0,
      currentPerOther: (json['current_per_other'] as num?)?.toDouble() ?? 0,
      gramsPerCurrentUnit: (json['grams_per_current_unit'] as num?)?.toDouble(),
      gramsPerOtherUnit: (json['grams_per_other_unit'] as num?)?.toDouble(),
      resolvable: json['resolvable'] == true,
      note: json['note']?.toString(),
      otherLatestPrice: (json['other_latest_price'] as num?)?.toDouble(),
      otherLatestPriceUnit: json['other_latest_price_unit']?.toString(),
      equivalentCurrentPrice:
          (json['equivalent_current_price'] as num?)?.toDouble(),
      isStale: json['is_stale'] == true,
      pending: json['pending'] == true,
    );
  }

  String get sentence {
    return '${_qty(current.quantity)} ${current.unit} ${current.name ?? '—'}'
        ' = ${_qty(other.quantity)} ${other.unit} ${other.name ?? '—'}';
  }

  String? get gramsSelfCheck {
    if (!resolvable || gramsPerCurrentUnit == null) return null;
    final grams = gramsPerCurrentUnit!;
    if (!grams.isFinite || grams <= 0) return null;
    return '1 ${current.unit} ≈ ${_qty(grams)} g';
  }

  static String _qty(double value) {
    if (!value.isFinite) return '?';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
