import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_formatters.dart';
import '../../features/entities/repositories/entity_repository.dart';
import '../../features/profile/providers/save_button_position_provider.dart';
import '../../l10n/app_localizations.dart';
import '../models/entity_quantity_link.dart';
import '../utils/entity_unit_names.dart';
import 'save_action_button.dart';

/// 关联与换算的维护页。
///
/// 与单位/密度维护一致：独立整页、保存按钮跟随全局位置设置；
/// 单位用下拉，关联对象用可搜索选择页，选中即关闭。
class EntityQuantityLinkEditPage extends ConsumerStatefulWidget {
  final String entityType;
  final int entityId;
  final String? entityName;
  final int? ingredientId;
  final EntityQuantityLink? link;
  final EntityRepository? repository;
  /// 测试注入：返回实体自身可用的单位名（含关联单位）。
  final Future<List<String>> Function(
    String entityType,
    int entityId,
    int? ingredientId,
  )? unitNamesLoader;
  /// 测试注入：返回全局单位名。
  final Future<List<String>> Function()? globalUnitNamesLoader;
  /// 测试注入：返回实体「默认单位」名（商品自身默认 > 关联原料默认）。
  final Future<String?> Function(
    String entityType,
    int entityId,
    int? ingredientId,
  )? defaultUnitLoader;

  const EntityQuantityLinkEditPage({
    super.key,
    required this.entityType,
    required this.entityId,
    this.entityName,
    this.ingredientId,
    this.link,
    this.repository,
    this.unitNamesLoader,
    this.globalUnitNamesLoader,
    this.defaultUnitLoader,
  });

  @override
  ConsumerState<EntityQuantityLinkEditPage> createState() =>
      _EntityQuantityLinkEditPageState();
}

