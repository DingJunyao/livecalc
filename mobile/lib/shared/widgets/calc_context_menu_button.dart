import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../providers/calc_context_provider.dart';
import 'region_select_field.dart';

/// 导航栏右侧「地区 / 计算范围 / 币种」快捷切换按钮（移动端单个按钮，点击弹窗修改）。
class CalcContextMenuButton extends ConsumerWidget {
  const CalcContextMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.public),
      tooltip: l10n.calcContextTooltip,
      onPressed: () => _showSheet(context, ref),
    );
  }

  Future<void> _showSheet(BuildContext context, WidgetRef ref) async {
    final ctx = ref.read(calcContextProvider);
    final user = ref.read(authProvider).user;
    final media = MediaQuery.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.86,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: CalcContextSheet(
          initialRegionId: ctx.regionId ?? user?.regionId,
          initialScope: ctx.scope ?? user?.defaultCalcScope ?? 'country',
          initialCurrency: ctx.currency ?? user?.defaultCurrency,
        ),
      ),
    );
  }
}

const _scopeOptions = ['', 'country', 'province', 'city', 'county'];

const _fallbackCurrencies = [
  {'code': 'CNY'},
  {'code': 'USD'},
  {'code': 'EUR'},
  {'code': 'JPY'},
  {'code': 'GBP'},
  {'code': 'HKD'},
  {'code': 'KRW'},
  {'code': 'SGD'},
];

class CalcContextSheet extends ConsumerStatefulWidget {
  final int? initialRegionId;
  final String initialScope;
  final String? initialCurrency;

  const CalcContextSheet({
    super.key,
    this.initialRegionId,
    required this.initialScope,
    this.initialCurrency,
  });

  @override
  ConsumerState<CalcContextSheet> createState() => _CalcContextSheetState();
}

class _CalcContextSheetState extends ConsumerState<CalcContextSheet> {
  late int? _regionId;
  late String _scope;
  late String? _currency;
  List<Map<String, dynamic>> _currencies = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _regionId = widget.initialRegionId;
    _scope = widget.initialScope;
    _currency = widget.initialCurrency;
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    try {
      final resp = await ApiClient.instance.dio.get('/currencies');
      final data = resp.data;
      final list = (data is List)
          ? data
          : ((data is Map) ? (data['items'] as List?) : null) ?? const [];
      if (!mounted) return;
      setState(() => _currencies = [
            for (final item in list)
              if (item is Map) Map<String, dynamic>.from(item),
          ]);
    } catch (_) {
      if (mounted) {
        setState(() => _currencies = [
              for (final c in _fallbackCurrencies) Map<String, dynamic>.from(c),
            ]);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // 会话级临时覆盖：仅当前会话有效，不修改用户配置
      await ref.read(calcContextProvider.notifier).apply(
            regionId: _regionId,
            scope: _scope,
            currency: _currency,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).calcAppliedForSession),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).calcApplyFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    ref.read(calcContextProvider.notifier).clear();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final selectedCurrency = _currency ?? '';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(l10n.calcContextTitle,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(l10n.authRegion, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              RegionSelectField(
                value: _regionId,
                onChanged: (v) => setState(() => _regionId = v),
              ),
              const SizedBox(height: 16),
              Text(l10n.profileDefaultCalcScope,
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _scope,
                items: [
                  for (final value in _scopeOptions)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_scopeLabel(value, l10n)),
                    ),
                ],
                decoration: _inputDecoration,
                menuMaxHeight: 320,
                onChanged: (value) =>
                    setState(() => _scope = value ?? 'country'),
              ),
              const SizedBox(height: 16),
              Text(l10n.profileDefaultCurrency,
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: selectedCurrency,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(l10n.profileFollowRegion),
                  ),
                  for (final c in _currencies)
                    DropdownMenuItem(
                      value: c['code'] as String? ?? '',
                      child: Text(
                        _currencyLabel(c),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                decoration: _inputDecoration,
                menuMaxHeight: 360,
                onChanged: (value) => setState(
                  () => _currency =
                      (value == null || value.isEmpty) ? null : value,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : _reset,
                    child: Text(l10n.calcResetToPersonal),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(
                          _saving ? l10n.commonApplying : l10n.commonApply),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration get _inputDecoration => InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  String _scopeLabel(String scope, AppLocalizations l10n) {
    return switch (scope) {
      '' => l10n.profileCalcScopeAll,
      'country' => l10n.profileCalcScopeCountry,
      'province' => l10n.profileCalcScopeProvince,
      'city' => l10n.profileCalcScopeCity,
      _ => l10n.profileCalcScopeCounty,
    };
  }

  String _currencyName(Map<String, dynamic> currency) {
    final displayName = currency['display_name']?.toString();
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName;
    }
    final name = currency['name']?.toString();
    if (name != null && name.trim().isNotEmpty) return name;
    return currency['code']?.toString() ?? '';
  }

  String _currencyLabel(Map<String, dynamic> currency) {
    final code = currency['code']?.toString() ?? '';
    final name = _currencyName(currency);
    return name == code ? code : '$name $code';
  }
}
