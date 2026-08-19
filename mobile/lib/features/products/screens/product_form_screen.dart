import 'dart:async';

import 'package:flutter/material.dart';
import '../../../shared/widgets/alias_tags_field.dart';
import '../../ingredients/models/ingredient.dart';
import '../../ingredients/repositories/ingredient_repository.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';

class ProductFormResult {
  final bool saved;
  final bool pending;
  final String message;

  const ProductFormResult({
    required this.saved,
    required this.pending,
    required this.message,
  });
}

class ProductFormScreen extends StatefulWidget {
  final Ingredient? fixedIngredient;
  final Product? product;
  final ProductRepository? repository;
  final IngredientRepository? ingredientRepository;
  final bool isAdmin;

  const ProductFormScreen({
    super.key,
    this.fixedIngredient,
    this.product,
    this.repository,
    this.ingredientRepository,
    this.isAdmin = false,
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
  Timer? _debounce;
  List<Ingredient> _ingredientOptions = const [];
  List<String> _aliases = const [];
  List<String> _tags = const [];
  Ingredient? _selectedIngredient;
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
    _nameController = TextEditingController(text: initialProduct?.name);
    _brandController = TextEditingController(text: initialProduct?.brand);
    _barcodeController = TextEditingController(text: initialProduct?.barcode);
    _ingredientSearchController = TextEditingController();
    _selectedIngredient = widget.fixedIngredient;

    if (_isEdit) {
      _loading = true;
      Future.microtask(_loadProduct);
    } else {
      _ingredientSearchController.addListener(_onIngredientSearchChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _ingredientSearchController.dispose();
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
      _ingredientSearchController.addListener(_onIngredientSearchChanged);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '商品加载失败，请重试';
        });
      }
    }
  }

  void _onIngredientSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final query = _ingredientSearchController.text.trim();
      if (query.isEmpty) {
        setState(() {
          _ingredientOptions = const [];
          _searching = false;
        });
        return;
      }
      setState(() => _searching = true);
      try {
        final result = await _ingredientRepository.search(
          search: query,
          limit: 20,
        );
        if (mounted) {
          setState(() {
            _ingredientOptions = result.items;
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入商品名称');
      return;
    }
    if (_selectedIngredient == null) {
      setState(() => _error = '请选择关联的原料');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
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
        await _productRepository.createProduct(
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
          const ProductFormResult(
            saved: true,
            pending: false,
            message: '已创建商品',
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

    return Column(
      children: [
        TextField(
          controller: _ingredientSearchController,
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
        ),
        if (_selectedIngredient != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.check_circle, size: 16),
                label: Text(_selectedIngredient!.name),
                onDeleted: () => setState(() => _selectedIngredient = null),
              ),
            ),
          ),
        if (_ingredientOptions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _ingredientOptions.length,
              itemBuilder: (context, index) {
                final ingredient = _ingredientOptions[index];
                return ListTile(
                  dense: true,
                  title: Text(ingredient.name),
                  subtitle: ingredient.category == null
                      ? null
                      : Text(ingredient.category!),
                  onTap: () {
                    setState(() {
                      _selectedIngredient = ingredient;
                      _ingredientSearchController.text = ingredient.name;
                      _ingredientOptions = const [];
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                _buildIngredientField(),
                const SizedBox(height: 16),
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
                  decoration: const InputDecoration(
                    labelText: '条码',
                    border: OutlineInputBorder(),
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
    );
  }
}
