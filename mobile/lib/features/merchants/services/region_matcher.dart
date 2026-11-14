import '../repositories/merchant_repository.dart';

/// 按名称逐级匹配行政区划，返回最深命中的 region id。
///
/// 纯客户端实现：复用 GET /regions 懒加载接口逐层下钻。国家用
/// iso_country 精确匹配（不受设备语言影响，兜底按 country 的中英文名）；
/// 省/市/县按名称先精确、再剥离行政区后缀归一比较。任何一级失配停在
/// 上一层（currency 跟随地区仍有意义），无国家锚或全空候选返回 null。
/// best-effort：失配时表单仍可手动选择。
Future<int?> matchRegionId(
  MerchantRepository repository, {
  String? countryCode,
  String? country,
  String? administrativeArea,
  String? locality,
  String? subLocality,
}) async {
  try {
    if (administrativeArea == null &&
        locality == null &&
        subLocality == null) {
      return null;
    }
    final countries = await repository.listRegions(level: 0);
    final root = _matchCountry(countries, countryCode, country);
    if (root == null) return null;
    final rootId = (root['id'] as num?)?.toInt();
    if (rootId == null) return null;
    var nodeId = rootId;

    // 省 → 市 → 区县；市/区两级共用 locality/subLocality 两个候选
    // （直辖市行政区划名称在两级之间位置不定，两级都试）。
    for (final candidates in [
      [administrativeArea],
      [locality, subLocality],
      [locality, subLocality],
    ]) {
      final matched = await _descend(repository, nodeId, candidates);
      if (matched != null) nodeId = matched;
    }
    return nodeId;
  } catch (_) {
    return null;
  }
}

/// 在 [parentId] 的子级里匹配 [candidates]；唯一子节点（如「市辖区」
/// 单链层级）不命中时自动下穿一层再试，最多穿两层。
Future<int?> _descend(
  MerchantRepository repository,
  int parentId,
  List<String?> candidates,
) async {
  final unique = <String>[
    for (final candidate in candidates)
      if (candidate != null && candidate.trim().isNotEmpty) candidate.trim(),
  ];
  if (unique.isEmpty) return null;

  var children = await repository.listRegions(parentId: parentId);
  for (var bypass = 0; bypass < 2; bypass++) {
    final matched = _matchAmong(children, unique);
    if (matched != null) return matched;
    if (children.length != 1) return null;
    final onlyId = (children.first['id'] as num?)?.toInt();
    if (onlyId == null) return null;
    children = await repository.listRegions(parentId: onlyId);
  }
  return null;
}

/// 先按精确名匹配，再按剥后缀归一名匹配，避免「朝阳区/朝阳市」类误命中。
int? _matchAmong(List<Map<String, dynamic>> rows, List<String> candidates) {
  for (final candidate in candidates) {
    for (final row in rows) {
      if (row['name']?.toString() == candidate) {
        return (row['id'] as num?)?.toInt();
      }
    }
  }
  for (final candidate in candidates) {
    final normalized = _normalizeName(candidate);
    if (normalized == null) continue;
    for (final row in rows) {
      final rowName = _normalizeName(row['name']?.toString());
      if (rowName != null &&
          (rowName == normalized || rowName.startsWith(normalized))) {
        return (row['id'] as num?)?.toInt();
      }
    }
  }
  return null;
}

/// 国家锚：iso_country 精确优先，兜底按中/英文名匹配。
Map<String, dynamic>? _matchCountry(
  List<Map<String, dynamic>> rows,
  String? countryCode,
  String? country,
) {
  final code = countryCode?.trim().toUpperCase() ?? '';
  if (code.isNotEmpty) {
    for (final row in rows) {
      if (row['iso_country']?.toString().toUpperCase() == code) return row;
    }
  }
  final name = country?.trim() ?? '';
  if (name.isNotEmpty) {
    for (final row in rows) {
      if (row['name']?.toString() == name ||
          row['name_en']?.toString() == name) {
        return row;
      }
    }
  }
  return null;
}

/// 剥离尾部行政区后缀后归一（北京市→北京 / 朝阳区→朝阳 / 新疆维吾尔
/// 自治区→新疆维吾尔）。双侧同规则剥离，可安全处理「沙市/沙市区」类全剥。
String? _normalizeName(String? raw) {
  if (raw == null) return null;
  var name = raw.trim();
  if (name.isEmpty) return null;
  const suffixes = [
    '特别行政区', '自治区', '自治州', '林区', '地区', '盟', '省', '市', '县', '区', '旗',
  ];
  bool changed = true;
  while (changed) {
    changed = false;
    for (final suffix in suffixes) {
      if (name.length > suffix.length && name.endsWith(suffix)) {
        name = name.substring(0, name.length - suffix.length);
        changed = true;
        break;
      }
    }
  }
  return name;
}
