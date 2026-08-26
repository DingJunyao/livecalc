import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../providers/calc_context_provider.dart';
import 'region_select_field.dart';

/// 导航栏右侧「地区 / 计算范围 / 币种」快捷切换按钮（移动端单个按钮，点击弹窗修改）。
class CalcContextMenuButton extends ConsumerWidget {
  const CalcContextMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.public),
      tooltip: '地区/计算范围/币种',
      onPressed: () => _showSheet(context, ref),
    );
  }

  Future<void> _showSheet(BuildContext context, WidgetRef ref) async {
    final ctx = ref.read(calcContextProvider);
    final user = ref.read(authProvider).user;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CalcContextSheet(
          initialRegionId: ctx.regionId ?? user?.regionId,
          initialScope: ctx.scope ?? user?.defaultCalcScope ?? 'country',
          initialCurrency: ctx.currency ?? user?.defaultCurrency,
        ),
      ),
    );
  }
}

const _scopeOptions = [
  ('', '全部地区'),
  ('country', '国家/地区'),
  ('province', '省份'),
  ('city', '城市'),
  ('county', '区县'),
];

const _fallbackCurrencies = [
  {'code': 'CNY', 'name': '人民币'},
  {'code': 'USD', 'name': '美元'},
  {'code': 'EUR', 'name': '欧元'},
  {'code': 'JPY', 'name': '日元'},
  {'code': 'GBP', 'name': '英镑'},
  {'code': 'HKD', 'name': '港币'},
  {'code': 'KRW', 'name': '韩元'},
  {'code': 'SGD', 'name': '新加坡元'},
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
              for (final c in _fallbackCurrencies)
                Map<String, dynamic>.from(c),
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
          const SnackBar(content: Text('已应用（当前会话生效）')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('应用失败，请重试')),
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
                  Text('地区 / 计算范围 / 币种',
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
              Text('所在地区', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              RegionSelectField(
                value: _regionId,
                onChanged: (v) => setState(() => _regionId = v),
              ),
              const SizedBox(height: 16),
              Text('计算范围', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              RadioGroup<String>(
                groupValue: _scope,
                onChanged: (v) => setState(() => _scope = v ?? 'country'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (value, label) in _scopeOptions)
                      RadioListTile<String>(
                        value: value,
                        title: Text(label),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('币种', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              RadioGroup<String>(
                groupValue: selectedCurrency,
                onChanged: (v) => setState(() => _currency =
                    (v == null || v.isEmpty) ? null : v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RadioListTile<String>(
                      value: '',
                      title: Text('跟随所在地区'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    for (final c in _currencies)
                      RadioListTile<String>(
                        value: c['code'] as String? ?? '',
                        title: Text('${c['name']} ${c['code']}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : _reset,
                    child: const Text('重置为个人配置'),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? '应用中...' : '应用'),
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
}