import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/merchants/repositories/merchant_repository.dart';

/// Four-level cascading region selector (country/region -> province -> city -> district).
class RegionSelectField extends ConsumerStatefulWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final MerchantRepository? repository;

  const RegionSelectField({
    super.key,
    required this.value,
    required this.onChanged,
    this.repository,
  });

  @override
  ConsumerState<RegionSelectField> createState() => _RegionSelectFieldState();
}

class _RegionSelectFieldState extends ConsumerState<RegionSelectField> {
  static const _levels = [
    ('国家/地区', 0),
    ('省份', 1),
    ('城市', 2),
    ('区县', 3),
  ];

  late final List<List<Map<String, dynamic>>> _options;
  late final List<int?> _sel;
  late final MerchantRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MerchantRepository();
    _options = List.generate(_levels.length, (_) => const <Map<String, dynamic>>[]);
    _sel = List<int?>.filled(_levels.length, null);
    _init();
  }

  @override
  void didUpdateWidget(covariant RegionSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = widget.value;
    if (v != null && v != oldWidget.value && v != _current) {
      _applyValue(v);
    }
  }

  /// 已存 region_id 回填级联（含只填国家/地区）：GET /regions/{id} 返回祖先链。
  Future<void> _init() async {
    await _load(0, null);
    final v = widget.value;
    if (v != null && mounted) {
      await _applyValue(v);
    }
  }

  Future<void> _applyValue(int v) async {
    final Map<String, dynamic> detail;
    try {
      detail = await _repo.getRegion(v);
    } catch (_) {
      return;
    }
    if (!mounted || widget.value != v) return;

    final rawAncestors = (detail['ancestors'] as List?) ?? const [];
    final chain = <Map<String, dynamic>>[
      for (final a in rawAncestors)
        if (a is Map)
          {
            'id': (a['id'] as num?)?.toInt(),
            'level': (a['level'] as num?)?.toInt() ?? 0,
          },
      {'id': v, 'level': (detail['level'] as num?)?.toInt() ?? 0},
    ]..sort((a, b) =>
        ((a['level'] as int?) ?? 0).compareTo((b['level'] as int?) ?? 0));

    for (var i = 0; i < chain.length; i++) {
      final item = chain[i];
      final itemId = item['id'] as int?;
      final itemLevel = item['level'] as int?;
      if (itemId == null ||
          itemLevel == null ||
          itemLevel < 0 ||
          itemLevel >= _levels.length) {
        continue;
      }
      if (i < chain.length - 1) {
        final nextLevel = chain[i + 1]['level'] as int?;
        if (nextLevel != null && nextLevel < _levels.length) {
          await _load(nextLevel, itemId);
          if (!mounted || widget.value != v) return;
        }
      }
      setState(() => _sel[itemLevel] = itemId);
    }
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
      _options[level] = _normalize(rows);
      _sel[level] = null;
      for (var i = level + 1; i < _levels.length; i++) {
        _sel[i] = null;
        _options[i] = const <Map<String, dynamic>>[];
      }
    });
  }

  List<Map<String, dynamic>> _normalize(List<Map<String, dynamic>> rows) {
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      if (id == null) continue;
      result.add({'id': id, 'name': row['name']?.toString() ?? ''});
    }
    return result;
  }

  int? get _current {
    for (var i = _levels.length - 1; i >= 0; i--) {
      if (_sel[i] != null) return _sel[i];
    }
    return null;
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
    widget.onChanged(_current);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _levels.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            key: ValueKey('region_${_levels[i].$2}_$_sel[i]'),
            initialValue: _sel[i],
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('请选择')),
              for (final option in _options[i])
                DropdownMenuItem<int?>(
                  value: option['id'] as int,
                  child: Text(option['name'] as String),
                ),
            ],
            decoration: InputDecoration(
              labelText: _levels[i].$1,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => _select(i, value),
          ),
        ],
      ],
    );
  }
}