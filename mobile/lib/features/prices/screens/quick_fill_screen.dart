import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_formatters.dart';
import '../repositories/price_repository.dart';
import '../../merchants/repositories/merchant_repository.dart';
import '../../../shared/widgets/numeric_keypad.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../../shared/utils/entity_unit_names.dart';
import '../../../l10n/app_localizations.dart';

/// 快速填写每行单位菜单的兜底列表（全局单位拉取失败时使用）。
const quickFillFallbackUnits = <String>['个', '斤', '克', '千克', '升', '毫升', '包', '瓶', '袋', '箱'];

class QuickFillScreen extends ConsumerStatefulWidget {
  const QuickFillScreen({
    super.key,
    this.priceRepository,
    this.merchantRepository,
    this.unitNamesLoader,
    this.globalUnitNamesLoader,
    this.merchantsLoader,
  });

  /// 测试注入，缺省用真实 repository。
  final PriceRepository? priceRepository;
  final MerchantRepository? merchantRepository;

  /// 测试注入：某商品（含关联原料）的自定义单位名加载器。
  final Future<List<String>> Function(int productId, int? ingredientId)?
      unitNamesLoader;

  /// 测试注入：全局单位基准加载器（缺省走 GET /units/，失败回退常量列表）。
  final Future<List<String>> Function()? globalUnitNamesLoader;

  /// 测试注入：商家列表加载器（缺省走 GET /merchants）。
  final Future<List<Map<String, dynamic>>> Function()? merchantsLoader;

  @override
  ConsumerState<QuickFillScreen> createState() => _QuickFillScreenState();
}

class _QuickFillScreenState extends ConsumerState<QuickFillScreen> {
  late final PriceRepository _repo;
  late final MerchantRepository _merchantRepo;
  int? _selectedMerchantId;
  String _currency = 'CNY';
  String _currencySymbol = '¥';
  List<dynamic> _currencies = const [];

  // Pricing rows
  final List<_PriceRow> _rows = [];
  bool _loading = false;

  /// 每行商品的自定义单位缓存（key = productId）。
  /// 行数即商家历史商品数，网络请求不阻塞 UI，到达后 setState 让菜单可见。
  final Map<int, List<String>> _customUnitsByProduct = {};
  /// 已发起过自定义单位请求的商品 id（避免重复请求）。
  final Set<int> _unitsRequested = {};
  /// 全局单位基准（GET /units/）；为空时回退 [quickFillFallbackUnits]。
  List<String> _globalUnits = const [];
  bool _globalUnitsLoading = false;

