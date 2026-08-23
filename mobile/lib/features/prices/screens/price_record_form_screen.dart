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
import '../repositories/price_repository.dart';

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

  const PriceRecordFormScreen({
    super.key,
    this.priceRepository,
    this.productRepository,
    this.prefill,
    this.scanner,
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
  String _unit = '斤';
  int? _merchantId;
  Product? _selectedProduct;
  List<Product> _searchResults = const [];
  bool _searching = false;
  int _searchSeq = 0;
  bool _isPurchase = true;
  bool _saving = false;
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
    // 构建阶段内写 provider 会抛异常，微任务延后（对齐 price_list_screen 惯例）
    Future.microtask(() => ref.read(merchantListProvider.notifier).load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String query) async {
    if (_lockProduct) return;
    final q = query.trim();
    if (q.isEmpty) {
      _searchSeq++; // 使在途搜索失效，避免清空后被旧结果覆盖
      setState(() {
        _searchResults = const [];
        _selectedProduct = null;
        _searching = false;
      });
      return;
    }
    // 商品名被改动则撤销原选择，避免保存时携带旧的 productId
    if (_selectedProduct != null && _selectedProduct!.name != q) {
      _selectedProduct = null;
    }
    final seq = ++_searchSeq;
    setState(() => _searching = true);
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
  }

  void _selectProduct(Product p) {
    _nameController.text = p.name;
    setState(() {
      _selectedProduct = p;
      _searchResults = const [];
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
        builder: (dialogContext) => AlertDialog(
          title: const Text('未找到本地商品'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('条码：$code'),
              if (result.product.name?.isNotEmpty == true)
                Text('名称：${result.product.name}'),
              if (result.product.brand?.isNotEmpty == true)
                Text('品牌：${result.product.brand}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('新增商品'),
            ),
          ],
        ),
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
          const SnackBar(content: Text('条码查询失败，请重试')),
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
    final price = double.tryParse(_priceController.text.trim());
    final quantity = double.tryParse(_quantityController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的价格')),
      );
      return;
    }
    if (quantity == null || quantity <= 0) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的数量')),
      );
      return;
    }
    final name = _nameController.text.trim();
    if (_selectedProduct == null && name.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入商品名称')),
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
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Exception {
      // 失败可重试，恢复按钮
      if (mounted) setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final merchants = ref.watch(merchantListProvider).items;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('新增价格记录')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '商品名称',
                  hintText: '搜索或输入新商品名',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '扫码识别商品',
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
              TextField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '价格（¥）',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
                        labelText: '数量',
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
                        labelText: '单位',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        for (final u in priceRecordUnits)
                          DropdownMenuItem(value: u, child: Text(u)),
                      ],
                      onChanged: (v) => setState(() => _unit = v ?? '斤'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                  setState(() => _merchantId = m.id);
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
                      labelText: '商家',
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
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('计入支出'),
                subtitle: const Text('表示此价格记录来自实际购买，将用于支出计算'),
                value: _isPurchase,
                onChanged: (v) => setState(() => _isPurchase = v),
              ),
              ListTile(
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
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '备注',
                  hintText: '备注（可选）',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
        if (_barcodeLoading) const LoadingOverlay(message: '正在查询商品信息…'),
      ],
    );
  }
}
