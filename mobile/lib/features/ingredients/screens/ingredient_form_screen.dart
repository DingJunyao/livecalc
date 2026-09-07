import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/alias_tags_field.dart';
import '../models/ingredient.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/ingredient_provider.dart';
import '../repositories/ingredient_repository.dart';

class IngredientFormResult {
  final bool saved;
  final bool pending;
  final String message;

  const IngredientFormResult({
    required this.saved,
    required this.pending,
    required this.message,
  });
}

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
    final initialIngredient = widget.ingredient?.mergedWithPending();
    _nameController = TextEditingController(text: initialIngredient?.name);
    _aliases = List.of(initialIngredient?.aliases ?? const []);
    _categoryId = initialIngredient?.categoryId;
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
    final l10n = AppLocalizations.of(context);
    try {
      final ingredient =
          (await _repository.getIngredient(_editId!)).mergedWithPending();
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
          _error = l10n.ingredientLoadFailed;
        });
      }
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.ingredientNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      IngredientMutationResult? result;
      if (_isEdit) {
        result = await _repository.updateIngredient(
          _editId!,
          isAdmin: ref.read(authProvider).user?.isAdmin == true,
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
      if (!mounted) return;
      if (!_isEdit) {
        Navigator.of(context).pop(
          IngredientFormResult(
            saved: true,
            pending: false,
            message: l10n.ingredientCreated,
          ),
        );
        return;
      }
      Navigator.of(context).pop(
        IngredientFormResult(
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

  Widget _buildCategoryField() {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(ingredientCategoriesProvider);
    return categoriesAsync.when(
      data: (categories) => DropdownButtonFormField<int?>(
        initialValue: _categoryId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.ingredientCategory,
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem<int?>(
            value: null,
            child: Text(l10n.ingredientUncategorized),
          ),
          for (final category in categories)
            DropdownMenuItem<int?>(
              value: category.id,
              child: Text(category.localizedDisplayName(l10n)),
            ),
        ],
        onChanged: (value) => setState(() => _categoryId = value),
      ),
      loading: () => DropdownButtonFormField<int?>(
        items: null,
        disabledHint: Text(l10n.ingredientCategoriesLoading),
        onChanged: null,
        decoration: InputDecoration(
          labelText: l10n.ingredientCategory,
          border: const OutlineInputBorder(),
        ),
      ),
      error: (_, __) => Text(l10n.ingredientCategoriesLoadFailed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? l10n.ingredientEditTitle : l10n.ingredientAddTitle,
        ),
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
                    labelText: l10n.ingredientName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCategoryField(),
                const SizedBox(height: 16),
                AliasTagsField(
                  label: l10n.ingredientAliases,
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
            child: Text(_saving ? l10n.commonSaving : l10n.commonSave),
          ),
        ),
      ),
    );
  }
}
