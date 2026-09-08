import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/repositories/auth_repository.dart';
import '../models/unit_option.dart';
import '../repositories/profile_repository.dart';
import '../../../l10n/app_localizations.dart';

/// 单位偏好：能量/质量/容积/记价 4 个下拉，保存 PATCH /auth/me 只传变化字段。
class UnitPreferencesScreen extends ConsumerStatefulWidget {
  /// 可注入以便测试；生产用默认实现。
  final ProfileRepository? repository;
  final AuthRepository? authRepository;

  const UnitPreferencesScreen(
      {super.key, this.repository, this.authRepository});

  @override
  ConsumerState<UnitPreferencesScreen> createState() =>
      _UnitPreferencesScreenState();
}

class _UnitPreferencesScreenState extends ConsumerState<UnitPreferencesScreen> {
  late final ProfileRepository _repo;
  List<UnitOption> _units = [];
  bool _loading = true;
  String? _loadError;
  bool _saving = false;

  String? _energyUnit; // kcal | kJ | null=不设置
  int? _massUnitId;
  int? _volumeUnitId;
  int? _priceUnitId;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ProfileRepository();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final units = await _repo.getUnits();
      if (!mounted) return;
      final prefs = ref.read(authProvider).user?.unitPreferences;
      setState(() {
        _units = units;
        _energyUnit = prefs?.energyUnit;
        _massUnitId = _validId(prefs?.massUnit?.id, units, 'mass');
        _volumeUnitId = _validId(prefs?.volumeUnit?.id, units, 'volume');
        _priceUnitId = _validId(prefs?.priceUnit?.id, units, null);
      });
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() => _loadError = l10n.unitPreferencesLoadFailed);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 初值不在选项列表中（单位已删除）时置空，保存时视为「清除」。
  int? _validId(int? id, List<UnitOption> units, String? unitType) {
    if (id == null) return null;
    final ok = units.any((u) =>
        u.id == id &&
        (unitType == null ||
            u.unitType == unitType ||
            (unitType == 'price' &&
                const ['mass', 'volume', 'count'].contains(u.unitType))));
    return ok ? id : null;
  }

  List<UnitOption> _options(String? unitType) {
    return _units.where((u) {
      if (unitType == null) {
        return const ['mass', 'volume', 'count'].contains(u.unitType);
      }
      return u.unitType == unitType;
    }).toList();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.read(authProvider).user?.unitPreferences;
    final body = <String, dynamic>{};
    if (_energyUnit != prefs?.energyUnit) {
      body['default_energy_unit'] = _energyUnit;
    }
    if (_massUnitId != prefs?.massUnit?.id) {
      body['default_mass_unit_id'] = _massUnitId;
    }
    if (_volumeUnitId != prefs?.volumeUnit?.id) {
      body['default_volume_unit_id'] = _volumeUnitId;
    }
    if (_priceUnitId != prefs?.priceUnit?.id) {
      body['default_price_unit_id'] = _priceUnitId;
    }
    if (body.isEmpty) {
      _toast(l10n.authNoChangesToSave);
      return;
    }

    setState(() => _saving = true);
    try {
      final user =
          await (widget.authRepository ?? AuthRepository()).updateMe(body);
      ref.read(authProvider.notifier).applyUser(user);
      if (mounted) {
        _toast(l10n.authSaved);
        context.pop();
      }
    } on DioException catch (e) {
      if (mounted) _toast(_extractDetail(e, l10n));
    } catch (_) {
      if (mounted) _toast(l10n.authSaveFailedRetry);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _extractDetail(DioException e, AppLocalizations l10n) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    return l10n.authSaveFailedCheckInput;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileUnitPreferences)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_loadError!),
                      const SizedBox(height: 8),
                      OutlinedButton(
                          onPressed: _loadUnits, child: Text(l10n.commonRetry)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      l10n.unitPreferencesDescription,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    const SizedBox(height: 16),
                    _unitDropdown(
                      label: l10n.unitPreferencesEnergyUnit,
                      hint: l10n.unitPreferencesKilocalories,
                      value: _energyUnit,
                      noneLabel: l10n.unitPreferencesNone,
                      items: [
                        DropdownMenuItem(
                            value: 'kcal',
                            child: Text(l10n.unitPreferencesKilocalories)),
                        DropdownMenuItem(
                            value: 'kJ',
                            child: Text(l10n.unitPreferencesKilojoules)),
                      ],
                      onChanged: (v) => setState(() => _energyUnit = v),
                    ),
                    _unitDropdown(
                      label: l10n.unitPreferencesMassUnit,
                      hint: l10n.unitPreferencesMassHint,
                      value: _massUnitId,
                      noneLabel: l10n.unitPreferencesNone,
                      items:
                          _options('mass').map((u) => _item(u, l10n)).toList(),
                      onChanged: (v) => setState(() => _massUnitId = v),
                    ),
                    _unitDropdown(
                      label: l10n.unitPreferencesVolumeUnit,
                      hint: l10n.unitPreferencesVolumeHint,
                      value: _volumeUnitId,
                      noneLabel: l10n.unitPreferencesNone,
                      items: _options('volume')
                          .map((u) => _item(u, l10n))
                          .toList(),
                      onChanged: (v) => setState(() => _volumeUnitId = v),
                    ),
                    _unitDropdown(
                      label: l10n.unitPreferencesPriceUnit,
                      hint: l10n.unitPreferencesPriceHint,
                      value: _priceUnitId,
                      noneLabel: l10n.unitPreferencesNone,
                      items: _options(null).map((u) => _item(u, l10n)).toList(),
                      onChanged: (v) => setState(() => _priceUnitId = v),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child:
                          Text(_saving ? l10n.commonSaving : l10n.commonSave),
                    ),
                  ],
                ),
    );
  }

  DropdownMenuItem<int?> _item(UnitOption u, AppLocalizations l10n) {
    // abbreviation 与 name 相同（如「个」）时不重复拼后缀
    final abbr = u.abbreviation.isNotEmpty && u.abbreviation != u.name
        ? l10n.unitPreferencesAbbreviation(u.abbreviation)
        : '';
    return DropdownMenuItem(value: u.id, child: Text('${u.name}$abbr'));
  }

  Widget _unitDropdown({
    required String label,
    required String hint,
    required dynamic value,
    required String noneLabel,
    required List<DropdownMenuItem<dynamic>> items,
    required ValueChanged<dynamic> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<dynamic>(
        key: ValueKey(label),
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        hint: Text(hint),
        items: [
          DropdownMenuItem(value: null, child: Text(noneLabel)),
          ...items,
        ],
        onChanged: onChanged,
      ),
    );
  }
}