  // Merchant search / selection
  List<Map<String, dynamic>> _merchants = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.priceRepository ?? PriceRepository();
    _merchantRepo = widget.merchantRepository ?? MerchantRepository();
    _loadMerchants();
    _loadCurrencies();
    _ensureGlobalUnits();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.nameController.dispose();
      r.priceController.dispose();
    }
    super.dispose();
  }

  /// 拉取全部可选商家（翻页）。
  ///
  /// 后端 `GET /merchants` 默认 `limit=10`、按 `created_at` 倒序，只请求一次时
  /// 较早创建的商家会被截断（「下拉里没有美道家万达广场店」即此因：该店在
  /// 营业商家列表里排第 12）。这里按 `total` 翻页取全，单页用后端上限 100，
  /// 最多 10 页兜底防死循环。
  Future<List<Map<String, dynamic>>> _fetchAllMerchants() async {
    const pageSize = 100;
    final out = <Map<String, dynamic>>[];
    var skip = 0;
    for (var i = 0; i < 10; i++) {
      final resp = await _repo.client.dio.get(
        '/merchants',
        queryParameters: {'skip': skip, 'limit': pageSize},
      );
      final data = resp.data;
      final raw = data is List
          ? data
          : ((data is Map ? data['items'] as List<dynamic>? : null) ??
              const <dynamic>[]);
      out.addAll(raw.cast<Map<String, dynamic>>());
      final total = data is Map ? (data['total'] as num?)?.toInt() : null;
      if (raw.isEmpty ||
          raw.length < pageSize ||
          (total != null && out.length >= total)) {
        break;
      }
      skip += pageSize;
    }
    return out;
  }

  Future<void> _loadMerchants() async {
    try {
      final custom = widget.merchantsLoader;
      final List<Map<String, dynamic>> list;
      if (custom != null) {
        list = await custom();
      } else {
        list = await _fetchAllMerchants();
      }
      if (!mounted) return;
      setState(() => _merchants = list);
    } catch (error, stackTrace) {
      log(
        'QuickFillScreen: 商家列表加载失败',
        name: 'quick_fill',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _selectMerchant(Map<String, dynamic> merchant) {
    setState(() {
      _selectedMerchantId = merchant['id'] as int?;
      final code = merchant['default_currency'] as String?;
      if (code != null && code.isNotEmpty) {
        _currency = code;
        _currencySymbol = currencySymbol(code);
      }
    });
    _loadHistoryProducts();
  }

  Future<void> _loadCurrencies() async {
    try {
      final resp = await _repo.client.dio.get('/currencies');
      final data = resp.data;
      final list = (data is List)
          ? data
          : ((data is Map) ? (data['items'] as List?) : null) ?? const [];
      if (!mounted) return;
      setState(() => _currencies = list);
    } catch (_) {
      // 币种加载失败保持默认 CNY
    }
  }

  Future<void> _loadHistoryProducts() async {
    setState(() => _loading = true);
    try {
      // 对齐 web 端：用 /merchants/{id}/product-prices（limit 200）获取全部商品，
      // 而非 /products 分页 20 条记录去重（商品多时会截断）。
      final page = await _merchantRepo.getProductPrices(
        _selectedMerchantId!,
        skip: 0,
        limit: 200,
      );
      if (!mounted) return;
      setState(() {
        _rows.clear();
        for (final p in page.items) {
          _rows.add(_PriceRow(
            name: p.productName,
            unit: '斤',
            productId: p.productId,
          ));
        }
        _loading = false;
      });
      // 行重建后预取各行商品（及其关联原料）的自定义单位；
      // 不 await —— 菜单打开时能看到就已足够，加载失败回退常量列表。
      unawaited(_preloadCustomUnits());
    } catch (error, stackTrace) {
      log(
        'QuickFillScreen: 商家历史商品加载失败',
        name: 'quick_fill',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 全局单位基准（GET /units/，与 web 同源），失败回退 [quickFillFallbackUnits]。
  Future<void> _ensureGlobalUnits() async {
    if (_globalUnits.isNotEmpty || _globalUnitsLoading) return;
    _globalUnitsLoading = true;
    try {
      final names = await (widget.globalUnitNamesLoader?.call() ??
          loadGlobalUnitNames());
      if (names.isNotEmpty && mounted) {
        setState(() => _globalUnits = names);
      }
    } catch (error, stackTrace) {
      log(
        'QuickFillScreen: 全局单位加载失败，回退常量列表',
        name: 'quick_fill',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _globalUnitsLoading = false;
    }
  }

  /// 按 productId 预取自定义单位（缓存在 [_customUnitsByProduct]）。
  ///
  /// 每个商品一次 `loadEntityUnitNames`（商品自身 + 关联原料，最多 3 个请求），
  /// 并发限制在 4 路以内，避免商家历史商品多时打出请求风暴。
  Future<void> _preloadCustomUnits() async {
    final pending = <int>[];
    for (final row in _rows) {
      final id = row.productId;
      if (id != null && !_unitsRequested.contains(id)) {
        _unitsRequested.add(id);
        pending.add(id);
      }
    }
    if (pending.isEmpty) return;

    var next = 0;
    Future<void> worker() async {
      while (next < pending.length) {
        final id = pending[next++];
        var names = const <String>[];
        try {
          names = await (widget.unitNamesLoader?.call(id, null) ??
              loadEntityUnitNames(entityType: 'product', entityId: id));
        } catch (error, stackTrace) {
          // 单个商品失败只影响它自己的菜单（回退常量列表），不打扰用户。
          log(
            'QuickFillScreen: 商品 $id 自定义单位加载失败',
            name: 'quick_fill',
            error: error,
            stackTrace: stackTrace,
          );
          names = const [];
        }
        if (!mounted) return;
        _customUnitsByProduct[id] = names;
      }
    }

    final workers = pending.length < 4 ? pending.length : 4;
    await Future.wait(List.generate(workers, (_) => worker()));
    if (!mounted) return;
    setState(() {});
  }

  /// 某行单位菜单的选项：该商品自定义单位在前 → 全局单位 → 兜底常量，
  /// 并保证当前 [row.unit] 一定在列表里。
  List<String> _unitOptionsFor(_PriceRow row) {
    final productId = row.productId;
    final custom = productId == null
        ? const <String>[]
        : (_customUnitsByProduct[productId] ?? const <String>[]);
    final base = _globalUnits.isNotEmpty ? _globalUnits : quickFillFallbackUnits;
    return mergePriceUnitOptions(custom, base, current: row.unit);
  }

  /// 记录本次导入商品顺序（POST /merchants/{id}/product-orders）。
  /// sort_order = product_ids 数组索引（即粘贴文本顺序）；
  /// 失败静默不阻断 —— 排序仅影响下次列表显示顺序（对齐 web onPasteImported 的 try/catch warn）。
  Future<void> _saveProductOrders(List<int> productIds) async {
    final merchantId = _selectedMerchantId;
    if (merchantId == null || productIds.isEmpty) return;
    final now = DateTime.now();
    final sessionDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      await _repo.client.dio.post(
        '/merchants/$merchantId/product-orders',
        data: {'product_ids': productIds, 'session_date': sessionDate},
      );
    } catch (_) {
      // 排序记录失败不阻断导入主流程
    }
  }

  void _addRow({String? name, String? unit, int? productId}) {
    setState(() {
      _rows.add(
          _PriceRow(name: name ?? '', unit: unit ?? '个', productId: productId));
    });
  }

  Future<void> _saveAll() async {
    if (_selectedMerchantId == null) return;
    int saved = 0;
    for (final row in _rows) {
      final priceStr = row.priceController.text.trim();
      if (priceStr.isEmpty) continue;
      final price = double.tryParse(priceStr);
      if (price == null || price <= 0) continue;

      final name = row.nameController.text.trim();
      // 没有 productId 且名字为空则跳过
      if (row.productId == null && name.isEmpty) continue;

      try {
        await _repo.createRecord(
          productId: row.productId,
          productName: row.productId == null ? name : null,
          price: price,
          quantity: 1,
          unit: row.unit,
          merchantId: _selectedMerchantId,
          recordType: 'price',
          currency: _currency,
        );
        saved++;
      } catch (_) {}
    }

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.quickFillSavedCount(formatNumber(saved))),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.quickFillTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: l10n.pricePasteImportTooltip,
            key: const Key('quick-fill-paste-button'),
            // 历史商品加载中也必须禁用：模板依赖加载完成的商品名列表。
            onPressed: _selectedMerchantId == null || _loading
                ? null
                : () async {
                    final savedIds = await context.push<List<int>>(
                      '/prices/paste-import',
                      extra: {
                        'merchantId': _selectedMerchantId,
                        'historyProductNames': _rows
                            .map((r) => r.nameController.text)
                            .where((n) => n.trim().isNotEmpty)
                            .toList(),
                      },
                    );
                    if (savedIds != null && savedIds.isNotEmpty && mounted) {
                      // 先按导入顺序记录排序，再刷新历史列表（对齐 web onPasteImported）
                      await _saveProductOrders(savedIds);
                      _loadHistoryProducts();
                    }
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // Step 1: Merchant selection
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.quickFillSelectMerchant,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 8),
                Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.toLowerCase();
                    if (query.isEmpty) return _merchants;
                    return _merchants.where((m) {
                      final name = (m['name'] as String? ?? '').toLowerCase();
                      return name.contains(query);
                    }).toList();
                  },
                  displayStringForOption: (m) => m['name'] as String? ?? '',
                  onSelected: _selectMerchant,
                  fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: l10n.quickFillMerchantSearchHint,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onSubmitted: (_) => onSubmitted(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(l10n.priceCurrencyLabel,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      onSelected: (code) {
                        setState(() {
                          _currency = code;
                          _currencySymbol = currencySymbol(code);
                        });
                      },
                      itemBuilder: (context) {
                        if (_currencies.isEmpty) {
                          return [
                            PopupMenuItem(
                                value: _currency, child: Text(_currency)),
                          ];
                        }
                        return [
                          for (final c in _currencies)
                            PopupMenuItem(
                              value: c['code'] as String,
                              child: Text(
                                '${c['name']} ${c['code']}',
                              ),
                            ),
                        ];
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_currency),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_selectedMerchantId != null)
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n.quickFillNoHistoryProducts),
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                onPressed: () => _addRow(),
                                child: Text(l10n.productAddTitle),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Price rows header
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Text(l10n.quickFillProductHeader,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text(l10n.quickFillUnitPriceHeader,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 80),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            // Scrollable rows
                            Expanded(
                              child: ListView.builder(
                                itemCount:
                                    _rows.length + 1, // +1 for add button
                                itemBuilder: (ctx, i) {
                                  if (i == _rows.length) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: OutlinedButton.icon(
                                        onPressed: () => _addRow(),
                                        icon: const Icon(Icons.add),
                                        label: Text(l10n.productAddTitle),
                                      ),
                                    );
                                  }
                                  return _PriceRowWidget(
                                    row: _rows[i],
                                    currencySymbol: _currencySymbol,
                                    unitOptions: _unitOptionsFor(_rows[i]),
                                    onUnitChanged: (u) => setState(
                                        () => _rows[i].unit = u),
                                    onShowKeypad: () => _showKeypad(_rows[i]),
                                  );
                                },
                              ),
                            ),
                            // Submit button
                            SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: FilledButton(
                                  onPressed: _saveAll,
                                  child: Text(l10n.quickFillSaveAll),
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
        ],
      ),
    );
  }

  void _showKeypad(_PriceRow row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _PriceInputSheet(row: row, currencySymbol: _currencySymbol),
    );
  }
}