class _EntityQuantityLinkEditPageState
    extends ConsumerState<EntityQuantityLinkEditPage> {
  late final EntityRepository _repo;
  late final TextEditingController _fromQty;
  late final TextEditingController _toQty;
  late final TextEditingController _note;
  String _targetType = 'product';
  Map<String, dynamic>? _target;
  String? _fromUnit;
  String? _toUnit;
  List<String> _fromUnits = const [];
  List<String> _toUnits = const [];
  bool _loadingFromUnits = true;
  bool _loadingToUnits = false;
  bool _saving = false;

  bool get _isEditing => widget.link != null;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? EntityRepository();
    final link = widget.link;
    _targetType = link?.other.type ?? widget.entityType;
    _fromQty = TextEditingController(
      text: link == null ? '1' : formatQuantity(link.current.quantity),
    );
    _toQty = TextEditingController(
      text: link == null ? '1' : formatQuantity(link.other.quantity),
    );
    _note = TextEditingController(text: link?.note ?? '');
    if (link != null) {
      _target = {
        'id': link.other.id,
        'name': link.other.name,
        'ingredient_id': link.other.ingredientId,
      };
      _fromUnit = link.current.unit;
      _toUnit = link.other.unit;
    }
    _loadCurrentUnits();
    if (link != null) _loadTargetUnits();
  }

  @override
  void dispose() {
    _fromQty.dispose();
    _toQty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<List<String>> _loadUnits(
    String type,
    int id, {
    int? ingredientId,
  }) async {
    final own = widget.unitNamesLoader != null
        ? await widget.unitNamesLoader!(type, id, ingredientId)
        : await loadEntityUnitNames(
            entityType: type,
            entityId: id,
            ingredientId: ingredientId,
            includeLinkUnits: true,
          );
    final global = widget.globalUnitNamesLoader != null
        ? await widget.globalUnitNamesLoader!()
        : await loadGlobalUnitNames();
    final merged = <String>[];
    for (final name in [...own, ...global]) {
      final trimmed = name.trim();
      if (trimmed.isEmpty || merged.contains(trimmed)) continue;
      merged.add(trimmed);
    }
    return merged;
  }

  /// 实体「默认单位」名：商品自身默认 > 关联原料默认（与单位解析链一致）。
  Future<String?> _loadDefaultUnit(
    String type,
    int id,
    int? ingredientId,
  ) {
    if (widget.defaultUnitLoader != null) {
      return widget.defaultUnitLoader!(type, id, ingredientId);
    }
    return loadEntityDefaultUnitName(
      entityType: type,
      entityId: id,
      ingredientId: ingredientId,
    );
  }

  Future<void> _loadCurrentUnits() async {
    try {
      final names = await _loadUnits(
        widget.entityType,
        widget.entityId,
        ingredientId: widget.ingredientId,
      );
      // 新增时没有已选单位：带出实体默认单位（商品的默认优先于原料默认），
      // 而不是单位列表第一项（商品的「块」「盒」按创建顺序，块未必是默认）。
      final preferred = (_fromUnit == null || _fromUnit!.isEmpty)
          ? await _loadDefaultUnit(
              widget.entityType,
              widget.entityId,
              widget.ingredientId,
            )
          : null;
      if (!mounted) return;
      setState(() {
        _fromUnits = names;
        _fromUnit = _pickUnit(names, _fromUnit ?? preferred);
        _loadingFromUnits = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFromUnits = false);
    }
  }

  Future<void> _loadTargetUnits() async {
    final target = _target;
    if (target == null) return;
    final id = (target['id'] as num?)?.toInt();
    if (id == null) return;
    setState(() => _loadingToUnits = true);
    try {
      final names = await _loadUnits(
        _targetType,
        id,
        ingredientId: (target['ingredient_id'] as num?)?.toInt(),
      );
      final preferred = (_toUnit == null || _toUnit!.isEmpty)
          ? await _loadDefaultUnit(
              _targetType,
              id,
              (target['ingredient_id'] as num?)?.toInt(),
            )
          : null;
      if (!mounted) return;
      setState(() {
        _toUnits = names;
        _toUnit = _pickUnit(names, _toUnit ?? preferred);
        _loadingToUnits = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingToUnits = false);
    }
  }

  String? _pickUnit(List<String> options, String? current) {
    if (current != null && current.isNotEmpty && options.contains(current)) {
      return current;
    }
    return options.isEmpty ? null : options.first;
  }

  List<String> _optionsWithCurrent(List<String> options, String? current) {
    final list = [...options];
    if (current != null &&
        current.isNotEmpty &&
        !list.contains(current)) {
      list.insert(0, current);
    }
    return list;
  }

  Future<void> _pickTarget() async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TargetPickerSheet(
        repository: _repo,
        initialType: _targetType,
        l10n: l10n,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _targetType = selected['type']?.toString() ?? _targetType;
      _target = selected;
      _toUnits = const [];
      _toUnit = null;
    });
    await _loadTargetUnits();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final targetId = (_target?['id'] as num?)?.toInt();
    final fromQty = _parseNumber(_fromQty.text);
    final toQty = _parseNumber(_toQty.text);
    if (targetId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.entityLinksTargetRequired)),
      );
      return;
    }
    if (fromQty == null || fromQty <= 0 || toQty == null || toQty <= 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.entityLinksQuantityInvalid)),
      );
      return;
    }
    if ((_fromUnit ?? '').isEmpty || (_toUnit ?? '').isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.entityLinksUnitRequired)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final link = widget.link;
      EntityWriteResult<EntityQuantityLink> result;
      if (link == null) {
        result = await _repo.createQuantityLink(
          widget.entityType,
          widget.entityId,
          toType: _targetType,
          toId: targetId,
          fromQuantity: fromQty,
          fromUnit: _fromUnit!,
          toQuantity: toQty,
          toUnit: _toUnit!,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
      } else {
        result = await _repo.updateQuantityLink(
          widget.entityType,
          widget.entityId,
          link.id,
          fromQuantity: fromQty,
          fromUnit: _fromUnit!,
          toQuantity: toQty,
          toUnit: _toUnit!,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
      }
      if (!mounted) return;
      if (result.pending) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.message.isEmpty
                  ? l10n.commonSubmittedPendingReview
                  : result.message,
            ),
          ),
        );
      }
      Navigator.of(context).pop(result.pending ? 'pending' : 'saved');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.entityLinksSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final savePosition = ref.watch(saveButtonPositionProvider);
    final saveLabel = l10n.commonSave;
    final targetName = _target?['name']?.toString();
    final fromOptions = _optionsWithCurrent(_fromUnits, _fromUnit);
    final toOptions = _optionsWithCurrent(_toUnits, _toUnit);
    final preview =
        '${_fromQty.text.trim()} ${_fromUnit ?? '—'} ${widget.entityName ?? '—'}'
        ' = ${_toQty.text.trim()} ${_toUnit ?? '—'} ${targetName ?? '—'}';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.entityLinksEdit : l10n.entityLinksAddTitle),
        actions: [
          ...saveAppBarActions(
            position: savePosition,
            onSave: _saving ? null : _save,
            label: saveLabel,
            busy: _saving,
          ),
        ],
      ),
      bottomNavigationBar: saveBottomBar(
        context: context,
        position: savePosition,
        onSave: _saving ? null : _save,
        label: saveLabel,
        busy: _saving,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.entityType == 'ingredient' &&
              _targetType == 'ingredient') ...[
            Container(
              key: const ValueKey('entity-links-ingredient-hint'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.entityLinksIngredientHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _SectionLabel(text: l10n.entityLinksCurrent),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              widget.entityType == 'product'
                  ? Icons.inventory_2_outlined
                  : Icons.grass_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(widget.entityName ?? '—'),
            subtitle: Text(
              widget.entityType == 'product'
                  ? l10n.entityLinksProduct
                  : l10n.entityLinksIngredient,
            ),
          ),
          const Divider(height: 24),
          _SectionLabel(text: l10n.entityLinksToSection),
          DropdownButtonFormField<String>(
            key: ValueKey('target-type-$_targetType'),
            initialValue: _targetType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ).copyWith(labelText: l10n.entityLinksTargetType),
            items: [
              DropdownMenuItem(
                value: 'product',
                child: Text(l10n.entityLinksProduct),
              ),
              DropdownMenuItem(
                value: 'ingredient',
                child: Text(l10n.entityLinksIngredient),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null || value == _targetType) return;
                    setState(() {
                      _targetType = value;
                      _target = null;
                      _toUnits = const [];
                      _toUnit = null;
                    });
                  },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickTarget,
            icon: const Icon(Icons.search),
            label: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                targetName ?? l10n.entityLinksTargetPlaceholder,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              alignment: AlignmentDirectional.centerStart,
            ),
          ),
          const Divider(height: 28),
          _SectionLabel(text: l10n.entityLinksConversionSection),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _fromQty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.entityLinksQuantity,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _UnitDropdown(
                  value: _fromUnit,
                  options: fromOptions,
                  loading: _loadingFromUnits,
                  emptyHint: l10n.entityLinksUnitsEmpty,
                  label: l10n.entityLinksUnit,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _fromUnit = value),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Icon(Icons.drag_handle, size: 20),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _toQty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.entityLinksQuantity,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _UnitDropdown(
                  value: _toUnit,
                  options: toOptions,
                  loading: _loadingToUnits,
                  emptyHint: targetName == null
                      ? l10n.entityLinksSelectTargetFirst
                      : l10n.entityLinksUnitsEmpty,
                  label: l10n.entityLinksUnit,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _toUnit = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${l10n.entityLinksPreview}: $preview',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: l10n.entityLinksNote,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _UnitDropdown extends StatelessWidget {
  final String? value;
  final List<String> options;
  final bool loading;
  final String emptyHint;
  final String label;
  final ValueChanged<String?>? onChanged;

  const _UnitDropdown({
    required this.value,
    required this.options,
    required this.loading,
    required this.emptyHint,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const InputDecorator(
        decoration: InputDecoration(border: OutlineInputBorder()),
        child: SizedBox(
          height: 20,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (options.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: emptyHint,
        ),
        child: const SizedBox(height: 20),
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-${value ?? ''}-${options.join('|')}'),
      initialValue: value != null && options.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final unit in options)
          DropdownMenuItem(value: unit, child: Text(unit)),
      ],
      onChanged: onChanged,
    );
  }
}

