import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../core/api/api_client.dart';
import '../providers/startup_page_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info card：点击进入编辑页，显示昵称与头像
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/profile/account'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  CircleAvatar(
                    radius: 32,
                    foregroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    onForegroundImageError:
                        user?.avatarUrl == null ? null : (_, __) {},
                    child: Text(
                        user?.displayName.isNotEmpty == true
                            ? user!.displayName[0]
                            : '?',
                        style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(user?.displayName ?? '用户',
                            style: theme.textTheme.titleLarge),
                        Text(user?.email ?? '',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ])),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Settings section
          Text('设置',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          Card(
              child: Column(children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('启动时起始页'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(startupPageDisplayName(ref.watch(startupPageProvider))),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ]),
              onTap: () => _showStartupPageDialog(context, ref),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: const Text('默认币种'),
              subtitle: Text(user?.defaultCurrency ?? '跟随所在地区'),
              onTap: () => _showDefaultCurrencyDialog(context, ref),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('默认计算范围'),
              subtitle: Text(_calcScopeDisplayName(user?.defaultCalcScope)),
              onTap: () => _showDefaultCalcScopeDialog(context, ref),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.scale),
              title: const Text('单位偏好'),
              onTap: () => context.push('/profile/settings/unit-preferences'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text('营养目标'),
              onTap: () => context.push('/profile/settings/nutrition-goals'),
            ),
          ])),
          const SizedBox(height: 24),

          // My data section
          Text('我的数据',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          Card(
              child: Column(children: [
            ListTile(
                leading: const Icon(Icons.rate_review_outlined),
                title: const Text('我的提议'),
                onTap: () => context.push('/profile/proposals')),
            const Divider(height: 1),
            ListTile(
                leading: const Icon(Icons.place_outlined),
                title: const Text('我的地点'),
                onTap: () => context.push('/profile/places')),
          ])),
          const SizedBox(height: 32),

          // Logout
          SafeArea(
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('退出登录'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// 启动时起始页单选对话框：点选即生效并关闭。
Future<void> _showStartupPageDialog(BuildContext context, WidgetRef ref) async {
  final current = ref.read(startupPageProvider);
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('启动时起始页'),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final page in kStartupPages)
                RadioListTile<String>(
                  value: page,
                  title: Text(startupPageDisplayName(page)),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (selected != null && selected != current) {
    await ref.read(startupPageProvider.notifier).setPage(selected);
  }
}

String _calcScopeDisplayName(String? scope) {
  switch (scope) {
    case 'country':
      return '国家/地区';
    case 'province':
      return '省份';
    case 'city':
      return '城市';
    case 'county':
      return '区县';
    case '':
      return '全部地区';
    default:
      return '国家/地区';
  }
}

const List<Map<String, String>> _fallbackCurrencies = [
  {'code': 'CNY', 'symbol': '¥', 'name': '人民币'},
  {'code': 'USD', 'symbol': r'$', 'name': '美元'},
  {'code': 'EUR', 'symbol': '€', 'name': '欧元'},
  {'code': 'GBP', 'symbol': '£', 'name': '英镑'},
  {'code': 'JPY', 'symbol': '¥', 'name': '日元'},
  {'code': 'HKD', 'symbol': 'HK\$', 'name': '港币'},
  {'code': 'KRW', 'symbol': '₩', 'name': '韩元'},
  {'code': 'SGD', 'symbol': 'S\$', 'name': '新加坡元'},
  {'code': 'AUD', 'symbol': 'A\$', 'name': '澳大利亚元'},
  {'code': 'CAD', 'symbol': 'C\$', 'name': '加拿大元'},
  {'code': 'TWD', 'symbol': 'NT\$', 'name': '新台币'},
  {'code': 'THB', 'symbol': '฿', 'name': '泰铢'},
  {'code': 'MYR', 'symbol': 'RM', 'name': '马来西亚林吉特'},
  {'code': 'VND', 'symbol': '₫', 'name': '越南盾'},
  {'code': 'RUB', 'symbol': '₽', 'name': '俄罗斯卢布'},
  {'code': 'AED', 'symbol': 'د.إ', 'name': '阿联酋迪拉姆'},
  {'code': 'BGN', 'symbol': 'лв', 'name': '保加利亚列弗'},
  {'code': 'BRL', 'symbol': 'R\$', 'name': '巴西雷亚尔'},
  {'code': 'CHF', 'symbol': 'CHF', 'name': '瑞士法郎'},
  {'code': 'CZK', 'symbol': 'Kč', 'name': '捷克克朗'},
  {'code': 'DKK', 'symbol': 'kr', 'name': '丹麦克朗'},
  {'code': 'HUF', 'symbol': 'Ft', 'name': '匈牙利福林'},
  {'code': 'IDR', 'symbol': 'Rp', 'name': '印度尼西亚盾'},
  {'code': 'ILS', 'symbol': '₪', 'name': '以色列新谢克尔'},
  {'code': 'INR', 'symbol': '₹', 'name': '印度卢比'},
  {'code': 'ISK', 'symbol': 'kr', 'name': '冰岛克朗'},
  {'code': 'MXN', 'symbol': 'Mex\$', 'name': '墨西哥比索'},
  {'code': 'NOK', 'symbol': 'kr', 'name': '挪威克朗'},
  {'code': 'NZD', 'symbol': 'NZ\$', 'name': '新西兰元'},
  {'code': 'PHP', 'symbol': '₱', 'name': '菲律宾比索'},
  {'code': 'PLN', 'symbol': 'zł', 'name': '波兰兹罗提'},
  {'code': 'RON', 'symbol': 'lei', 'name': '罗马尼亚列伊'},
  {'code': 'SEK', 'symbol': 'kr', 'name': '瑞典克朗'},
  {'code': 'TRY', 'symbol': '₺', 'name': '土耳其里拉'},
  {'code': 'ZAR', 'symbol': 'R', 'name': '南非兰特'},
];

Future<List<Map<String, dynamic>>> _fetchCurrencies() async {
  try {
    final response = await ApiClient.instance.dio.get('/currencies');
    final data = response.data;
    final list = (data is List)
        ? data
        : ((data is Map ? data['items'] as List? : null) ?? const []);
    return [
      for (final item in list)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  } catch (_) {
    return const [];
  }
}

Future<void> _showDefaultCurrencyDialog(
    BuildContext context, WidgetRef ref) async {
  final current = ref.read(authProvider).user?.defaultCurrency;
  final fetched = await _fetchCurrencies();
  if (!context.mounted) return;
  final currencies = fetched.isNotEmpty
      ? fetched
      : <Map<String, dynamic>>[
          for (final c in _fallbackCurrencies) Map<String, dynamic>.from(c),
        ];
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('默认币种'),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in currencies)
                RadioListTile<String>(
                  value: c['code'] as String? ?? '',
                  title: Text('${c['name']} ${c['code']}'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (selected == null || selected == current) return;
  if (!context.mounted) return;
  await _saveLocaleSettings(
    context,
    ref,
    defaultCurrency: selected,
  );
}

Future<void> _showDefaultCalcScopeDialog(
    BuildContext context, WidgetRef ref) async {
  final current = ref.read(authProvider).user?.defaultCalcScope ?? 'country';
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('默认计算范围'),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(value: '', title: Text('全部地区')),
              RadioListTile<String>(value: 'country', title: Text('国家/地区')),
              RadioListTile<String>(value: 'province', title: Text('省份')),
              RadioListTile<String>(value: 'city', title: Text('城市')),
              RadioListTile<String>(value: 'county', title: Text('区县')),
            ],
          ),
        ),
      ],
    ),
  );
  if (selected == null || selected == current) return;
  if (!context.mounted) return;
  await _saveLocaleSettings(context, ref, defaultCalcScope: selected);
}

Future<void> _saveLocaleSettings(
  BuildContext context,
  WidgetRef ref, {
  String? defaultCurrency,
  String? defaultCalcScope,
}) async {
  try {
    final user = await AuthRepository().updateSettings(
      defaultCurrency: defaultCurrency,
      defaultCalcScope: defaultCalcScope,
    );
    ref.read(authProvider.notifier).applyUser(user);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    }
  } on DioException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractDetail(e))),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请重试')),
      );
    }
  }
}

String _extractDetail(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['detail'] is String) {
    return data['detail'] as String;
  }
  return '保存失败，请检查后重试';
}

