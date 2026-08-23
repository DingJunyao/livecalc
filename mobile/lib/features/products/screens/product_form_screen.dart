import 'dart:async';

import 'package:flutter/material.dart';
import '../../../shared/widgets/alias_tags_field.dart';
import '../../ingredients/models/ingredient.dart';
import '../../ingredients/repositories/ingredient_repository.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../../../shared/widgets/barcode_scanner_sheet.dart';
import '../../../shared/widgets/loading_overlay.dart';

class ProductFormPrefill {
  final String barcode;
  final String name;
  final String brand;

  const ProductFormPrefill({
    this.barcode = '',
    this.name = '',
    this.brand = '',
  });
}

class ProductFormResult {
  final bool saved;
  final bool pending;
  final String message;
  final Product? product;

  const ProductFormResult({
    required this.saved,
    required this.pending,
    required this.message,
    this.product,
  });
}

class ProductFormScreen extends StatefulWidget {
  final Ingredient? fixedIngredient;
  final Product? product;
  final ProductRepository? repository;
  final IngredientRepository? ingredientRepository;
  final bool isAdmin;
  final ProductFormPrefill? prefill;
  final Future<String?> Function(BuildContext context)? scanner;

  const ProductFormScreen({
    super.key,
    this.fixedIngredient,
    this.product,
    this.repository,
    this.ingredientRepository,
    this.isAdmin = false,
    this.prefill,
    this.scanner,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  late final ProductRepository _productRepository;
  late final IngredientRepository _ingredientRepository;
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _ingredientSearchController;
  final FocusNode _ingredientFocusNode = FocusNode();
  Timer? _debounce;
  int _ingredientSearchSeq = 0;
  List<String> _aliases = const [];
  List<String> _tags = const [];
  Ingredient? _selectedIngredient;
  bool _createNewIngredient = false;
  bool _barcodeLoading = false;
  bool _searching = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    _productRepository = widget.repository ?? ProductRepository();
    _ingredientRepository =
        widget.ingredientRepository ?? IngredientRepository();
    final initialProduct = widget.product?.mergedWithPending();
    _nameController = TextEditingController(
      text: widget.prefill?.name ?? initialProduct?.name,
    );
    _brandController = TextEditingController(
      text: widget.prefill?.brand ?? initialProduct?.brand,
    );
    _barcodeController = TextEditingController(
      text: widget.prefill?.barcode ?? initialProduct?.barcode,
    );
    _ingredientSearchController = TextEditingController();
    _selectedIngredient = widget.fixedIngredient;

    if (_isEdit) {
      _loading = true;
      Future.microtask(_loadProduct);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _ingredientSearchController.dispose();
    _ingredientFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    try {
      final product = (await _productRepository.getProduct(widget.product!.id))
          .mergedWithPending();
      if (!mounted) return;
      setState(() {
        _nameController.text = product.name;
        _brandController.text = product.brand ?? '';
        _barcodeController.text = product.barcode ?? '';
        _aliases = List.of(product.aliases);
        _tags = List.of(product.tags);
        _selectedIngredient = product.ingredientId == null
            ? null
            : Ingredient(
                id: product.ingredientId!,
                name: product.ingredientName ?? '',
              );
        _ingredientSearchController.text = _selectedIngredient?.name ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '商品加载失败，请重试';
        });
      }
    }
  }

  /// 防抖搜索关联原料（供 Autocomplete.optionsBuilder 异步调用）。
  Future<List<Ingredient>> _searchIngredients(String query) {
    final q = query.trim();
    if (q.isEmpty) {
      return Future.value(const <Ingredient>[]);
    }
    final seq = ++_ingredientSearchSeq;
    final completer = Completer<List<Ingredient>>();
    _debounce?.cancel();
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final result = await _ingredientRepository.search(
          search: q,
          limit: 20,
        );
        if (mounted && seq == _ingredientSearchSeq) {
          setState(() => _searching = false);
          completer.complete(result.items);
        } else {
          // 已有更新的查询在途，丢弃本次结果。
          completer.complete(const <Ingredient>[]);
        }
      } catch (_) {
        if (mounted && seq == _ingredientSearchSeq) {
          setState(() => _searching = false);
        }
        completer.complete(const <Ingredient>[]);
      }
    });
    return completer.future;
  }

  Future<void> _scanBarcode() async {
    final scanner = widget.scanner ?? showBarcodeScannerSheet;
    final code = await scanner(context);
    if (code == null || code.trim().isEmpty || !mounted) return;
    _barcodeController.text = code.trim();
    setState(() => _barcodeLoading = true);
    try {
      final result = await _productRepository.lookupBarcode(code);
      if (!mounted) return;
      if (!result.hasEnabledProviders) {
        return;
      }
      if (!result.found) return;
      setState(() {
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = result.product.name ?? '';
        }
        if (_brandController.text.trim().isEmpty) {
          _brandController.text = result.product.brand ?? '';
        }
      });
    } catch (_) {
      // 外部服务失败时保留扫码得到的条码，用户可以继续手工填写。
    } finally {
      if (mounted) setState(() => _barcodeLoading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入商品名称');
      return;
    }
    if (_selectedIngredient == null && !_createNewIngredient) {
      setState(() => _error = '请选择关联的原料，或开启“新建同名原料”');
      return;
    }
    if (_selectedIngredient == null && _createNewIngredient) {
      setState(() => _saving = true);
      try {
        final ingredient =
            await _ingredientRepository.createIngredient(name: name);
        _selectedIngredient = ingredient;
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = '创建原料失败';
            _saving = false;
          });
        }
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      Product? createdProduct;
      ProductMutationResult? result;
      if (_isEdit) {
        result = await _productRepository.updateProduct(
          widget.product!.id,
          isAdmin: widget.isAdmin,
          name: name,
          ingredientId: _selectedIngredient!.id,
          brand: _brandController.text.trim(),
          barcode: _barcodeController.text.trim(),
          aliases: _aliases,
          tags: _tags,
        );
      } else {
        createdProduct = await _productRepository.createProduct(
          name: name,
          ingredientId: _selectedIngredient!.id,
          brand: _brandController.text.trim(),
          barcode: _barcodeController.text.trim(),
          aliases: _aliases,
          tags: _tags,
        );
      }
      if (!mounted) return;
      if (!_isEdit) {
        Navigator.of(context).pop(
          ProductFormResult(
            saved: true,
            pending: false,
            message: '已创建商品',
            product: createdProduct,
          ),
        );
        return;
      }
      Navigator.of(context).pop(
        ProductFormResult(
          saved: true,
          pending: result!.pending,
          message: result.message,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请重试';
        });
      }
    }
  }

  Widget _buildIngredientField() {
    if (widget.fixedIngredient != null && !_isEdit) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: '关联原料',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            const Icon(Icons.link, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.fixedIngredient!.name)),
          ],
        ),
      );
    }

    // 下拉带输入的关联原料选择（对齐 price_record_form_screen 商家选择做法）。
    return Autocomplete<Ingredient>(
      textEditingController: _ingredientSearchController,
      focusNode: _ingredientFocusNode,
      optionsBuilder: (textEditingValue) async {
        final query = textEditingValue.text.trim();
        // 当前文本就是已选原料名时不再搜索（避免编辑态预填触发查询）。
        if (query.isEmpty ||
            (_selectedIngredient != null &&
                _selectedIngredient!.name == query)) {
          if (_searching) setState(() => _searching = false);
          return const <Ingredient>[];
        }
        return _searchIngredients(query);
      },
      displayStringForOption: (ingredient) => ingredient.name,
      onSelected: (ingredient) {
        _ingredientSearchController.text = ingredient.name;
        setState(() {
          _selectedIngredient = ingredient;
          _searching = false;
        });
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final ingredient = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(ingredient.name),
                    subtitle: ingredient.category == null
                        ? null
                        : Text(ingredient.category!),
                    onTap: () => onSelected(ingredient),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: '搜索并选择关联原料 *',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => onFieldSubmitted(),
          onChanged: (value) {
            // 文本被改动后不再信任原选择；要保留必须重新点选。
            if (_selectedIngredient != null &&
                _selectedIngredient!.name != value.trim()) {
              setState(() => _selectedIngredient = null);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text(_isEdit ? '编辑商品' : '添加商品')),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      initialValue: null,
                      decoration: const InputDecoration(
                        labelText: '商品名称 *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_createNewIngredient) _buildIngredientField(),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('新建同名原料'),
                      subtitle: const Text('开启后将自动创建与商品同名的原料'),
                      value: _createNewIngredient,
                      onChanged: (v) =>
                          setState(() => _createNewIngredient = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _brandController,
                      initialValue: null,
                      decoration: const InputDecoration(
                        labelText: '品牌',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _barcodeController,
                      initialValue: null,
                      decoration: InputDecoration(
                        labelText: '条码',
                        border: const OutlineInputBorder(),
                        suffixIcon: _barcodeLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                tooltip: '扫码输入条码',
                                icon: const Icon(Icons.barcode_reader),
                                onPressed: _scanBarcode,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AliasTagsField(
                      label: '别名',
                      initialTags: _aliases,
                      onTagsChanged: (aliases) => _aliases = aliases,
                    ),
                    if (_isEdit) ...[
                      const SizedBox(height: 16),
                      AliasTagsField(
                        label: '标签',
                        initialTags: _tags,
                        onTagsChanged: (tags) => _tags = tags,
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中...' : '保存'),
              ),
            ),
          ),
        ),
        if (_barcodeLoading) const LoadingOverlay(message: '正在查询商品信息…'),
      ],
    );
  }
}