class _TargetPickerSheet extends StatefulWidget {
  final EntityRepository repository;
  final String initialType;
  final AppLocalizations l10n;

  const _TargetPickerSheet({
    required this.repository,
    required this.initialType,
    required this.l10n,
  });

  @override
  State<_TargetPickerSheet> createState() => _TargetPickerSheetState();
}

class _TargetPickerSheetState extends State<_TargetPickerSheet> {
  final _search = TextEditingController();
  late String _type;
  Timer? _debounce;
  int _seq = 0;
  List<Map<String, dynamic>> _options = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(value.trim());
    });
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_seq;
    setState(() => _loading = true);
    try {
      final rows = await widget.repository.searchQuantityLinkTargets(
        _type,
        query,
      );
      if (!mounted || seq != _seq) return;
      setState(() {
        _options = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _options = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final height = MediaQuery.sizeOf(context).height * 0.78;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.entityLinksToSection,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'product',
                    label: Text(l10n.entityLinksProduct),
                  ),
                  ButtonSegment(
                    value: 'ingredient',
                    label: Text(l10n.entityLinksIngredient),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (values) {
                  final next = values.first;
                  if (next == _type) return;
                  setState(() {
                    _type = next;
                    _options = const [];
                  });
                  _runSearch(_search.text.trim());
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.entityLinksSearch,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onSearch,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _options.isEmpty
                      ? Center(child: Text(l10n.entityLinksEmpty))
                      : ListView.separated(
                          itemCount: _options.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final row = _options[index];
                            final subtitle = row['ingredient_name']?.toString();
                            return ListTile(
                              leading: Icon(
                                _type == 'product'
                                    ? Icons.inventory_2_outlined
                                    : Icons.grass_outlined,
                              ),
                              title: Text(row['name']?.toString() ?? '—'),
                              subtitle: subtitle == null || subtitle.isEmpty
                                  ? null
                                  : Text(subtitle),
                              onTap: () => Navigator.of(context).pop({
                                ...row,
                                'type': _type,
                              }),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

double? _parseNumber(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  const extendedArabicIndic = '۰۱۲۳۴۵۶۷۸۹';
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final arabicIndex = arabicIndic.indexOf(char);
    if (arabicIndex >= 0) {
      buffer.write(arabicIndex);
      continue;
    }
    final extendedIndex = extendedArabicIndic.indexOf(char);
    if (extendedIndex >= 0) {
      buffer.write(extendedIndex);
      continue;
    }
    if (char == ',' || char == '\u066C' || char == '\u00A0' || char == ' ') {
      continue;
    }
    if (char == '\u066B' || char == '٫') {
      buffer.write('.');
      continue;
    }
    buffer.write(char);
  }
  return double.tryParse(buffer.toString());
}
