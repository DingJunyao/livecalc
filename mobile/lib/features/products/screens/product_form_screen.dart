import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
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
  // 我的权重覆盖（仅编辑态显示；个人偏好不走审核）
  bool _myWeightEnabled = false;
  int _myWeight = 50;
  int _globalWeight = 50;

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
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _ingredientSearchController.dispose();
    _ingredientFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    final l10n = AppLocalizations.of(context);
    try {
      final product = (await _productRepository.getProduct(widget.product!.id))
          .mergedWithPending();
      // 我的权重覆盖与商品信息并行加载；失败不阻塞表单（与 web 行为一致）
      MyWeightInfo? myWeight;
      try {
        myWeight = await _productRepository.getMyWeight(widget.product!.id);
      } catch (_) {}
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
        if (myWeight != null) {
          _myWeightEnabled = myWeight.source == 'override';
          _myWeight = myWeight.overrideWeight ?? myWeight.globalWeight;
          _globalWeight = myWeight.globalWeight;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = l10n.productLoadFailed;
        });
      }
    }
  }

  /// 搜索关联原料（供 Autocomplete.optionsBuilder 异步调用）。
  Future<List<Ingredient>> _searchIngredients(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      ++_ingredientSearchSeq;
      if (mounted && _searching) setState(() => _searching = false);
      return const <Ingredient>[];
    }

    final seq = ++_ingredientSearchSeq;
    if (mounted) setState(() => _searching = true);
    try {
      final result = await _ingredientRepository.search(
        search: q,
        limit: 20,
      );
      if (!mounted || seq != _ingredientSearchSeq) {
        return const <Ingredient>[];
      }
      if (mounted) setState(() => _searching = false);
      return result.items;
    } catch (_) {
      if (mounted && seq == _ingredientSearchSeq) {
        setState(() => _searching = false);
      }
      return const <Ingredient>[];
    }
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
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.productNameRequired);
      return;
    }
    if (_selectedIngredient == null && !_createNewIngredient) {
      setState(() => _error = l10n.productSelectIngredientOrCreate);
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
            _error = l10n.productCreateIngredientFailed;
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
            message: l10n.productCreated,
            product: createdProduct,
          ),
        );
        return;
      }
      // 我的权重覆盖：开关开 → set；关 → delete（用回全局）。
      // 个人偏好接口失败不阻塞保存，与 web 行为一致。
      try {
        if (_myWeightEnabled) {
          await _productRepository.setMyWeight(
            widget.product!.id,
            _myWeight,
          );
        } else {
          await _productRepository.deleteMyWeight(widget.product!.id);
        }
      } catch (_) {}
      if (!mounted) return;
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
          _error = l10n.commonSaveFailedRetry;
        });
      }
    }
  }

  Widget _buildIngredientField() {
    final l10n = AppLocalizations.of(context);
    if (widget.fixedIngredient != null && !_isEdit) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.productLinkedIngredient,
          border: const OutlineInputBorder(),
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
          alignment: AlignmentDirectional.topStart,
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
            labelText: _isEdit
                ? l10n.productLinkedIngredient
                : l10n.productSearchIngredient,
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
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              _isEdit ? l10n.productEditTitle : l10n.productAddTitle,
            ),
            actions: [
              TextButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? l10n.commonSaving : l10n.commonSave),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      initialValue: null,
                      decoration: InputDecoration(
                        labelText: l10n.productName,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_createNewIngredient) _buildIngredientField(),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(l10n.productCreateSameName),
                      subtitle: Text(l10n.productCreateSameNameHint),
                      value: _createNewIngredient,
                      onChanged: (v) =>
                          setState(() => _createNewIngredient = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _brandController,
                      initialValue: null,
                      decoration: InputDecoration(
                        labelText: l10n.productBrand,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _barcodeController,
                      initialValue: null,
                      decoration: InputDecoration(
                        labelText: l10n.productBarcode,
                        border: const OutlineInputBorder(),
                        suffixIcon: _barcodeLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                tooltip: l10n.productScanBarcode,
                                icon: const Icon(Icons.barcode_reader),
                                onPressed: _scanBarcode,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AliasTagsField(
                      label: l10n.ingredientAliases,
                      initialTags: _aliases,
                      onTagsChanged: (aliases) => _aliases = aliases,
                    ),
                    if (_isEdit) ...[
                      const SizedBox(height: 16),
                      AliasTagsField(
                        label: l10n.productTags,
                        initialTags: _tags,
                        onTagsChanged: (tags) => _tags = tags,
                      ),
                      const SizedBox(height: 8),
                      // 我的权重覆盖：开关 + 滑块（所有人可设，仅影响自己）
                      SwitchListTile(
                        title: Text(l10n.productMyWeightOverride),
                        subtitle:
                            Text(l10n.productMyWeightGlobalDefault(_globalWeight)),
                        value: _myWeightEnabled,
                        onChanged: (v) =>
                            setState(() => _myWeightEnabled = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_myWeightEnabled)
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _myWeight.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 100,
                                label: '$_myWeight',
                                onChanged: (v) =>
                                    setState(() => _myWeight = v.round()),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '$_myWeight',
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
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
        ),
        if (_barcodeLoading) LoadingOverlay(message: l10n.productLookupLoading),
      ],
    );
  }
}
