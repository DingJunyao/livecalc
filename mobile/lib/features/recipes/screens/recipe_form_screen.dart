import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe_detail.dart';
import '../repositories/recipe_repository.dart';

class RecipeFormResult {
  final bool saved;
  final bool pending;
  final int? recipeId;

  const RecipeFormResult({
    this.saved = false,
    this.pending = false,
    this.recipeId,
  });
}

class RecipeFormScreen extends ConsumerStatefulWidget {
  final RecipeDetail? recipe;
  final int? recipeId;
  final RecipeRepository? repository;

  const RecipeFormScreen({
    super.key,
    this.recipe,
    this.recipeId,
    this.repository,
  });

  @override
  ConsumerState<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends ConsumerState<RecipeFormScreen> {
  static const _basicSectionKey = 'recipe-save-basic';
  static const _ingredientsSectionKey = 'recipe-save-ingredients';
  static const _stepsSectionKey = 'recipe-save-steps';
  static const _tipsSectionKey = 'recipe-save-tips';

  static const _categories = [
    '荤菜',
    '素菜',
    '水产',
    '主食',
    '汤与粥',
    '早餐',
    '甜品',
    '调料',
    '半成品',
    '小食',
  ];

  static const _difficulties = <(String, String)>[
    ('simple', '简易'),
    ('easy', '简单'),
    ('medium', '中等'),
    ('hard', '困难'),
    ('expert', '专家'),
  ];

  late final RecipeRepository _repository;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _servings;
  late final TextEditingController _totalTime;
  late final TextEditingController _resultIngredient;
  final _ingredients = <_IngredientRow>[];
  final _steps = <_StepRow>[];
  final _tips = <_TipRow>[];

  final _ingredientSearch = TextEditingController();
  Timer? _ingredientDebounce;
  List<IngredientOption> _ingredientOptions = const [];
  List<RecipeUnitOption> _unitOptions = const [];
  _IngredientRow? _activeIngredientRow;
  bool _resultSearchActive = false;
  IngredientOption? _resultIngredientOption;
  String _category = _categories.first;
  String _difficulty = 'easy';
  bool _loading = false;
  bool _saving = false;
  String? _savingSection;
  String? _error;
  bool _hasSectionSave = false;
  bool _hasPendingSection = false;
  Map<String, dynamic> _basicBaseline = {};
  List<Map<String, dynamic>> _ingredientsBaseline = const [];
  List<Map<String, dynamic>> _stepsBaseline = const [];
  List<String> _tipsBaseline = const [];

  int? get _editId => widget.recipe?.id ?? widget.recipeId;
  bool get _isEdit => _editId != null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RecipeRepository();
    _name = TextEditingController(text: widget.recipe?.name);
    _description =
        TextEditingController(text: widget.recipe?.description ?? '');
    _servings = TextEditingController(text: '${widget.recipe?.servings ?? 1}');
    _totalTime = TextEditingController(
      text: widget.recipe?.totalTimeMinutes?.toString() ?? '',
    );
    _resultIngredient = TextEditingController();
    _category = widget.recipe?.category ?? _categories.first;
    _difficulty = widget.recipe?.difficulty ?? 'easy';
    _fillRows(widget.recipe ?? const RecipeDetail(id: 0, name: ''));
    _resetBaselines();
    _ingredientSearch.addListener(_onIngredientSearch);
    _loading = _isEdit && widget.recipe == null;
    Future.microtask(() async {
      await _loadUnits();
      if (_isEdit && widget.recipe == null) await _loadRecipe();
      if (widget.recipe?.resultIngredientId != null) await _loadResultName();
    });
  }

