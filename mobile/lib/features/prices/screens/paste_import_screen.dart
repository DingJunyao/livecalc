import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../repositories/price_repository.dart';
import '../utils/paste_price_parser.dart';
import '../../products/repositories/product_repository.dart';

/// 粘贴导入行的匹配模式。
enum _MatchMode { existing, newSame, newAttach }

/// 粘贴导入行的状态。
enum _RowStatus { matched, unmatched, invalid }

/// 一行可变的导入状态（解析结果 + 匹配进度）。
class _ImportRow {
  final ParsedPriceLine parsed;
  _RowStatus status;
  int? productId;
  int? ingredientId;
  _MatchMode mode = _MatchMode.newSame;
  bool editing = false;
  String productSearch = '';
  List<Map<String, dynamic>> suggestions = const [];

  /// 展开态搜索框的持久 controller（避免每次 build new 导致光标跳末尾）。
  /// 由 _openEditor 创建、_cancelEdit/_chooseExisting/_chooseNewSame 释放。
  TextEditingController? searchController;

 /// _onExistingSearch 的请求序号，用于丢弃过期的异步响应（竞态保护）。
  int searchSeq = 0;

  /// 原料搜索的状态（new_attach 模式：新建商品并关联到原料）。
  String ingredientSearch = '';
  List<Map<String, dynamic>> ingredientSuggestions = const [];
  TextEditingController? ingredientSearchController;
  int ingredientSearchSeq = 0;

  _ImportRow({required this.parsed, required this.status});
}

/// 后端返回的数字字段可能是 int 也可能是 double（如 9.0），
/// 裸 `as int` 在 double 时会抛 TypeError（不被 on Exception 接住），
/// 故统一通过此助手安全转换。
int? _toInt(dynamic v) => (v as num?)?.toInt();

/// 导入结果（成功/失败统计 + 失败明细）。
class _ImportResult {
  final int success;
  final int fail;
  final List<String> failures;
  const _ImportResult({
    required this.success,
    required this.fail,
    required this.failures,
  });
}

/// 粘贴导入价格全屏页（移植 web 端 PasteImportDialog.vue 状态机）。
///
/// 入口参数：[merchantId] 必填（与网页端 selectedMerchantId 一致）；
/// [historyProductNames] 用于「复制模板」文本生成。
/// 为测试注入，[priceRepository] / [productRepository] 缺省用真实实例。
class PasteImportScreen extends StatefulWidget {
  final int? merchantId;
  final List<String> historyProductNames;
  final PriceRepository? priceRepository;
  final ProductRepository? productRepository;

  const PasteImportScreen({
    super.key,
    required this.merchantId,
    this.historyProductNames = const <String>[],
    this.priceRepository,
    this.productRepository,
  });

  @override
  State<PasteImportScreen> createState() => _PasteImportScreenState();
}

class _PasteImportScreenState extends State<PasteImportScreen> {
  late final PriceRepository _priceRepo;
  late final ProductRepository _productRepo;
  final _rawTextController = TextEditingController();
  final _scrollController = ScrollController();

  DateTime _recordedAt = DateTime.now();
  List<_ImportRow> _rows = const [];
  bool _parsing = false;
  bool _importing = false;
  int _progressCurrent = 0;
  int _progressTotal = 0;
  _ImportResult? _result;

  /// 自动匹配 + 导入的并发上限（对齐网页端 MATCH_CONCURRENCY / CONCURRENCY = 5）。
  static const _concurrency = 5;

  @override
  void initState() {
    super.initState();
    _priceRepo = widget.priceRepository ?? PriceRepository();
    _productRepo = widget.productRepository ?? ProductRepository();
  }

  @override
  void dispose() {
    _rawTextController.dispose();
    _scrollController.dispose();
    // 释放展开行残留的搜索 controller（防异常退出泄漏）
    for (final row in _rows) {
      row.searchController?.dispose();
      row.searchController = null;
    }
    super.dispose();
  }

  /// 复制模板：每行「商品名 + 空格」拼接（对齐 web templateText computed）。
  String get _templateText =>
      widget.historyProductNames.map((n) => '$n ').join('\n');

  int get _matchedCount =>
      _rows.where((r) => r.status == _RowStatus.matched).length;
  int get _unmatchedCount =>
      _rows.where((r) => r.status == _RowStatus.unmatched).length;
  int get _invalidCount =>
      _rows.where((r) => r.status == _RowStatus.invalid).length;