class _PriceRow {
  final TextEditingController nameController;
  final TextEditingController priceController;
  String unit;
  int? productId;

  _PriceRow({String name = '', this.unit = '个', this.productId})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController();
}

class _PriceRowWidget extends StatelessWidget {
  final _PriceRow row;
  final String currencySymbol;
  final List<String> unitOptions;
  final ValueChanged<String> onUnitChanged;
  final VoidCallback onShowKeypad;

  const _PriceRowWidget({
    required this.row,
    required this.currencySymbol,
    required this.unitOptions,
    required this.onUnitChanged,
    required this.onShowKeypad,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: row.productId != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          row.nameController.text,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : TextField(
                        controller: row.nameController,
                        decoration: InputDecoration(
                          labelText: l10n.priceProductNameLabel,
                          hintText: l10n.quickFillNewProduct,
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: GestureDetector(
                  onTap: onShowKeypad,
                  child: AbsorbPointer(
                    child: TextField(
                      controller: row.priceController,
                      decoration: InputDecoration(
                        labelText: l10n.priceLabel,
                        border: InputBorder.none,
                        isDense: true,
                        prefixText: currencySymbol,
                      ),
                      keyboardType: TextInputType.none, // block system keyboard
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                key: Key('quick-fill-unit-${row.productId ?? row.nameController.text}'),
                onSelected: onUnitChanged,
                itemBuilder: (_) => [
                  for (final u in unitOptions)
                    PopupMenuItem(value: u, child: Text(u)),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(row.unit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceInputSheet extends StatefulWidget {
  final _PriceRow row;
  final String currencySymbol;
  const _PriceInputSheet({required this.row, required this.currencySymbol});

  @override
  State<_PriceInputSheet> createState() => _PriceInputSheetState();
}

class _PriceInputSheetState extends State<_PriceInputSheet> {
  late String _display;

  @override
  void initState() {
    super.initState();
    _display = widget.row.priceController.text;
  }

  void _onKeyTap(String key) {
    setState(() {
      if (key == '⌫') {
        if (_display.isNotEmpty) {
          _display = _display.substring(0, _display.length - 1);
        }
      } else if (key == 'C') {
        _display = '';
      } else if (key == '✓') {
        widget.row.priceController.text = _display;
        Navigator.of(context).pop();
      } else if (key == '.') {
        if (!_display.contains('.')) _display += '.';
      } else {
        if (_display == '0' && key != '.') _display = '';
        _display += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            alignment: AlignmentDirectional.centerEnd,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${widget.currencySymbol}$_display',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          NumericKeypad(
            onKeyTap: _onKeyTap,
            onConfirm: () {
              widget.row.priceController.text = _display;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
