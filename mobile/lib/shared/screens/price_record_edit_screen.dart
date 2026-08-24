import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/merchants/models/merchant.dart';
import '../utils/currency_fmt.dart';

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
  'g',
  'kg',
  '斤',
  '个',
  'ml',
  'L',
  '盒',
  '袋',
  '瓶',
  '罐',
  '包',
];

class PriceRecordFormArguments {
  final List<Merchant> merchants;
  final List<ProductOption> products;
  final int? fixedProductId;
  final String? fixedProductName;
  final double? initialPrice;
  final double? initialQuantity;
  final String? initialUnit;
  final int? initialMerchantId;

  const PriceRecordFormArguments({
    required this.merchants,
    this.products = const [],
    this.fixedProductId,
    this.fixedProductName,
    this.initialPrice,
    this.initialQuantity,
    this.initialUnit,
    this.initialMerchantId,
  });
}

class PriceRecordEditScreen extends StatefulWidget {
  final PriceRecordFormArguments arguments;

  const PriceRecordEditScreen({super.key, required this.arguments});

  @override
  State<PriceRecordEditScreen> createState() => _PriceRecordEditScreenState();
}

class _PriceRecordEditScreenState extends State<PriceRecordEditScreen> {
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _merchantController;
  late String _unit;
  int? _merchantId;
  int? _productId;

  @override
  void initState() {
    super.initState();
    final args = widget.arguments;
    _priceController = TextEditingController(
      text: args.initialPrice == null
          ? ''
          : args.initialPrice!.toStringAsFixed(2),
    );
    _quantityController = TextEditingController(
      text: args.initialQuantity == null
          ? '1'
          : _formatQuantity(args.initialQuantity!),
    );
    _unit = args.initialUnit ?? '斤';
    final merchantName = _findMerchantName(args.initialMerchantId);
    _merchantId = merchantName.isEmpty ? null : args.initialMerchantId;
    _merchantController = TextEditingController(text: merchantName);
    _productId = args.fixedProductId ?? args.products.firstOrNull?.id;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  String _findMerchantName(int? id) {
    if (id == null) return '';
    for (final merchant in widget.arguments.merchants) {
      if (merchant.id == id) return merchant.name;
    }
    return '';
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.truncateToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(2);
  }

  void _submit() {
    final price = double.tryParse(_priceController.text.trim());
    final quantity = double.tryParse(_quantityController.text.trim());
    if (price == null || price <= 0) {
      _toast('请输入有效的价格');
      return;
    }
    if (quantity == null || quantity <= 0) {
      _toast('请输入有效的数量');
      return;
    }
    Navigator.of(context).pop(
      PriceRecordFormResult(
        price: price,
        quantity: quantity,
        unit: _unit,
        merchantId: _merchantId,
        productId: _productId,
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = widget.arguments;
    final isEdit = args.initialPrice != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '编辑价格记录' : '记录价格')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (args.fixedProductName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    args.fixedProductName!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              if (args.products.length > 1 && args.fixedProductId == null) ...[
                _label(theme, '商品'),
                DropdownButtonFormField<int>(
                  initialValue: _productId,
                  isExpanded: true,
                  decoration: _decoration(),
                  items: [
                    for (final product in args.products)
                      DropdownMenuItem(
                        value: product.id,
                        child: Text(product.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _productId = value),
                ),
                const SizedBox(height: 12),
              ],
              Consumer(
                builder: (context, ref, _) => _label(
                  theme,
                  '价格（${currencySymbol(ref.read(authProvider).user?.defaultCurrency ?? 'CNY')}）',
                ),
              ),
              TextField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
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
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
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
                            for (final unit in priceRecordUnits)
                              DropdownMenuItem(value: unit, child: Text(unit)),
                          ],
                          onChanged: (value) =>
                              setState(() => _unit = value ?? '斤'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _label(theme, '商家'),
              Autocomplete<Merchant>(
                optionsBuilder: (value) {
                  final text = value.text.toLowerCase();
                  if (text.isEmpty) return args.merchants;
                  return args.merchants
                      .where((merchant) =>
                          merchant.name.toLowerCase().contains(text))
                      .toList();
                },
                displayStringForOption: (merchant) => merchant.name,
                onSelected: (merchant) {
                  _merchantController.text = merchant.name;
                  setState(() => _merchantId = merchant.id);
                },
                fieldViewBuilder: (
                  context,
                  controller,
                  focusNode,
                  onFieldSubmitted,
                ) {
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
                      if (_merchantId != null) {
                        setState(() => _merchantId = null);
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: Text(isEdit ? '保存' : '添加'),
              ),
            ],
          ),
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
