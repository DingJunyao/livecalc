import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/alias_tags_field.dart';
import '../models/ingredient.dart';
import '../providers/ingredient_provider.dart';
import '../repositories/ingredient_repository.dart';

class IngredientFormScreen extends ConsumerStatefulWidget {
  final Ingredient? ingredient;
  final int? ingredientId;
  final IngredientRepository? repository;

  const IngredientFormScreen({
    super.key,
    this.ingredient,
    this.ingredientId,
    this.repository,
  });

  @override
  ConsumerState<IngredientFormScreen> createState() =>
      _IngredientFormScreenState();
}

class _IngredientFormScreenState extends ConsumerState<IngredientFormScreen> {
  late final IngredientRepository _repository;
  late final TextEditingController _nameController;
  late List<String> _aliases;
  int? _categoryId;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  int? get _editId => widget.ingredient?.id ?? widget.ingredientId;

  bool get _isEdit => _editId != null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IngredientRepository();
    _nameController = TextEditingController(text: widget.ingredient?.name);
    _aliases = List.of(widget.ingredient?.aliases ?? const []);
    _categoryId = widget.ingredient?.categoryId;
    if (_isEdit && widget.ingredient == null) {
      _loading = true;
      Future.microtask(_loadIngredient);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadIngredient() async {
    try {
      final ingredient = await _repository.getIngredient(_editId!);
      if (!mounted) return;
      setState(() {
        _nameController.text = ingredient.name;
        _aliases = List.of(ingredient.aliases);
        _categoryId = ingredient.categoryId;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '原料加载失败，请重试';
        });
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入原料名称');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await _repository.updateIngredient(
          _editId!,
          name: name,
          categoryId: _categoryId,
          aliases: _aliases,
        );
      } else {
        await _repository.createIngredient(
          name: name,
          categoryId: _categoryId,
          aliases: _aliases,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请重试';
        });
      }
    }
  }

  Widget _buildCategoryField() {
    final categoriesAsync = ref.watch(ingredientCategoriesProvider);
    return categoriesAsync.when(
      data: (categories) => DropdownButtonFormField<int?>(
        initialValue: _categoryId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: '分类',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('未分类')),
          for (final category in categories)
            DropdownMenuItem<int?>(
              value: category.id,
              child: Text(category.displayName),
            ),
        ],
        onChanged: (value) => setState(() => _categoryId = value),
      ),
      loading: () => DropdownButtonFormField<int?>(
        items: null,
        disabledHint: const Text('分类加载中...'),
        onChanged: null,
        decoration: const InputDecoration(
          labelText: '分类',
          border: OutlineInputBorder(),
        ),
      ),
      error: (_, __) => const Text('分类加载失败'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑原料' : '添加原料')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nameController,
                  initialValue: null,
                  decoration: const InputDecoration(
                    labelText: '原料名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCategoryField(),
                const SizedBox(height: 16),
                AliasTagsField(
                  label: '别名',
                  initialTags: _aliases,
                  onTagsChanged: (aliases) => _aliases = aliases,
                ),
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
