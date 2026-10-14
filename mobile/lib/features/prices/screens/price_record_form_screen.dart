import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/screens/price_record_edit_screen.dart'
    show priceRecordUnits;
import '../../merchants/models/merchant.dart';
import '../../merchants/providers/merchant_provider.dart';
import '../../products/models/product.dart';
import '../../products/repositories/product_repository.dart';
import '../../products/screens/product_form_screen.dart'
    show ProductFormPrefill, ProductFormResult;
import '../../../shared/widgets/barcode_scanner_sheet.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/save_action_button.dart';
import '../../../shared/utils/entity_unit_names.dart';
import '../../profile/providers/save_button_position_provider.dart';
import '../repositories/price_repository.dart';
import '../providers/price_record_session_memory.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../../core/i18n/app_formatters.dart';
import '../../../l10n/app_localizations.dart';

class PriceRecordFormPrefill {
  final Product? product;
  final int? ingredientId;
  final bool lockProduct;

  const PriceRecordFormPrefill({
    this.product,
    this.ingredientId,
    this.lockProduct = false,
  });
}

/// 新增价格记录全屏页（对齐 web 端添加价格记录对话框）。
/// 保存成功后 pop(true)；校验失败提示不关闭。
class PriceRecordFormScreen extends ConsumerStatefulWidget {
  /// 测试注入，缺省用真实 repository。
  final PriceRepository? priceRepository;
  final ProductRepository? productRepository;
  final PriceRecordFormPrefill? prefill;
  final Future<String?> Function(BuildContext context)? scanner;

  /// 测试注入：商品自定义单位名加载器（缺省走 /entities/... 接口）。
  final Future<List<String>> Function(int productId, int? ingredientId)?
      unitNamesLoader;

  /// 测试注入：全局单位基准加载器（缺省走 GET /units/，失败回退常量）。
  final Future<List<String>> Function()? globalUnitNamesLoader;

  /// 测试注入：实体单位请求缝，供缺省 [loadEntityUnitNames] 使用（不走真实网络）。
  final EntityUnitsRequest? entityUnitsRequest;

  const PriceRecordFormScreen({
    super.key,
    this.priceRepository,
    this.productRepository,
    this.prefill,
    this.scanner,
    this.unitNamesLoader,
    this.globalUnitNamesLoader,
    this.entityUnitsRequest,
  });

  @override
  ConsumerState<PriceRecordFormScreen> createState() =>
      _PriceRecordFormScreenState();
}

class _PriceRecordFormScreenState extends ConsumerState<PriceRecordFormScreen> {
  late final PriceRepository _priceRepo;
  late final ProductRepository _productRepo;
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  final _merchantController = TextEditingController();
  String _currency = 'CNY';
  String _currencySymbol = '¥';
  List<dynamic> _currencies = const [];
  String _unit = '斤';
  /// 当前商品（及其关联原料）的自定义单位名，价格单位下拉里排在最前
  List<String> _customUnits = const [];
  /// 全局单位基准（GET /units/）；为空时回退 [priceRecordUnits] 常量
  List<String> _globalUnits = const [];
  bool _globalUnitsLoading = false;
  /// 已按其加载过自定义单位的商品 id，避免重复请求
  int? _unitsLoadedForProductId;
  int _unitsSeq = 0;
  int? _merchantId;
  Product? _selectedProduct;
  List<Product> _searchResults = const [];
  bool _searching = false;
  Timer? _searchDebounce;
  int _searchSeq = 0;
  bool _isPurchase = true;
  bool _saving = false;
  bool _currencyTouched = false;
  DateTime _recordedAt = DateTime.now();
  bool _barcodeLoading = false;
  late final bool _lockProduct;
  late final int? _ingredientId;

