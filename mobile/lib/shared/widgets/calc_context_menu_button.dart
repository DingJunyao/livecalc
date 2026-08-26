import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/repositories/auth_repository.dart';
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
          initialRegionId: user?.regionId,
          initialScope: user?.defaultCalcScope ?? 'country',
          initialCurrency: user?.defaultCurrency,
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
    final user = ref.read(authProvider).user;
    setState(() => _saving = true);
    try {
      final repo = AuthRepository();
      if (_scope != user?.defaultCalcScope ||
          _currency != user?.defaultCurrency) {
        final body = <String, dynamic>{};
        if (_scope != user?.defaultCalcScope) {
          body['default_calc_scope'] = _scope;
        }
        if (_currency != user?.defaultCurrency) {
          // 空串 = 清除默认币种，跟随所在地区
          body['default_currency'] = (_currency == null || _currency!.isEmpty)
              ? null
              : _currency;
        }
        await repo.updateMe(body);
      }
      if (_regionId != user?.regionId) {
        await repo.updateAccount({'region_id': _regionId});
      }
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractDetail(e))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _extractDetail(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    return '保存失败，请检查后重试';
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
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中...' : '保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}