  /// 可导入行：matched + ok。
  Iterable<_ImportRow> get _importable =>
      _rows.where((r) => r.status == _RowStatus.matched && r.parsed.ok);

  Future<void> _copyTemplate() async {
    await Clipboard.setData(ClipboardData(text: _templateText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制模板')),
    );
  }

  Future<void> _pickRecordedAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _recordedAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // -------- 解析 + 自动匹配 --------

  Future<void> _parse() async {
    setState(() {
      _parsing = true;
      _result = null;
    });
    try {
      final parsed = parsePasteText(_rawTextController.text, defaultUnit: '斤');
      _rows = parsed
          .map((p) => _ImportRow(
                parsed: p,
                status: p.ok ? _RowStatus.unmatched : _RowStatus.invalid,
              ))
          .toList();
      setState(() {});

      final okRows = _rows.where((r) => r.parsed.ok).toList();
      for (var i = 0; i < okRows.length; i += _concurrency) {
        final batch = okRows.skip(i).take(_concurrency).toList();
        await Future.wait(batch.map(_tryAutoMatch));
      }
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  /// 自动匹配四级优先级（对齐 web tryAutoMatch）：
  /// 商品主名 → 原料主名 → 商品别名 → 原料别名。
  Future<void> _tryAutoMatch(_ImportRow row) async {
    try {
      final list = await _productRepo.autocomplete(row.parsed.name, limit: 20);
      if (list.isEmpty) return;

      // 1. 商品主名精确匹配
      final nameMatch = list.firstWhere(
        (it) =>
            it['match_type'] == 'name' && it['name'] == row.parsed.name,
        orElse: () => const <String, dynamic>{},
      );
      final nameId = _toInt(nameMatch['id']);
      if (nameMatch.isNotEmpty && nameId != null) {
        _setAutoMatched(row, nameId);
        return;
      }

      // 2. 原料主名匹配 → 解析最佳商品
      final ingNameMatch = list.firstWhere(
        (it) => it['match_type'] == 'ingredient_name',
        orElse: () => const <String, dynamic>{},
      );
      final ingNameId = _toInt(ingNameMatch['ingredient_id']);
      if (ingNameMatch.isNotEmpty && ingNameId != null) {
        final best = _resolveIngredientProduct(
          list,
          ingNameId,
          (ingNameMatch['ingredient_name'] as String?) ?? '',
        );
        if (best != null) {
          _setAutoMatched(row, best);
          return;
        }
      }

      // 3. 商品别名匹配
      final aliasMatch = list.firstWhere(
        (it) =>
            it['match_type'] == 'alias' ||
            ((it['aliases'] as List?)?.contains(row.parsed.name) ?? false),
        orElse: () => const <String, dynamic>{},
      );
      final aliasId = _toInt(aliasMatch['id']);
      if (aliasMatch.isNotEmpty && aliasId != null) {
        _setAutoMatched(row, aliasId);
        return;
      }

      // 4. 原料别名匹配 → 解析最佳商品
      final ingAliasMatch = list.firstWhere(
        (it) =>
            it['match_type'] == 'ingredient_alias' ||
            ((it['ingredient_aliases'] as List?)?.contains(row.parsed.name) ??
                false),
        orElse: () => const <String, dynamic>{},
      );
      final ingAliasId = _toInt(ingAliasMatch['ingredient_id']);
      if (ingAliasMatch.isNotEmpty && ingAliasId != null) {
        final best = _resolveIngredientProduct(
          list,
          ingAliasId,
          (ingAliasMatch['ingredient_name'] as String?) ?? '',
        );
        if (best != null) {
          _setAutoMatched(row, best);
          return;
        }
      }
    } on Exception {
      // 保持 unmatched，用户手动处理
    }
  }

  /// 原料匹配时解析最佳商品：唯一商品 > 同名商品 > 第一个。
  /// 简化：不依赖 created_at 排序（移动端列首次实现，后续可加）。
  int? _resolveIngredientProduct(
    List<Map<String, dynamic>> list,
    int ingredientId,
    String ingredientName,
  ) {
    final products =
        list.where((it) => it['ingredient_id'] == ingredientId).toList();
    if (products.isEmpty) return null;
    final totalCount = _toInt(products.first['ingredient_product_count']) ??
        products.length;
    if (totalCount == 1) return _toInt(products.first['id']);
    final sameName = products.firstWhere(
      (p) => p['name'] == ingredientName,
      orElse: () => const <String, dynamic>{},
    );
    if (sameName.isNotEmpty) return _toInt(sameName['id']);
    return _toInt(products.first['id']);
  }

  void _setAutoMatched(_ImportRow row, int productId) {
    setState(() {
      row.productId = productId;
      row.mode = _MatchMode.existing;
      row.status = _RowStatus.matched;
    });
  }

  // -------- 手动三分支 --------

  void _openEditor(_ImportRow row) {
    // 持久 controller：仅首次展开时创建，避免 rebuild 时光标被强制跳末尾。
    // 不预填商品名：用户手动匹配时应从空白开始搜索，避免误关联同名商品。
    if (row.searchController == null) {
      row.searchController = TextEditingController();
      row.productSearch = '';
    }
    row.ingredientSearchController ??= TextEditingController();
    setState(() => row.editing = true);
  }

  void _releaseEditor(_ImportRow row) {
    row.searchController?.dispose();
    row.searchController = null;
    row.ingredientSearchController?.dispose();
    row.ingredientSearchController = null;
  }

  void _cancelEdit(_ImportRow row) {
    setState(() {
      row.editing = false;
      _releaseEditor(row);
    });
  }

  Future<void> _onExistingSearch(_ImportRow row, String query) async {
    setState(() => row.productSearch = query);
    if (query.isEmpty) {
      setState(() => row.suggestions = const []);
      return;
    }
    // 序号守卫：快速输入时旧请求晚回会被丢弃，避免覆盖最新结果
    final mySeq = ++row.searchSeq;
    try {
      final list = await _productRepo.autocomplete(query, limit: 20);
      if (!mounted || mySeq != row.searchSeq) return;
      setState(() => row.suggestions = list);
    } on Exception {
      if (!mounted || mySeq != row.searchSeq) return;
      setState(() => row.suggestions = const []);
    }
  }

  void _chooseExisting(_ImportRow row, Map<String, dynamic> opt) {
    setState(() {
      row.productId = _toInt(opt['id']);
      row.ingredientId = null;
      row.mode = _MatchMode.existing;
      row.status = _RowStatus.matched;
      row.editing = false;
      _releaseEditor(row);
    });
  }

  void _chooseNewSame(_ImportRow row) {
    setState(() {
      row.productId = null;
      row.ingredientId = null;
      row.mode = _MatchMode.newSame;
      row.status = _RowStatus.matched;
      row.editing = false;
      _releaseEditor(row);
    });
  }

  // -------- 原料搜索（new_attach 模式） --------

  Future<void> _onIngredientSearch(_ImportRow row, String query) async {
    setState(() => row.ingredientSearch = query);
    if (query.isEmpty) {
      setState(() => row.ingredientSuggestions = const []);
      return;
    }
    final mySeq = ++row.ingredientSearchSeq;
    try {
      final resp = await _priceRepo.client.dio.get(
        '/ingredients',
        queryParameters: {'q': query, 'limit': 20},
      );
      if (!mounted || mySeq != row.ingredientSearchSeq) return;
      final data = resp.data;
      final list = (data is List)
          ? data
          : ((data['items'] as List?) ?? const []);
      final items = list.cast<Map<String, dynamic>>();
      setState(() {
        row.ingredientSuggestions = items
            .map((e) => {'id': e['id'], 'name': e['name']})
            .toList();
      });
    } on Exception {
      if (!mounted || mySeq != row.ingredientSearchSeq) return;
      setState(() => row.ingredientSuggestions = const []);
    }
  }

  void _chooseAttach(_ImportRow row, Map<String, dynamic> opt) {
    setState(() {
      row.productId = null;
      row.ingredientId = _toInt(opt['id']);
      row.mode = _MatchMode.newAttach;
      row.status = _RowStatus.matched;
      row.editing = false;
      _releaseEditor(row);
    });
  }

  // -------- 导入 --------

  Future<void> _doImport() async {
    final merchantId = widget.merchantId;
    if (merchantId == null) return;
    final targets = _importable.toList();
    if (targets.isEmpty) return;

    setState(() {
      _importing = true;
      _result = null;
      _progressTotal = targets.length;
      _progressCurrent = 0;
    });

    final savedIds = <int>[];
    var success = 0;
    final failures = <String>[];

    for (var i = 0; i < targets.length; i += _concurrency) {
      final batch = targets.skip(i).take(_concurrency).toList();
      // Dart 无 Promise.allSettled：Future.wait 配合逐条 try-catch 模拟。
      final results = await Future.wait(
        batch.map((row) async {
          try {
            final record = await _priceRepo.createRecord(
              productId:
                  row.mode == _MatchMode.existing ? row.productId : null,
              productName: row.mode == _MatchMode.existing
                  ? null
                  : row.parsed.name,
              price: row.parsed.price!,
              quantity: row.parsed.quantity,
              unit: row.parsed.unit,
              merchantId: merchantId,
              ingredientId:
                  row.mode == _MatchMode.newAttach ? row.ingredientId : null,
              recordType: 'price', // 必须显式传（默认 purchase）
              recordedAt: _recordedAt,
            );
            // 成功后给商品加别名（existing→已有 id / new_attach→新建 id）
            // new_same 不加别名（用户本就想用此名）。
            final int? aliasProductId = row.mode == _MatchMode.existing
                ? row.productId
                : row.mode == _MatchMode.newAttach
                    ? (record.productId > 0 ? record.productId : null)
                    : null;
            if (aliasProductId != null) {
              try {
                await _priceRepo.addImportAlias(aliasProductId, row.parsed.name);
              } on Exception {
                // 别名失败不影响导入成功
              }
            }
            return (ok: true, row: row, record: record);
          } on Exception {
            return (ok: false, row: row, record: null);
          }
        }),
      );

      // 批内累加不 setState，批末一次性更新进度（减少 N 次重建）
      for (final r in results) {
        if (r.ok) {
          success++;
          if (r.row.mode == _MatchMode.existing && r.row.productId != null) {
            savedIds.add(r.row.productId!);
          } else {
            final rec = r.record;
            if (rec != null && rec.productId > 0) {
              savedIds.add(rec.productId);
            }
          }
        } else {
          failures.add(r.row.parsed.name);
        }
      }
      _progressCurrent += results.length;
      if (mounted) setState(() {});
    }

    if (!mounted) return;
    setState(() {
      _importing = false;
      _result = _ImportResult(
        success: success,
        fail: failures.length,
        failures: failures,
      );
    });

    // 全部成功才关闭页面并回传 savedIds（对齐网页端行为）
    if (failures.isEmpty && mounted) {
      Navigator.of(context).pop(savedIds);
    }
  }

  // -------- 渲染辅助 --------

  String _fmtQty(double q) {
    if (q == q.truncateToDouble()) return q.toInt().toString();
    return q.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImportable = _importable.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('粘贴导入价格')),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 与新增价格记录页保持一致的记录时间选择器。
              ListTile(
                key: const Key('paste-recorded-at-field'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: const Text('记录时间'),
                trailing: Text(
                  '${_recordedAt.year}-${_recordedAt.month.toString().padLeft(2, '0')}-${_recordedAt.day.toString().padLeft(2, '0')} '
                  '${_recordedAt.hour.toString().padLeft(2, '0')}:${_recordedAt.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodyMedium,
                ),
                onTap: _pickRecordedAt,
              ),
              const SizedBox(height: 8),
              // 复制模板
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: widget.historyProductNames.isEmpty
                      ? null
                      : _copyTemplate,
                  icon: const Icon(Icons.content_copy),
                  label: const Text('复制模板'),
                ),
              ),
              // 粘贴文本输入
              TextField(
                key: const Key('paste-raw-text-field'),
                controller: _rawTextController,
                maxLines: 4,
                minLines: 4,
                decoration: const InputDecoration(
                  hintText: '芹菜 1.88\n芽菇 4/袋\n嫩豆腐 5.18/kg\n土豆粉 2.5/200g',
                  border: OutlineInputBorder(),
                  labelText: '粘贴价格文本\n（每行一条，格式：名称 价格[/单位]）',
                ),
              ),
              const SizedBox(height: 8),
              // 解析按钮 + 概要
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _parsing ? null : _parse,
                    icon: _parsing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('解析并匹配'),
                  ),
                  const SizedBox(width: 12),
                  if (_rows.isNotEmpty)
                    Expanded(
                      child: Text(
                        '已匹配 $_matchedCount · 待处理 $_unmatchedCount · 无法识别 $_invalidCount',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // 行列表
              if (_rows.isNotEmpty) ...[
                for (var i = 0; i < _rows.length; i++)
                  _buildRow(_rows[i], theme),
                const SizedBox(height: 12),
              ],
              // 导入进度条
              if (_importing && _progressTotal > 0) ...[
                LinearProgressIndicator(
                  value: _progressCurrent / _progressTotal,
                ),
                const SizedBox(height: 4),
                Text(
                  '正在导入 $_progressCurrent/$_progressTotal…',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              // 导入按钮
              if (hasImportable)
                FilledButton.icon(
                  key: const Key('paste-import-button'),
                  onPressed: _importing ? null : _doImport,
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: Text('全部导入（${_importable.length} 条）'),
                ),
              // 结果
              if (_result != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _result!.fail == 0
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '导入完成：成功 ${_result!.success} 条，失败 ${_result!.fail} 条',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (_result!.failures.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '失败：${_result!.failures.join('、')}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(_ImportRow row, ThemeData theme) {
    if (row.editing) return _buildExpanded(row, theme);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              row.status == _RowStatus.matched
                  ? Icons.check_circle
                  : row.status == _RowStatus.unmatched
                      ? Icons.help_outline
                      : Icons.error_outline,
              size: 20,
              color: row.status == _RowStatus.matched
                  ? theme.colorScheme.primary
                  : row.status == _RowStatus.unmatched
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: row.status == _RowStatus.invalid
                  ? Text(
                      row.parsed.name.isEmpty
                          ? '（${row.parsed.error}）'
                          : '${row.parsed.name}（${row.parsed.error}）',
                      style: theme.textTheme.bodyMedium,
                    )
                  : InkWell(
                      onTap: row.status == _RowStatus.unmatched
                          ? () => _openEditor(row)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                row.parsed.name,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            if (row.status == _RowStatus.unmatched) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.expand_more,
                                size: 16,
                                color: theme.colorScheme.outline,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
            if (row.status != _RowStatus.invalid) ...[
              Text(
                row.parsed.price?.toStringAsFixed(2) ?? '—',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              Text(
                '${_fmtQty(row.parsed.quantity)} ${row.parsed.unit}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 展开态：内联手势面板，关联已有商品 / 创建同名商品。
  Widget _buildExpanded(_ImportRow row, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  row.parsed.name,
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${row.parsed.price?.toStringAsFixed(2) ?? '—'} · '
                  '${_fmtQty(row.parsed.quantity)} ${row.parsed.unit}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 关联已有商品（使用 row.searchController 持久实例）
            TextField(
              key: const Key('paste-existing-search'),
              decoration: const InputDecoration(
                labelText: '关联已有商品',
                hintText: '搜索商品…',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => _onExistingSearch(row, v),
              controller: row.searchController,
            ),
            if (row.suggestions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 4),
                  children: [
                   for (final s in row.suggestions)
                     ListTile(
                       key: Key('paste-suggestion-${s['id']}'),
                       dense: true,
                       title: Text('${s['name']}'),
                       onTap: () => _chooseExisting(row, s),
                     ),
                  ],
                ),
              ),
           const SizedBox(height: 8),
           // 搜索原料：新建商品并关联到该原料（new_attach 模式）
           TextField(
             key: const Key('paste-ingredient-search'),
             decoration: const InputDecoration(
               labelText: '关联到原料',
               hintText: '搜索原料…',
               border: OutlineInputBorder(),
               isDense: true,
               prefixIcon: Icon(Icons.eco_outlined),
             ),
             onChanged: (v) => _onIngredientSearch(row, v),
             controller: row.ingredientSearchController,
           ),
           if (row.ingredientSuggestions.isNotEmpty)
             ConstrainedBox(
               constraints: const BoxConstraints(maxHeight: 200),
               child: ListView(
                 shrinkWrap: true,
                 padding: const EdgeInsets.only(top: 4),
                 children: [
                   for (final s in row.ingredientSuggestions)
                    ListTile(
                      key: Key('paste-ingredient-${s['id']}'),
                      dense: true,
                      title: Text('${s['name']}'),
                      onTap: () => _chooseAttach(row, s),
                    ),
                 ],
               ),
             ),
           const SizedBox(height: 8),
           // 创建同名商品
           FilledButton.tonalIcon(
             key: const Key('paste-new-same-button'),
             onPressed: () => _chooseNewSame(row),
             icon: const Icon(Icons.add),
             label: const Text('创建同名原料 + 商品'),
           ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _cancelEdit(row),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