  @override
  void initState() {
    super.initState();
    _lockProduct = widget.prefill?.lockProduct ?? false;
    _ingredientId = widget.prefill?.ingredientId;
    _selectedProduct = widget.prefill?.product;
    _nameController.text = widget.prefill?.product?.name ?? '';
    _priceRepo = widget.priceRepository ?? PriceRepository();
    _productRepo = widget.productRepository ?? ProductRepository();
    // 会话记忆：商家 + 计入支出（对齐 web 端 sessionStorage，同一会话内保持）
    final memory = ref.read(priceRecordSessionMemoryProvider);
    _merchantId = memory.merchantId;
    _isPurchase = memory.isPurchase;
    // 商家列表可能已加载，也可能稍后才加载；两种情况都回填商家名到输入框
    if (_merchantId != null) {
      final m = ref
          .read(merchantListProvider)
          .items
          .where((m) => m.id == _merchantId)
          .firstOrNull;
      if (m != null) {
        _merchantController.text = m.name;
        _applyMerchantCurrency(m);
      }
    }
    ref.listenManual<MerchantListState>(merchantListProvider, (previous, next) {
      if (!mounted || _merchantId == null) return;
      final m = next.items.where((m) => m.id == _merchantId).firstOrNull;
      if (m == null) return;
      if (_merchantController.text.isEmpty) _merchantController.text = m.name;
      if (_currencyTouched) return;
      setState(() => _applyMerchantCurrency(m));
    });
    // 构建阶段内写 provider 会抛异常，微任务延后（对齐 price_list_screen 惯例）
    Future.microtask(() => ref.read(merchantListProvider.notifier).load());
    _loadCurrencies();
    _ensureGlobalUnits();
    final prefillProduct = widget.prefill?.product;
    if (prefillProduct != null) {
      _loadCustomUnits(prefillProduct.id, prefillProduct.ingredientId);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  void _applyMerchantCurrency(Merchant m) {
    final code = m.defaultCurrency ?? m.effectiveCurrency;
    if (code == null || code.isEmpty) return;
    _currency = code;
    _currencySymbol = currencySymbol(code);
  }

  Future<void> _loadCurrencies() async {
    try {
      final resp = await _priceRepo.client.dio.get('/currencies');
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

  void _searchProducts(String query) {
    if (_lockProduct || !mounted) return;
    final q = query.trim();
    _searchDebounce?.cancel();
    final seq = ++_searchSeq;

    if (q.isEmpty) {
      setState(() {
        _searchResults = const [];
        _selectedProduct = null;
        _customUnits = const [];
        _unitsLoadedForProductId = null;
        _searching = false;
      });
      return;
    }

    // 商品名被改动则撤销原选择，避免保存时携带旧的 productId。
    if (_selectedProduct != null && _selectedProduct!.name != q) {
      _selectedProduct = null;
      _unitsSeq++;
      _customUnits = const [];
      _unitsLoadedForProductId = null;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final page = await _productRepo.search(
          search: q,
          ingredientId: _ingredientId,
          limit: 10,
        );
        if (!mounted || seq != _searchSeq) return;
        setState(() {
          _searchResults = page.items;
          _searching = false;
        });
      } on Exception {
        if (!mounted || seq != _searchSeq) return;
        setState(() {
          _searchResults = const [];
          _searching = false;
        });
      }
    });
  }

  void _selectProduct(Product p) {
    _nameController.text = p.name;
    setState(() {
      _selectedProduct = p;
      _searchResults = const [];
    });
    _loadCustomUnits(p.id, p.ingredientId);
    _ensureGlobalUnits();
  }

  /// 价格单位下拉的「基准列表」：全局单位（GET /units/，与 web 同源），
  /// 拉不到时回退 [priceRecordUnits] 常量。
  ///
  /// 之前只用常量，导致单位管理里存在、但不在常量里的全局单位
  /// （把/条/块/mL/桶…）在移动端下拉里根本选不到。
  List<String> get _baseUnits =>
      _globalUnits.isNotEmpty ? _globalUnits : priceRecordUnits;

  Future<void> _ensureGlobalUnits() async {
    if (_globalUnits.isNotEmpty || _globalUnitsLoading) return;
    _globalUnitsLoading = true;
    try {
      final names = await (widget.globalUnitNamesLoader?.call() ??
          loadGlobalUnitNames(request: widget.entityUnitsRequest));
      if (names.isNotEmpty && mounted) {
        setState(() => _globalUnits = names);
      }
    } catch (error, stackTrace) {
      // 全局单位拉取失败只影响「多出来的可选项」，回退常量即可，不打扰用户。
      log(
        'PriceRecordFormScreen: 全局单位加载失败，回退常量列表',
        name: 'price_record_form',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _globalUnitsLoading = false;
    }
  }

  /// 选中商品后拉取「商品 + 关联原料」的自定义单位，并到价格单位下拉最前。
  /// 每次都以全局单位为基础重建，避免切换商品后残留上一个商品的单位。
  Future<void> _loadCustomUnits(int productId, int? ingredientId) async {
    if (_unitsLoadedForProductId == productId && _customUnits.isNotEmpty) {
      return;
    }
    final seq = ++_unitsSeq;
    final names = await (widget.unitNamesLoader?.call(productId, ingredientId) ??
        loadEntityUnitNames(
          entityType: 'product',
          entityId: productId,
          ingredientId: ingredientId,
          request: widget.entityUnitsRequest,
        ));
    if (!mounted || seq != _unitsSeq) return;
    setState(() {
      _customUnits = names;
      _unitsLoadedForProductId = productId;
    });
  }

  Future<void> _scanBarcode() async {
    final scanner = widget.scanner ?? showBarcodeScannerSheet;
    final code = await scanner(context);
    if (code == null || code.trim().isEmpty || !mounted) return;
    setState(() => _barcodeLoading = true);
    try {
      final result = await _productRepo.lookupBarcode(code);
      if (!mounted) return;
      if (!result.hasEnabledProviders) {
        return;
      }
      if (result.found && result.product.id != null) {
        _selectProduct(
          Product(
            id: result.product.id!,
            name: result.product.name ?? code,
            barcode: result.product.barcode ?? code,
            brand: result.product.brand,
          ),
        );
        return;
      }

      // 查询已完成，先收起加载覆盖层，再展示后续对话框/跳转。
      if (mounted) setState(() => _barcodeLoading = false);

      final create = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(dialogContext);
          return AlertDialog(
            title: Text(l10n.priceBarcodeNotFoundTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l10n.productBarcode}: $code'),
                if (result.product.name?.isNotEmpty == true)
                  Text('${l10n.priceNameLabel}: ${result.product.name}'),
                if (result.product.brand?.isNotEmpty == true)
                  Text('${l10n.productBrand}: ${result.product.brand}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.productAddTitle),
              ),
            ],
          );
        },
      );
      if (create != true || !mounted) return;

      final saved = await context.push<ProductFormResult>(
        '/products/new',
        extra: ProductFormPrefill(
          barcode: code,
          name: result.product.name ?? '',
          brand: result.product.brand ?? '',
        ),
      );
      if (saved?.product != null && mounted) {
        _selectProduct(saved!.product!);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context).priceBarcodeLookupFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _barcodeLoading = false);
    }
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final price = double.tryParse(_priceController.text.trim());
    final quantity = double.tryParse(_quantityController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.priceValidRequired)),
      );
      return;
    }
    if (quantity == null || quantity <= 0) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.priceQuantityRequired)),
      );
      return;
    }
    final name = _nameController.text.trim();
    if (_selectedProduct == null && name.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.productNameRequired)),
      );
      return;
    }
    try {
      await _priceRepo.createRecord(
        productId: _selectedProduct?.id,
        productName: _selectedProduct == null ? name : null,
        price: price,
        quantity: quantity,
        unit: _unit,
        merchantId: _merchantId,
        recordType: _isPurchase ? 'purchase' : 'price',
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        recordedAt: _recordedAt,
        currency: _currency,
      );
      // 记住本次新增的商家与计入支出选择（仅新增时记忆，对齐 web 端）
      ref
          .read(priceRecordSessionMemoryProvider.notifier)
          .save(merchantId: _merchantId, isPurchase: _isPurchase);
      if (mounted) Navigator.of(context).pop(true);
    } on Exception {
      // 失败可重试，恢复按钮
      if (mounted) setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonSaveFailedRetry)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final merchants = ref.watch(merchantListProvider).items;
    final savePosition = ref.watch(saveButtonPositionProvider);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(l10n.priceAddRecordTitle),
            actions: [
              ...saveAppBarActions(
                position: savePosition,
                onSave: _saving ? null : _save,
                label: l10n.commonSave,
              ),
            ],
          ),
          bottomNavigationBar: saveBottomBar(
            context: context,
            position: savePosition,
            onSave: _saving ? null : _save,
            label: l10n.commonSave,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 商家（置于商品前）
              Autocomplete<Merchant>(
                optionsBuilder: (textEditingValue) {
                  final text = textEditingValue.text.toLowerCase();
                  if (text.isEmpty) return merchants;
                  return merchants
                      .where((m) => m.name.toLowerCase().contains(text))
                      .toList();
                },
                displayStringForOption: (m) => m.name,
                onSelected: (m) {
                  _merchantController.text = m.name;
                  setState(() {
                    _merchantId = m.id;
                    _currencyTouched = false;
                    _applyMerchantCurrency(m);
                  });
                },
                fieldViewBuilder:
                    (ctx, controller, focusNode, onFieldSubmitted) {
                  // 同步外部 _merchantController 与 Autocomplete 内部 controller，
                  // 避免预填值被内部 controller 覆盖（对齐 quick_fill_screen 做法）。
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_merchantController.text != controller.text) {
                      controller.text = _merchantController.text;
                    }
                  });
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: l10n.priceMerchantLabel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => onFieldSubmitted(),
                    onChanged: (value) {
                      // 文本被改动后不再信任 _merchantId；要保留必须重新点选
                      // （onSelected 程序化赋值不会走 onChanged，选中流程不受影响）
                      if (_merchantId != null) {
                        setState(() => _merchantId = null);
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.priceProductNameLabel,
                  hintText: l10n.priceProductNameHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.priceScanProductTooltip,
                        icon: const Icon(Icons.barcode_reader),
                        onPressed: (_barcodeLoading || _lockProduct)
                            ? null
                            : _scanBarcode,
                      ),
                      if (_searching)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                onChanged: _searchProducts,
                readOnly: _lockProduct,
              ),
              if (_searchResults.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      for (final p in _searchResults)
                        ListTile(
                          dense: true,
                          title: Text(p.name),
                          onTap: () => _selectProduct(p),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.priceLabel,
                        prefixText: _currencySymbol,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 132,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_currency),
                      initialValue: _currency,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.priceCurrencyLabel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _currencies.isEmpty
                          ? [
                              DropdownMenuItem(
                                value: _currency,
                                child: Text(_currency),
                              ),
                            ]
                          : [
                              for (final c in _currencies)
                                DropdownMenuItem(
                                  value: c['code'] as String,
                                  child: Text(
                                    '${c['name']} ${c['code']}',
                                  ),
                                ),
                            ],
                      // 收起时只显示三字母代码，展开列表显示全称+代码
                      selectedItemBuilder: (context) => _currencies.isEmpty
                          ? [
                              DropdownMenuItem(
                                value: _currency,
                                child: Text(_currency),
                              ),
                            ]
                          : [
                              for (final c in _currencies)
                                DropdownMenuItem(
                                  value: c['code'] as String,
                                  child: Text(c['code'] as String),
                                ),
                            ],
                      onChanged: (code) {
                        if (code == null) return;
                        setState(() {
                          _currencyTouched = true;
                          _currency = code;
                          _currencySymbol = currencySymbol(code);
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.priceQuantityLabel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.priceUnitLabel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        for (final u in mergePriceUnitOptions(
                          _customUnits,
                          _baseUnits,
                          current: _unit,
                        ))
                          DropdownMenuItem(value: u, child: Text(u)),
                      ],
                      onChanged: (v) => setState(() => _unit = v ?? '斤'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.priceIncludeInSpending),
                subtitle: Text(l10n.priceIncludeInSpendingDescription),
                value: _isPurchase,
                onChanged: (v) => setState(() => _isPurchase = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(l10n.priceRecordedAt),
                trailing: Text(
                  formatDateTime(_recordedAt),
                  style: theme.textTheme.bodyMedium,
                ),
                onTap: _pickRecordedAt,
              ),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.priceNotesLabel,
                  hintText: l10n.priceNotesHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_barcodeLoading)
          LoadingOverlay(message: l10n.priceBarcodeSearching),
      ],
    );
  }
}
