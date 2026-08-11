import 'package:flutter/material.dart';
import '../../features/merchants/models/merchant.dart';

class PriceRecordFormResult {
  final double price;
  final double quantity;
  final String unit;
  final int? merchantId;
  final int? productId;

  const PriceRecordFormResult({
    required this.price,
    required this.quantity,
    required this.unit,
    this.merchantId,
    this.productId,
  });
}

class ProductOption {
  final int id;
  final String name;
  const ProductOption(this.id, this.name);
}

const priceRecordUnits = [
  'g', 'kg', '斤', '个', 'ml', 'L', '盒', '袋', '瓶', '罐', '包',
];

/// 打开“记录/编辑价格”底部表单。
/// - [products] 提供时显示商品下拉（原料详情页新增记录用）；
/// - [fixedProduct] 固定商品（商品详情/快捷记价用）；
/// - [initial] 编辑模式预填值。
Future<PriceRecordFormResult?> showPriceRecordFormSheet(
  BuildContext context, {
  required List<Merchant> merchants,
  List<ProductOption> products = const [],
  int? fixedProductId,
  String? fixedProductName,
  double? initialPrice,
  double? initialQuantity,
  String? initialUnit,
  int? initialMerchantId,
}) {
  return showModalBottomSheet<PriceRecordFormResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _PriceRecordFormSheet(
      merchants: merchants,
      products: products,
      fixedProductId: fixedProductId,
      fixedProductName: fixedProductName,
      initialPrice: initialPrice,
      initialQuantity: initialQuantity,
      initialUnit: initialUnit,
      initialMerchantId: initialMerchantId,
    ),
  );
}

class _PriceRecordFormSheet extends StatefulWidget {
  final List<Merchant> merchants;
  final List<ProductOption> products;
  final int? fixedProductId;
  final String? fixedProductName;
  final double? initialPrice;
  final double? initialQuantity;
  final String? initialUnit;
  final int? initialMerchantId;

  const _PriceRecordFormSheet({
    required this.merchants,
    required this.products,
    this.fixedProductId,
    this.fixedProductName,
    this.initialPrice,
    this.initialQuantity,
    this.initialUnit,
    this.initialMerchantId,
  });

  @override
  State<_PriceRecordFormSheet> createState() => _PriceRecordFormSheetState();
}

class _PriceRecordFormSheetState extends State<_PriceRecordFormSheet> {
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _merchantController;
  late String _unit;
  int? _merchantId;
  int? _productId;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.initialPrice == null
          ? ''
          : widget.initialPrice!.toStringAsFixed(2),
    );
    _quantityController = TextEditingController(
      text: widget.initialQuantity == null
          ? '1'
          : _fmtQty(widget.initialQuantity!),
    );
    _unit = widget.initialUnit ?? '斤';
    // 预填商家名：initialMerchantId 在 widget.merchants 中找到对应商家。
    // 若 initialMerchantId 不在 merchants 列表里（找不到名字），_merchantId 置 null
    // 防止 stale id 被悄悄提交。
    final initialName = _findMerchantName(widget.initialMerchantId);
    _merchantId = initialName.isEmpty ? null : widget.initialMerchantId;
    _merchantController = TextEditingController(text: initialName);
    _productId = widget.fixedProductId ?? widget.products.firstOrNull?.id;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  /// 在 widget.merchants 中按 id 查找商家名（未找到返回空串）
  String _findMerchantName(int? id) {
    if (id == null) return '';
    for (final m in widget.merchants) {
      if (m.id == id) return m.name;
    }
    return '';
  }

  String _fmtQty(double q) {
    if (q == q.truncateToDouble()) return q.toInt().toString();
    var s = q.toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  void _submit() {
    final price = double.tryParse(_priceController.text.trim());
    final quantity = double.tryParse(_quantityController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的价格')),
      );
      return;
    }
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的数量')),
      );
      return;
    }
    Navigator.of(context).pop(PriceRecordFormResult(
      price: price,
      quantity: quantity,
      unit: _unit,
      merchantId: _merchantId,
      productId: _productId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.initialPrice != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(isEdit ? '编辑价格记录' : '记录价格',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (widget.fixedProductName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.fixedProductName!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            if (widget.products.length > 1 && widget.fixedProductId == null) ...[
              _label(theme, '商品'),
              DropdownButtonFormField<int>(
                initialValue: _productId,
                isExpanded: true,
                decoration: _decoration(),
                items: [
                  for (final p in widget.products)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _productId = v),
              ),
              const SizedBox(height: 12),
            ],
            _label(theme, '价格（¥）'),
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _decoration(prefixIcon: const Icon(Icons.payments)),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(theme, '数量'),
                      TextField(
                        controller: _quantityController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: _decoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(theme, '单位'),
                      DropdownButtonFormField<String>(
                        initialValue: _unit,
                        isExpanded: true,
                        decoration: _decoration(),
                        items: [
                          for (final u in priceRecordUnits)
                            DropdownMenuItem(value: u, child: Text(u)),
                        ],
                        onChanged: (v) => setState(() => _unit = v ?? '斤'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _label(theme, '商家'),
            Autocomplete<Merchant>(
              optionsBuilder: (textEditingValue) {
                final text = textEditingValue.text.toLowerCase();
                if (text.isEmpty) return widget.merchants;
                return widget.merchants
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
                  decoration: _decoration(),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(isEdit ? '保存' : '添加'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: theme.textTheme.labelLarge),
      );

  InputDecoration _decoration({Widget? prefixIcon}) => InputDecoration(
        prefixIcon: prefixIcon,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
