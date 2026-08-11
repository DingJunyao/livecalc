/// 粘贴文本价格解析器（移植 web 端 pastePriceParser.ts）。
///
/// 支持格式（名称与价格之间用空格分隔）：
///   名称 价格            -> 芹菜 1.88            (默认 1 斤)
///   名称 价格/单位       -> 芽菇 4/袋            (1 袋)
///   名称 价格/缩写单位   -> 嫩豆腐 5.18/kg       (1 kg)
///   名称 价格/数量+单位  -> 土豆粉 2.5/200g      (200 g)
class ParsedPriceLine {
  /// 原始行（未 trim）
  final String raw;

  /// 商品名（解析失败时为空串）
  final String name;

  /// 价格（解析失败或无效时为 null）
  final double? price;

  /// 数量（默认 1）
  final double quantity;

  /// 单位（已 normalize，默认 '斤'）
  final String unit;

  /// 是否解析成功
  final bool ok;

  /// 失败原因（ok=false 时填）
  final String? error;

  const ParsedPriceLine({
    required this.raw,
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
    required this.ok,
    this.error,
  });
}

/// 中文单位别名 → 系统缩写（克=g、千克=kg、公斤=kg；「斤」保持原样不转）
const Map<String, String> _kUnitAliases = {
  '克': 'g',
  '公斤': 'kg',
  '千克': 'kg',
};

/// 名称(非贪婪) 价格 [/[数量]单位]
/// 组1 名称 | 组2 价格 | 组3 数量(可空) | 组4 单位(可空)
/// 中文单位范围用 一-龥（Dart RegExp 支持）。
final RegExp _kLineRe = RegExp(
  r'^(.+?)\s+(\d+(?:\.\d+)?)(?:/(\d*\.?\d*)\s*([A-Za-z一-龥]+))?\s*$',
);

/// 单位归一化：查别名表，查不到原样返回。
String normalizeUnit(String raw) => _kUnitAliases[raw] ?? raw;

/// 解析单行。
///
/// 边界（按顺序判定）：trim 后空串 → '空行'；'#' 开头 → '注释行'；
/// 正则不匹配 → '格式无法识别'；name 为空 → '商品名为空'；
/// price 非有限或 ≤0 → '价格无效'。
ParsedPriceLine parsePasteLine(String line, {String defaultUnit = '斤'}) {
  final trimmed = line.trim();

  if (trimmed.isEmpty) {
    return ParsedPriceLine(
      raw: line,
      name: '',
      price: null,
      quantity: 0,
      unit: '',
      ok: false,
      error: '空行',
    );
  }
  if (trimmed.startsWith('#')) {
    return ParsedPriceLine(
      raw: line,
      name: '',
      price: null,
      quantity: 0,
      unit: '',
      ok: false,
      error: '注释行',
    );
  }

  final match = _kLineRe.firstMatch(trimmed);
  if (match == null) {
    return ParsedPriceLine(
      raw: line,
      name: '',
      price: null,
      quantity: 0,
      unit: '',
      ok: false,
      error: '格式无法识别',
    );
  }

  final name = match.group(1)!.trim();
  final price = double.tryParse(match.group(2)!);
  final qtyStr = match.group(3) ?? ''; // 可能为空串
  final unitStr = match.group(4); // 可能为 null

  final quantity = qtyStr.isNotEmpty ? (double.tryParse(qtyStr) ?? 1) : 1.0;
  final unit = unitStr != null && unitStr.isNotEmpty
      ? normalizeUnit(unitStr)
      : defaultUnit;

  if (name.isEmpty) {
    return ParsedPriceLine(
      raw: line,
      name: '',
      price: price,
      quantity: quantity,
      unit: unit,
      ok: false,
      error: '商品名为空',
    );
  }
  if (price == null || price.isNaN || !price.isFinite || price <= 0) {
    return ParsedPriceLine(
      raw: line,
      name: name,
      price: price,
      quantity: quantity,
      unit: unit,
      ok: false,
      error: '价格无效',
    );
  }

  return ParsedPriceLine(
    raw: line,
    name: name,
    price: price,
    quantity: quantity,
    unit: unit,
    ok: true,
  );
}

/// 解析多行文本（按 \r?\n 拆行）。
List<ParsedPriceLine> parsePasteText(String text, {String defaultUnit = '斤'}) {
  return text
      .split(RegExp(r'\r?\n'))
      .map((l) => parsePasteLine(l, defaultUnit: defaultUnit))
      .toList();
}
