import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/merchants/repositories/merchant_repository.dart';

/// Four-level cascading region selector (country/region -> province -> city -> district).
class RegionSelectField extends ConsumerStatefulWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const RegionSelectField({
    super.key,
    required this.value,
    required this.onChanged,
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
  final MerchantRepository _repo = MerchantRepository();

  @override
  void initState() {
    super.initState();
    _options = List.generate(_levels.length, (_) => const <Map<String, dynamic>>[]);
    _sel = List<int?>.filled(_levels.length, null);
    _load(0, null);
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
        for (var i = 0; i < _levels.length; i++)
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
    );
  }
}