  @override
  void dispose() {
    _ingredientDebounce?.cancel();
    _ingredientSearch.removeListener(_onIngredientSearch);
    _ingredientSearch.dispose();
    _name.dispose();
    _description.dispose();
    _servings.dispose();
    _totalTime.dispose();
    _resultIngredient.dispose();
    for (final row in _ingredients) {
      row.dispose();
    }
    for (final row in _steps) {
      row.dispose();
    }
    for (final row in _tips) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final units = await _repository.getUnitOptions();
      if (!mounted) return;
      setState(() => _unitOptions = units);
    } on Exception {
      // 原料没有单位仍可保存；这里不阻断表单。
    }
  }

  Future<void> _loadRecipe() async {
    try {
      final loaded = await _repository.getRecipe(_editId!);
      final detail =
          loaded.pendingProposal == null ? loaded : loaded.mergedWithPending();
      if (!mounted) return;
      setState(() {
        _name.text = detail.name;
        _description.text = detail.description ?? '';
        _servings.text = detail.servings.toString();
        _totalTime.text = detail.totalTimeMinutes?.toString() ?? '';
        _category = detail.category ?? _categories.first;
        _difficulty = detail.difficulty ?? 'easy';
        _fillRows(detail);
        _resetBaselines();
        _loading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _error = '菜谱加载失败，请重试';
        _loading = false;
      });
    }
  }

  Future<void> _loadResultName() async {
    final id = widget.recipe?.resultIngredientId;
    if (id == null) return;
    try {
      final name = await _repository.getIngredientName(id);
      if (!mounted || name == null) return;
      setState(() {
        _resultIngredient.text = name;
        _resultIngredientOption = IngredientOption(id: id, name: name);
        _resetBaselines();
      });
    } on Exception {
      if (mounted) {
        setState(() => _resultIngredient.text = '原料 #$id');
      }
    }
  }

  void _fillRows(RecipeDetail detail) {
    for (final row in _ingredients) {
      row.dispose();
    }
    for (final row in _steps) {
      row.dispose();
    }
    for (final row in _tips) {
      row.dispose();
    }
    _ingredients
      ..clear()
      ..addAll([
        for (final ingredient in detail.ingredients)
          _IngredientRow.fromModel(ingredient),
      ]);
    _steps
      ..clear()
      ..addAll([
        for (final step in detail.steps) _StepRow.fromModel(step),
      ]);
    _tips
      ..clear()
      ..addAll([
        for (final tip in detail.tips) _TipRow(tip),
      ]);
    if (_ingredients.isEmpty) _addIngredient();
    if (_steps.isEmpty) _addStep();
    if (_tips.isEmpty) _addTip();
  }

  void _onIngredientSearch() {
    _ingredientDebounce?.cancel();
    final query = _ingredientSearch.text.trim();
    if (query.isEmpty) {
      setState(() => _ingredientOptions = const []);
      return;
    }
    _ingredientDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final options = await _repository.getIngredientOptions(query);
        if (mounted) setState(() => _ingredientOptions = options);
      } on Exception {
        if (mounted) setState(() => _ingredientOptions = const []);
      }
    });
  }

  void _syncIngredientSearch(String query, {_IngredientRow? row}) {
    setState(() {
      _activeIngredientRow = row;
      _resultSearchActive = row == null;
    });
    if (_ingredientSearch.text.trim() == query) return;
    _ingredientSearch.text = query;
  }

  void _pickIngredient(IngredientOption option, {_IngredientRow? row}) {
    setState(() {
      if (row == null) {
        _resultIngredient.text = option.name;
        _resultIngredientOption = option;
      } else {
        row.name.text = option.name;
      }
      _ingredientOptions = const [];
      _activeIngredientRow = null;
      _resultSearchActive = false;
    });
    _ingredientSearch.clear();
  }

  int? _unitIdFor(String? label) {
    if (label == null || label.isEmpty) return null;
    for (final unit in _unitOptions) {
      if (unit.label == label) return unit.id;
    }
    return null;
  }

  String? _validateIngredientQuantities() {
    for (var i = 0; i < _ingredients.length; i++) {
      final row = _ingredients[i];
      final name = row.name.text.trim();
      if (name.isEmpty || row.quantityType != null) continue;
      final rec = double.tryParse(row.recommended.text.trim());
      final min = double.tryParse(row.min.text.trim());
      final max = double.tryParse(row.max.text.trim());
      final hasRec = row.recommended.text.trim().isNotEmpty && rec != null;
      final hasMin = row.min.text.trim().isNotEmpty && min != null;
      final hasMax = row.max.text.trim().isNotEmpty && max != null;
      final valid = (hasRec && hasMin && hasMax) ||
          (hasRec && !hasMin && !hasMax) ||
          (!hasRec && hasMin && hasMax) ||
          (!hasRec && !hasMin && !hasMax);
      if (!valid || (hasMin && hasMax && max < min)) {
        return '第 ${i + 1} 行原料的用量组合不完整：仅支持推荐值、推荐值+区间或仅区间';
      }
    }
    return null;
  }

  Map<String, dynamic> _basicPayload() {
    final servings = int.tryParse(_servings.text.trim()) ?? 1;
    final totalTime = int.tryParse(_totalTime.text.trim());
    return {
      'name': _name.text.trim(),
      'category': _category,
      'difficulty': _difficulty,
      'description': _description.text.trim(),
      'servings': servings < 1 ? 1 : servings,
      if (totalTime != null) 'total_time_minutes': totalTime,
      'result_ingredient_id': _resultIngredientOption?.id,
    };
  }

  RecipeIngredientInput _ingredientInput(_IngredientRow row) {
    return RecipeIngredientInput(
      ingredientName: row.name.text.trim(),
      quantity:
          row.quantityType == null && row.recommended.text.trim().isNotEmpty
              ? row.recommended.text.trim()
              : null,
      quantityMin: row.quantityType == null && row.min.text.trim().isNotEmpty
          ? double.tryParse(row.min.text.trim())
          : null,
      quantityMax: row.quantityType == null && row.max.text.trim().isNotEmpty
          ? double.tryParse(row.max.text.trim())
          : null,
      unitId: _unitIdFor(row.unitLabel),
      isOptional: row.optional,
      note: row.note.text.trim().isEmpty ? null : row.note.text.trim(),
      originalQuantity: row.quantityType,
    );
  }

  List<RecipeIngredientInput> _ingredientInputs() {
    final ingredients = <RecipeIngredientInput>[
      for (final row in _ingredients)
        if (row.name.text.trim().isNotEmpty) _ingredientInput(row),
    ];
    return ingredients;
  }

  List<Map<String, dynamic>> _stepPayload() {
    final steps = <Map<String, dynamic>>[];
    for (final row in _steps) {
      if (row.content.text.trim().isEmpty) continue;
      steps.add({
        'content': row.content.text.trim(),
        if (double.tryParse(row.duration.text.trim()) != null)
          'duration_minutes': double.tryParse(row.duration.text.trim()),
        if (row.tips.text.trim().isNotEmpty) 'tips': row.tips.text.trim(),
      });
    }
    return steps;
  }

  List<String> _tipPayload() {
    final tips = [
      for (final row in _tips)
        if (row.text.text.trim().isNotEmpty) row.text.text.trim(),
    ];
    return tips;
  }

  Map<String, dynamic> _payload() {
    return {
      ..._basicPayload(),
      'ingredients': _ingredientInputs(),
      'cooking_steps': _stepPayload(),
      'tips': _tipPayload(),
    };
  }

  void _resetBaselines() {
    _basicBaseline = _basicPayload();
    _ingredientsBaseline = [
      for (final input in _ingredientInputs()) input.toJson(),
    ];
    _stepsBaseline = _stepPayload();
    _tipsBaseline = _tipPayload();
  }

  Map<String, dynamic> _changedBasicPayload() {
    final current = _basicPayload();
    return {
      for (final entry in current.entries)
        if (jsonEncode(entry.value) != jsonEncode(_basicBaseline[entry.key]))
          entry.key: entry.value,
    };
  }

  bool _listJsonEquals(
      List<Map<String, dynamic>> current, List<Map<String, dynamic>> baseline) {
    return jsonEncode(current) == jsonEncode(baseline);
  }

  Future<void> _saveBasicSection() async {
    await _saveEditSection(
      sectionKey: _basicSectionKey,
      validate: () {
        if (_name.text.trim().isEmpty) return '请输入菜谱名称';
        return null;
      },
      payload: _changedBasicPayload(),
      baseline: _basicBaseline,
      commitBaseline: () => _basicBaseline = _basicPayload(),
    );
  }

  Future<void> _saveIngredientsSection() async {
    await _saveEditSection(
      sectionKey: _ingredientsSectionKey,
      validate: _validateIngredientQuantities,
      payload: {'ingredients': _ingredientInputs()},
      baseline: _ingredientsBaseline,
      current: [for (final input in _ingredientInputs()) input.toJson()],
      commitBaseline: () => _ingredientsBaseline = [
        for (final input in _ingredientInputs()) input.toJson(),
      ],
    );
  }

  Future<void> _saveStepsSection() async {
    await _saveEditSection(
      sectionKey: _stepsSectionKey,
      payload: {'cooking_steps': _stepPayload()},
      baseline: _stepsBaseline,
      current: _stepPayload(),
      commitBaseline: () => _stepsBaseline = _stepPayload(),
    );
  }

  Future<void> _saveTipsSection() async {
    await _saveEditSection(
      sectionKey: _tipsSectionKey,
      payload: {'tips': _tipPayload()},
      baseline: _tipsBaseline,
      current: _tipPayload(),
      commitBaseline: () => _tipsBaseline = _tipPayload(),
    );
  }

  Future<void> _saveEditSection({
    required String sectionKey,
    String? Function()? validate,
    required Map<String, dynamic> payload,
    required Object baseline,
    Object? current,
    required VoidCallback commitBaseline,
  }) async {
    if (_savingSection != null || _saving) return;
    final validationError = validate?.call();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    final unchanged = current == null
        ? payload.isEmpty
        : (current is List<Map<String, dynamic>> &&
                baseline is List<Map<String, dynamic>> &&
                _listJsonEquals(current, baseline)) ||
            (current is List<String> &&
                baseline is List<String> &&
                jsonEncode(current) == jsonEncode(baseline));
    if (unchanged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前部分没有修改')),
      );
      return;
    }
    setState(() {
      _savingSection = sectionKey;
      _error = null;
    });
    try {
      final result = await _repository.updateRecipe(_editId!, payload);
      if (!mounted) return;
      commitBaseline();
      setState(() {
        _hasSectionSave = true;
        if (result.pending) _hasPendingSection = true;
      });
      final message = result.pending
          ? (result.message.isEmpty ? '修改已提交，待管理员审核' : result.message)
          : '保存成功';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on Exception {
      if (!mounted) return;
      setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _savingSection = null);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = '请输入菜谱名称');
      return;
    }
    final ingredientError = _validateIngredientQuantities();
    if (ingredientError != null) {
      setState(() => _error = ingredientError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = _payload();
      final result = _isEdit
          ? await _repository.updateRecipe(_editId!, payload)
          : await _repository.createRecipe(payload);
      if (!mounted) return;
      final message = result.pending
          ? (result.message.isEmpty ? '修改已提交，待管理员审核' : result.message)
          : '保存成功';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(RecipeFormResult(
        saved: true,
        pending: result.pending,
        recipeId: _editId ?? result.detail?.id,
      ));
    } on Exception {
      if (!mounted) return;
      setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addIngredient() {
    setState(() => _ingredients.add(_IngredientRow()));
  }

  void _removeIngredient(int index) {
    setState(() {
      final row = _ingredients.removeAt(index);
      row.dispose();
      if (_activeIngredientRow == row) _activeIngredientRow = null;
    });
  }

  void _moveIngredient(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _ingredients.length) return;
    setState(() {
      final row = _ingredients.removeAt(index);
      _ingredients.insert(target, row);
    });
  }

  void _addStep() {
    setState(() => _steps.add(_StepRow()));
  }

  void _removeStep(int index) {
    setState(() => _steps[index].dispose());
    setState(() => _steps.removeAt(index));
  }

  void _moveStep(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _steps.length) return;
    setState(() {
      final row = _steps.removeAt(index);
      _steps.insert(target, row);
    });
  }

  void _addTip() {
    setState(() => _tips.add(_TipRow('')));
  }

  void _removeTip(int index) {
    setState(() => _tips[index].dispose());
    setState(() => _tips.removeAt(index));
  }

  void _moveTip(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _tips.length) return;
    setState(() {
      final row = _tips.removeAt(index);
      _tips.insert(target, row);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope<RecipeFormResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(
          RecipeFormResult(
            saved: _hasSectionSave,
            pending: _hasPendingSection,
            recipeId: _editId,
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_isEdit ? '编辑菜谱' : '创建菜谱')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section(
                    theme,
                    '基本信息',
                    Icons.info_outline,
                    [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: '菜谱名称',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: '分类',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final category in _categories)
                            DropdownMenuItem(
                                value: category, child: Text(category)),
                        ],
                        onChanged: (value) => setState(
                            () => _category = value ?? _categories.first),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _difficulty,
                        decoration: const InputDecoration(
                          labelText: '难度',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final (value, label) in _difficulties)
                            DropdownMenuItem(value: value, child: Text(label)),
                        ],
                        onChanged: (value) =>
                            setState(() => _difficulty = value ?? 'easy'),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _servings,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '份数',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _totalTime,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '总时间（分钟）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: '简介',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ingredientField(
                        controller: _resultIngredient,
                        label: '成品产出原料',
                        onChanged: (value) =>
                            _syncIngredientSearch(value, row: null),
                        showOptions: _resultSearchActive,
                      ),
                    ],
                    saveKey: _basicSectionKey,
                    onSave: _isEdit ? _saveBasicSection : null,
                    saving: _savingSection == _basicSectionKey,
                  ),
                  const SizedBox(height: 16),
                  _section(
                    theme,
                    '原料',
                    Icons.restaurant_menu,
                    [
                      for (var i = 0; i < _ingredients.length; i++) ...[
                        _ingredientCard(theme, i),
                        const SizedBox(height: 12),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addIngredient,
                          icon: const Icon(Icons.add),
                          label: const Text('添加原料'),
                        ),
                      ),
                    ],
                    saveKey: _ingredientsSectionKey,
                    onSave: _isEdit ? _saveIngredientsSection : null,
                    saving: _savingSection == _ingredientsSectionKey,
                  ),
                  const SizedBox(height: 16),
                  _section(
                    theme,
                    '步骤',
                    Icons.format_list_numbered,
                    [
                      for (var i = 0; i < _steps.length; i++) ...[
                        _stepCard(theme, i),
                        const SizedBox(height: 12),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addStep,
                          icon: const Icon(Icons.add),
                          label: const Text('添加步骤'),
                        ),
                      ),
                    ],
                    saveKey: _stepsSectionKey,
                    onSave: _isEdit ? _saveStepsSection : null,
                    saving: _savingSection == _stepsSectionKey,
                  ),
                  const SizedBox(height: 16),
                  _section(
                    theme,
                    '小贴士',
                    Icons.lightbulb_outline,
                    [
                      for (var i = 0; i < _tips.length; i++) ...[
                        _tipRow(theme, i),
                        const SizedBox(height: 8),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addTip,
                          icon: const Icon(Icons.add),
                          label: const Text('添加小贴士'),
                        ),
                      ),
                    ],
                    saveKey: _tipsSectionKey,
                    onSave: _isEdit ? _saveTipsSection : null,
                    saving: _savingSection == _tipsSectionKey,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
        bottomNavigationBar: _isEdit
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('创建菜谱'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _section(
    ThemeData theme,
    String title,
    IconData icon,
    List<Widget> children, {
    String? saveKey,
    VoidCallback? onSave,
    bool saving = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              if (onSave != null)
                TextButton.icon(
                  key: saveKey == null ? null : ValueKey(saveKey),
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('保存'),
                ),
            ]),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _ingredientField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    required bool showOptions,
  }) {
    return Column(
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      _ingredientSearch.clear();
                      setState(() {
                        _ingredientOptions = const [];
                        _activeIngredientRow = null;
                        _resultSearchActive = false;
                        _resultIngredientOption = null;
                      });
                    },
                  ),
          ),
          onChanged: onChanged,
        ),
        if (showOptions && _ingredientOptions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 190),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _ingredientOptions.length,
              itemBuilder: (context, index) {
                final option = _ingredientOptions[index];
                return ListTile(
                  dense: true,
                  title: Text(option.name),
                  onTap: () => _pickIngredient(
                    option,
                    row: _activeIngredientRow,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _ingredientCard(ThemeData theme, int index) {
    final row = _ingredients[index];
    final unitItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('不指定')),
      for (final unit in _unitOptions)
        DropdownMenuItem(value: unit.label, child: Text(unit.label)),
      if (row.unitLabel.isNotEmpty &&
          _unitOptions.every((unit) => unit.label != row.unitLabel))
        DropdownMenuItem(value: row.unitLabel, child: Text(row.unitLabel)),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: _ingredientField(
                controller: row.name,
                label: '原料',
                onChanged: (value) => _syncIngredientSearch(value, row: row),
                showOptions: identical(row, _activeIngredientRow),
              ),
            ),
            IconButton(
              tooltip: '上移',
              onPressed: index == 0 ? null : () => _moveIngredient(index, -1),
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: '下移',
              onPressed: index == _ingredients.length - 1
                  ? null
                  : () => _moveIngredient(index, 1),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: () => _removeIngredient(index),
              icon: const Icon(Icons.delete_outline),
            ),
          ]),
          const SizedBox(height: 10),
          SegmentedButton<String?>(
            segments: const [
              ButtonSegment(value: null, label: Text('数值')),
              ButtonSegment(value: '适量', label: Text('适量')),
              ButtonSegment(value: '少许', label: Text('少许')),
            ],
            selected: {row.quantityType},
            onSelectionChanged: (values) =>
                setState(() => row.quantityType = values.first),
          ),
          if (row.quantityType == null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: row.recommended,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '推荐量',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.min,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '最小',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.max,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '最大',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: row.unitLabel,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '单位',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: unitItems,
                onChanged: (value) =>
                    setState(() => row.unitLabel = value ?? ''),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SwitchListTile(
                value: row.optional,
                onChanged: (value) => setState(() => row.optional = value),
                title: const Text('可选'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ]),
          TextFormField(
            controller: row.note,
            decoration: const InputDecoration(
              labelText: '备注',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCard(ThemeData theme, int index) {
    final row = _steps[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text(
              '步骤 ${index + 1}',
              style: theme.textTheme.labelLarge,
            ),
          ),
          IconButton(
            tooltip: '上移',
            onPressed: index == 0 ? null : () => _moveStep(index, -1),
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: '下移',
            onPressed:
                index == _steps.length - 1 ? null : () => _moveStep(index, 1),
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: () => _removeStep(index),
            icon: const Icon(Icons.delete_outline),
          ),
        ]),
        TextFormField(
          controller: row.content,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: '内容',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: row.duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '耗时（分钟）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        TextFormField(
          controller: row.tips,
          decoration: const InputDecoration(
            labelText: '步骤提示',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ]),
    );
  }

  Widget _tipRow(ThemeData theme, int index) {
    final row = _tips[index];
    return Row(children: [
      Expanded(
        child: TextFormField(
          controller: row.text,
          decoration: const InputDecoration(
            labelText: '小贴士',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ),
      IconButton(
        tooltip: '上移',
        onPressed: index == 0 ? null : () => _moveTip(index, -1),
        icon: const Icon(Icons.keyboard_arrow_up),
      ),
      IconButton(
        tooltip: '下移',
        onPressed: index == _tips.length - 1 ? null : () => _moveTip(index, 1),
        icon: const Icon(Icons.keyboard_arrow_down),
      ),
      IconButton(
        tooltip: '删除',
        onPressed: () => _removeTip(index),
        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
      ),
    ]);
  }
}

class _IngredientRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController recommended = TextEditingController();
  final TextEditingController min = TextEditingController();
  final TextEditingController max = TextEditingController();
  final TextEditingController note = TextEditingController();
  String? quantityType;
  String unitLabel = '';
  bool optional = false;

  _IngredientRow();

  factory _IngredientRow.fromModel(RecipeIngredient ingredient) {
    final row = _IngredientRow();
    row.name.text = ingredient.name;
    final original = ingredient.originalQuantity;
    if (original == '适量' || original == '少许') {
      row.quantityType = original;
    } else {
      row.recommended.text = ingredient.quantity ?? '';
      final range = ingredient.quantityRange;
      if (range != null && (range.min != 0 || range.max != 0)) {
        row.min.text = range.min.toString();
        row.max.text = range.max.toString();
      }
    }
    row.unitLabel = ingredient.unit ?? '';
    row.optional = ingredient.isOptional;
    row.note.text = ingredient.note ?? '';
    return row;
  }

  void dispose() {
    name.dispose();
    recommended.dispose();
    min.dispose();
    max.dispose();
    note.dispose();
  }
}

class _StepRow {
  final TextEditingController content = TextEditingController();
  final TextEditingController duration = TextEditingController();
  final TextEditingController tips = TextEditingController();

  _StepRow();

  factory _StepRow.fromModel(RecipeStep step) {
    final row = _StepRow();
    row.content.text = step.content;
    row.duration.text =
        step.durationMinutes == null ? '' : step.durationMinutes.toString();
    row.tips.text = step.tips ?? '';
    return row;
  }

  void dispose() {
    content.dispose();
    duration.dispose();
    tips.dispose();
  }
}

class _TipRow {
  final TextEditingController text = TextEditingController();

  _TipRow(String initial) {
    text.text = initial;
  }

  void dispose() {
    text.dispose();
  }
}
