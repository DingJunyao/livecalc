import 'package:flutter/material.dart';
import '../../../features/merchants/repositories/merchant_repository.dart';
import '../../../l10n/app_localizations.dart';

/// 多地区选择组件：四级级联浏览 + 逐个「添加」+ 已选 chips（可删除）。
/// 层级可混合（如一个县 + 一个地级市）；chip 文案带祖先前缀（河南 / 三门峡市）。
class RegionMultiSelectField extends StatefulWidget {
  /// 已选地区 id 列表。
  final List<int> value;
  final ValueChanged<List<int>> onChanged;
  final MerchantRepository? repository;

  const RegionMultiSelectField({
    super.key,
    required this.value,
    required this.onChanged,
    this.repository,
  });

  @override
  State<RegionMultiSelectField> createState() => _RegionMultiSelectFieldState();
}

class _RegionMultiSelectFieldState extends State<RegionMultiSelectField> {
  static const _levels = [0, 1, 2, 3];

  late final MerchantRepository _repo;
  final List<List<Map<String, dynamic>>> _options = [];
  final List<int?> _sel = List<int?>.filled(_levels.length, null);

  /// id -> 展示文案（含祖先前缀）。新增时用级联选项拼，编辑回填时经详情接口拼。
  final Map<int, String> _labels = {};

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MerchantRepository();
    for (var i = 0; i < _levels.length; i++) {
      _options.add(const <Map<String, dynamic>>[]);
    }
    _load(0, null);
    _syncLabels(widget.value);
  }

  @override
  void didUpdateWidget(covariant RegionMultiSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _syncLabels(widget.value);
    }
  }

  /// 编辑模式回填：对缺失文案的 id 拉详情（ancestors 链）拼前缀。
  Future<void> _syncLabels(List<int> ids) async {
    var changed = false;
    for (final id in ids) {
      if (_labels.containsKey(id)) continue;
      try {
        final detail = await _repo.getRegion(id);
        final buf = <String>[];
        final ancestors = (detail['ancestors'] as List?) ?? const [];
        for (final a in ancestors) {
          if (a is Map) {
            final name = (a['display_name'] ?? a['name'])?.toString() ?? '';
            if (name.isNotEmpty) buf.add(name);
          }
        }
        final selfName =
            (detail['display_name'] ?? detail['name'])?.toString() ?? '';
        _labels[id] = [...buf, if (selfName.isNotEmpty) selfName].join(' / ');
        changed = true;
      } catch (_) {
        _labels[id] = '$id';
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _load(int level, int? parentId) async {
    final List<Map<String, dynamic>> rows;
    try {
      rows = await _repo.listRegions(
        parentId: parentId,
        level: (parentId == null && level == 0) ? 0 : null,
      );
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _options[level] = [
        for (final row in rows)
          if ((row['id'] as num?)?.toInt() case final id?)
            {
              'id': id,
              'label': (row['display_name'] ?? row['name'])?.toString() ?? '',
            },
      ];
      _sel[level] = null;
      for (var i = level + 1; i < _levels.length; i++) {
        _sel[i] = null;
        _options[i] = const <Map<String, dynamic>>[];
      }
    });
  }

  void _select(int level, int? value) {
    setState(() {
      _sel[level] = value;
      for (var i = level + 1; i < _levels.length; i++) {
        _sel[i] = null;
        _options[i] = const <Map<String, dynamic>>[];
      }
    });
    if (value != null && level < _levels.length - 1) {
      _load(level + 1, value);
    }
  }

  /// 当前级联最深选中的地区（即「添加」按钮的目标）。
  int? get _current {
    for (var i = _levels.length - 1; i >= 0; i--) {
      if (_sel[i] != null) return _sel[i];
    }
    return null;
  }

  void _addCurrent() {
    final id = _current;
    if (id == null || widget.value.contains(id)) return;
    // 用当前级联选项名拼祖先前缀（遇到空档即停）
    final buf = <String>[];
    for (var i = 0; i < _levels.length; i++) {
      final sid = _sel[i];
      if (sid == null) break;
      final opt = _options[i].where((o) => o['id'] == sid).firstOrNull;
      final label = opt?['label']?.toString() ?? '';
      if (label.isEmpty) break;
      buf.add(label);
      if (sid == id) break;
    }
    _labels[id] = buf.isEmpty ? '$id' : buf.join(' / ');
    widget.onChanged([...widget.value, id]);
  }

  void _remove(int id) {
    widget.onChanged(widget.value.where((x) => x != id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = _current;
    final alreadyAdded = current != null && widget.value.contains(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _levels.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            key: ValueKey('multi_region_${i}_${_sel[i]}'),
            initialValue: _sel[i],
            isExpanded: true,
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(l10n.regionSelect),
              ),
              for (final option in _options[i])
                DropdownMenuItem<int?>(
                  value: option['id'] as int,
                  child: Text(option['label'] as String? ?? ''),
                ),
            ],
            decoration: InputDecoration(
              labelText: _regionLabel(i, l10n),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => _select(i, value),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: current == null || alreadyAdded ? null : _addCurrent,
              icon: const Icon(Icons.add),
              label: Text(l10n.calcScopeAddRegion),
            ),
            if (alreadyAdded) ...[
              const SizedBox(width: 8),
              Text(l10n.calcScopeRegionAdded,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (widget.value.isEmpty)
          Text(l10n.calcScopeNoRegion,
              style: Theme.of(context).textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final id in widget.value)
                InputChip(
                  label: Text(
                    _labels[id] ?? '$id',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: () => _remove(id),
                ),
            ],
          ),
      ],
    );
  }

  String _regionLabel(int level, AppLocalizations l10n) {
    return switch (level) {
      0 => l10n.regionCountry,
      1 => l10n.regionProvince,
      2 => l10n.regionCity,
      _ => l10n.regionCounty,
    };
  }
}
