import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/models/entity_unit.dart';
import '../../../shared/models/nutrition.dart';
import '../../../shared/screens/entity_units_draft_screen.dart';
import '../../../shared/screens/nutrition_edit_screen.dart';
import '../../../shared/services/entity_draft_persist.dart';
import '../../../shared/widgets/alias_tags_field.dart';
import '../../entities/repositories/entity_repository.dart';
import '../models/ingredient.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/ingredient_provider.dart';
import '../repositories/ingredient_repository.dart';
import '../../../shared/widgets/save_action_button.dart';
import '../../profile/providers/save_button_position_provider.dart';

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
  /// 测试注入：全局单位来源（缺省走真实接口）。
  final EntityRepository? entityRepository;
  /// 测试注入：草稿落库器。
  final EntityDraftPersister? draftPersister;

  const IngredientFormScreen({
    super.key,
    this.ingredient,
    this.ingredientId,
    this.repository,
    this.entityRepository,
    this.draftPersister,
  });

  @override
  ConsumerState<IngredientFormScreen> createState() =>
      _IngredientFormScreenState();
}

class _IngredientFormScreenState extends ConsumerState<IngredientFormScreen> {
  late final IngredientRepository _repository;
  late final EntityRepository _entityRepository;
  late final TextEditingController _nameController;
  late List<String> _aliases;
  int? _categoryId;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  // 新增原料时先填好的「自定义单位 / 营养信息」草稿：原料创建成功后才落库
  final List<EntityUnit> _draftUnits = [];
  List<NutrientEntry> _draftNutrients = const [];
  List<GlobalUnitOption> _globalUnitOptions = const [];
  bool _loadingDraftUnits = false;
  bool _draftUnitsLoaded = false;

  int? get _editId => widget.ingredient?.id ?? widget.ingredientId;

  bool get _isEdit => _editId != null;

  int get _draftNutrientCount => _draftNutrients
      .where((entry) => entry.label.trim().isNotEmpty && entry.value > 0)
      .length;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IngredientRepository();
    _entityRepository = widget.entityRepository ?? EntityRepository();
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
        final created = await _repository.createIngredient(
          name: name,
          categoryId: _categoryId,
          aliases: _aliases,
        );
        if (!mounted) return;
        // 原料已创建（拿到 id）→ 把自定义单位 / 营养信息草稿一并写**原料层级**
        if (_draftUnits.isNotEmpty || _draftNutrients.isNotEmpty) {
          await _persistDrafts(created.id);
          if (!mounted) return;
        }
        Navigator.of(context).pop(
          IngredientFormResult(
            saved: true,
            pending: false,
            message: l10n.ingredientCreated,
          ),
        );
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        IngredientFormResult(
          saved: true,
          pending: result.pending,
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

  // ---------- 新增原料时的自定义单位 / 营养信息草稿 ----------

  /// 打开单位草稿页前准备参照数据（全局单位）；原料没有「关联原料」这一层，故无继承单位。
  Future<void> _ensureDraftUnitReference() async {
    if (_draftUnitsLoaded) return;
    if (mounted) setState(() => _loadingDraftUnits = true);
    var globals = <GlobalUnitOption>[];
    try {
      final rows = await _entityRepository.listGlobalUnits();
      globals = [for (final row in rows) GlobalUnitOption.fromJson(row)];
    } on Exception {
      // 全局单位加载失败不阻塞草稿页：下拉只剩「默认（克）」与已有草稿
      globals = const [];
    }
    if (!mounted) return;
    setState(() {
      _globalUnitOptions = globals;
      _draftUnitsLoaded = true;
      _loadingDraftUnits = false;
    });
  }

  Future<void> _openDraftUnits() async {
    await _ensureDraftUnitReference();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => EntityUnitsDraftScreen(
          initialUnits: _draftUnits,
          globalUnitOptions: _globalUnitOptions,
          effectiveDensityKgM3: 1000,
          target: AppLocalizations.of(context).productDraftTargetIngredient,
          onChanged: (units) {
            if (!mounted) return;
            setState(() {
              _draftUnits
                ..clear()
                ..addAll(units);
            });
          },
        ),
      ),
    );
  }

  /// 打开营养草稿页：USDA 匹配直写服务端，原料还没创建时必须关掉。
  Future<void> _openDraftNutrition() async {
    await Navigator.of(context).push<NutritionEditResult>(
      MaterialPageRoute(
        builder: (ctx) => NutritionEditScreen(
          entityType: 'ingredient',
          entityId: 0,
          initialNutrients: _draftNutrients,
          allowUsda: false,
          onSave: (entries) async {
            _draftNutrients = entries;
            return null;
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// 原料创建成功后把草稿一并落库，并按结果提示。
  Future<void> _persistDrafts(int ingredientId) async {
    final persister = widget.draftPersister ?? EntityDraftPersister();
    final result = await persister.persist(
      entityType: 'ingredient',
      entityId: ingredientId,
      units: _draftUnits,
      nutrients: _draftNutrients,
    );
    if (!mounted) return;
    _notifyDraftResult(result);
  }

  void _notifyDraftResult(EntityDraftPersistResult result) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    for (final issue in result.issues) {
      final String text;
      switch (issue.kind) {
        case 'cycle':
          text = l10n.productDraftUnitCycle(issue.names.join(', '));
          break;
        case 'refMissing':
          text = l10n.productDraftUnitRefMissing(issue.names.join(', '));
          break;
        case 'unit':
          text = l10n.productDraftUnitFailed(
            issue.names.isEmpty ? '' : issue.names.first,
            issue.detail,
          );
          break;
        default:
          text = l10n.productDraftNutritionFailed(issue.detail);
      }
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }
    if (result.hasExtras) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.productDraftExtrasSaved(
            l10n.productDraftTargetIngredient,
            result.unitsCreated,
            result.nutrientsSaved,
          )),
        ),
      );
    } else if (result.hasPending) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              l10n.productDraftExtrasPending(l10n.productDraftTargetIngredient)),
        ),
      );
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
    final savePosition = ref.watch(saveButtonPositionProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? l10n.ingredientEditTitle : l10n.ingredientAddTitle,
        ),
        actions: [
          ...saveAppBarActions(
            position: savePosition,
            onSave: _saving ? null : _save,
            label: _saving ? l10n.commonSaving : l10n.commonSave,
          ),
        ],
      ),
      bottomNavigationBar: saveBottomBar(
        context: context,
        position: savePosition,
        onSave: _saving ? null : _save,
        label: _saving ? l10n.commonSaving : l10n.commonSave,
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
                if (!_isEdit) ...[
                  const SizedBox(height: 16),
                  // 自定义单位 / 营养信息：在这里先填好，保存原料时一并保存
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.straighten),
                          title: Text(_draftUnits.isEmpty
                              ? l10n.productDraftUnitsButton
                              : l10n.productDraftUnitsButtonCount(
                                  _draftUnits.length)),
                          subtitle: Text(l10n.productDraftSavedTogether(
                              l10n.productDraftTargetIngredient)),
                          trailing: _loadingDraftUnits
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _saving ? null : _openDraftUnits,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.food_bank_outlined),
                          title: Text(_draftNutrientCount == 0
                              ? l10n.productDraftNutritionButton
                              : l10n.productDraftNutritionButtonCount(
                                  _draftNutrientCount)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _saving ? null : _openDraftNutrition,
                        ),
                      ],
                    ),
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
    );
  }
}
