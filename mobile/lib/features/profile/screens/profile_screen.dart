import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/i18n/locale_settings.dart';
import '../providers/startup_page_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/directional_icons.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
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
                            : l10n.commonUserInitial,
                        style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(user?.displayName ?? l10n.profileAnonymousUser,
                            style: theme.textTheme.titleLarge),
                        Text(user?.email ?? '',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ])),
                  Icon(DirectionalIcons.forwardChevron(context),
                      color: Colors.grey),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Settings section
          Text(l10n.profileSettings,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          Card(
              child: Column(children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(l10n.profileStartupPage),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_startupPageDisplayName(
                    ref.watch(startupPageProvider), l10n)),
                Icon(DirectionalIcons.forwardChevron(context),
                    color: Colors.grey),
              ]),
              onTap: () => _showStartupPageDialog(context, ref),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: Text(l10n.profileDefaultCurrency),
              subtitle: Text(user?.defaultCurrency ?? l10n.profileFollowRegion),
              onTap: () => _showDefaultCurrencyDialog(context, ref),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.public),
              title: Text(l10n.profileDefaultCalcScope),
              subtitle:
                  Text(_calcScopeDisplayName(user?.defaultCalcScope, l10n)),
              onTap: () => _showDefaultCalcScopeDialog(context, ref),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.profileLanguage),
              trailing: Icon(DirectionalIcons.forwardChevron(context),
                  color: Colors.grey),
              onTap: () => _showLanguageDialog(context, ref),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.numbers),
              title: Text(l10n.profileRegionalFormat),
              trailing: Icon(DirectionalIcons.forwardChevron(context),
                  color: Colors.grey),
              onTap: () => _showRegionalFormatDialog(context, ref),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.scale),
              title: Text(l10n.profileUnitPreferences),
              onTap: () => context.push('/profile/settings/unit-preferences'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restaurant),
              title: Text(l10n.profileNutritionGoals),
              onTap: () => context.push('/profile/settings/nutrition-goals'),
            ),
          ])),
          const SizedBox(height: 24),

          // My data section
          Text(l10n.profileMyData,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          Card(
              child: Column(children: [
            ListTile(
                leading: const Icon(Icons.rate_review_outlined),
                title: Text(l10n.profileMyProposals),
                onTap: () => context.push('/profile/proposals')),
            const Divider(height: 1),
            ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(l10n.profileMyPlaces),
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
              label: Text(l10n.profileLogout),
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
  final l10n = AppLocalizations.of(context);
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.profileStartupPage),
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
                  title: Text(_startupPageDisplayName(page, l10n)),
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

String _startupPageDisplayName(String page, AppLocalizations l10n) {
  switch (page) {
    case 'prices':
      return l10n.profileStartupPagePrices;
    case 'recipes':
      return l10n.profileStartupPageRecipes;
    default:
      return l10n.profileStartupPageHome;
  }
}

String _calcScopeDisplayName(String? scope, AppLocalizations l10n) {
  switch (scope) {
    case '':
      return l10n.profileCalcScopeAll;
    case 'province':
      return l10n.profileCalcScopeProvince;
    case 'city':
      return l10n.profileCalcScopeCity;
    case 'county':
      return l10n.profileCalcScopeCounty;
    default:
      return l10n.profileCalcScopeCountry;
  }
}

const List<Map<String, String>> _fallbackCurrencies = [
  {'code': 'CNY', 'symbol': '¥'},
  {'code': 'USD', 'symbol': r'$'},
  {'code': 'EUR', 'symbol': '€'},
  {'code': 'GBP', 'symbol': '£'},
  {'code': 'JPY', 'symbol': '¥'},
  {'code': 'HKD', 'symbol': 'HK\$'},
  {'code': 'KRW', 'symbol': '₩'},
  {'code': 'SGD', 'symbol': 'S\$'},
  {'code': 'AUD', 'symbol': 'A\$'},
  {'code': 'CAD', 'symbol': 'C\$'},
  {'code': 'TWD', 'symbol': 'NT\$'},
  {'code': 'THB', 'symbol': '฿'},
  {'code': 'MYR', 'symbol': 'RM'},
  {'code': 'VND', 'symbol': '₫'},
  {'code': 'RUB', 'symbol': '₽'},
  {'code': 'AED', 'symbol': 'د.إ'},
  {'code': 'BGN', 'symbol': 'лв'},
  {'code': 'BRL', 'symbol': 'R\$'},
  {'code': 'CHF', 'symbol': 'CHF'},
  {'code': 'CZK', 'symbol': 'Kč'},
  {'code': 'DKK', 'symbol': 'kr'},
  {'code': 'HUF', 'symbol': 'Ft'},
  {'code': 'IDR', 'symbol': 'Rp'},
  {'code': 'ILS', 'symbol': '₪'},
  {'code': 'INR', 'symbol': '₹'},
  {'code': 'ISK', 'symbol': 'kr'},
  {'code': 'MXN', 'symbol': 'Mex\$'},
  {'code': 'NOK', 'symbol': 'kr'},
  {'code': 'NZD', 'symbol': 'NZ\$'},
  {'code': 'PHP', 'symbol': '₱'},
  {'code': 'PLN', 'symbol': 'zł'},
  {'code': 'RON', 'symbol': 'lei'},
  {'code': 'SEK', 'symbol': 'kr'},
  {'code': 'TRY', 'symbol': '₺'},
  {'code': 'ZAR', 'symbol': 'R'},
];

String _fallbackCurrencyName(String code, AppLocalizations l10n) {
  switch (code) {
    case 'USD':
      return l10n.profileCurrencyNameUSD;
    case 'EUR':
      return l10n.profileCurrencyNameEUR;
    case 'GBP':
      return l10n.profileCurrencyNameGBP;
    case 'JPY':
      return l10n.profileCurrencyNameJPY;
    case 'HKD':
      return l10n.profileCurrencyNameHKD;
    case 'KRW':
      return l10n.profileCurrencyNameKRW;
    case 'SGD':
      return l10n.profileCurrencyNameSGD;
    case 'AUD':
      return l10n.profileCurrencyNameAUD;
    case 'CAD':
      return l10n.profileCurrencyNameCAD;
    case 'TWD':
      return l10n.profileCurrencyNameTWD;
    case 'THB':
      return l10n.profileCurrencyNameTHB;
    case 'MYR':
      return l10n.profileCurrencyNameMYR;
    case 'VND':
      return l10n.profileCurrencyNameVND;
    case 'RUB':
      return l10n.profileCurrencyNameRUB;
    case 'AED':
      return l10n.profileCurrencyNameAED;
    case 'BGN':
      return l10n.profileCurrencyNameBGN;
    case 'BRL':
      return l10n.profileCurrencyNameBRL;
    case 'CHF':
      return l10n.profileCurrencyNameCHF;
    case 'CZK':
      return l10n.profileCurrencyNameCZK;
    case 'DKK':
      return l10n.profileCurrencyNameDKK;
    case 'HUF':
      return l10n.profileCurrencyNameHUF;
    case 'IDR':
      return l10n.profileCurrencyNameIDR;
    case 'ILS':
      return l10n.profileCurrencyNameILS;
    case 'INR':
      return l10n.profileCurrencyNameINR;
    case 'ISK':
      return l10n.profileCurrencyNameISK;
    case 'MXN':
      return l10n.profileCurrencyNameMXN;
    case 'NOK':
      return l10n.profileCurrencyNameNOK;
    case 'NZD':
      return l10n.profileCurrencyNameNZD;
    case 'PHP':
      return l10n.profileCurrencyNamePHP;
    case 'PLN':
      return l10n.profileCurrencyNamePLN;
    case 'RON':
      return l10n.profileCurrencyNameRON;
    case 'SEK':
      return l10n.profileCurrencyNameSEK;
    case 'TRY':
      return l10n.profileCurrencyNameTRY;
    case 'ZAR':
      return l10n.profileCurrencyNameZAR;
    default:
      return l10n.profileCurrencyNameCNY;
  }
}

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
  final l10n = AppLocalizations.of(context);
  final currencies = fetched.isNotEmpty
      ? fetched
      : <Map<String, dynamic>>[
          for (final c in _fallbackCurrencies) Map<String, dynamic>.from(c),
        ];
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.profileDefaultCurrency),
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
                  title: Text(
                    '${c['name'] ?? _fallbackCurrencyName(c['code'] as String? ?? '', l10n)} ${c['code']}',
                  ),
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
  final l10n = AppLocalizations.of(context);
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.profileDefaultCalcScope),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                  value: '', title: Text(l10n.profileCalcScopeAll)),
              RadioListTile<String>(
                  value: 'country', title: Text(l10n.profileCalcScopeCountry)),
              RadioListTile<String>(
                  value: 'province',
                  title: Text(l10n.profileCalcScopeProvince)),
              RadioListTile<String>(
                  value: 'city', title: Text(l10n.profileCalcScopeCity)),
              RadioListTile<String>(
                  value: 'county', title: Text(l10n.profileCalcScopeCounty)),
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

Future<void> _showLanguageDialog(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final options = {
    'zh-CN': l10n.localeOptionZhCN,
    'en-US': l10n.localeOptionEnUS,
    'ar': l10n.localeOptionAr,
  };
  final current = ref.read(localeSettingsProvider).uiLocale;
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.profileLanguage),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in options.entries)
                RadioListTile<String>(
                  value: entry.key,
                  title: Text(entry.value),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (selected == null || selected == current) return;
  if (!context.mounted) return;
  await _saveLocalePreferences(
    context,
    ref,
    uiLocale: selected,
    formatLocale: ref.read(localeSettingsProvider).formatLocale,
    localizedFallback: l10n,
  );
}

Future<void> _showRegionalFormatDialog(
    BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final options = {
    '': l10n.formatOptionFollowLanguage,
    'zh-CN': l10n.formatOptionZhCN,
    'zh-TW': l10n.formatOptionZhTW,
    'en-US': l10n.formatOptionEnUS,
    'en-GB': l10n.formatOptionEnGB,
    'ja-JP': l10n.formatOptionJaJP,
    'de-DE': l10n.formatOptionDeDE,
    'id-ID': l10n.formatOptionIdID,
    'ar-EG': l10n.formatOptionArEG,
  };
  final current = ref.read(localeSettingsProvider).formatLocale ?? '';
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.profileRegionalFormat),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in options.entries)
                RadioListTile<String>(
                  value: entry.key,
                  title: Text(entry.value),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (selected == null || selected == current) return;
  if (!context.mounted) return;
  await _saveLocalePreferences(
    context,
    ref,
    uiLocale: ref.read(localeSettingsProvider).uiLocale,
    formatLocale: selected.isEmpty ? null : selected,
    localizedFallback: l10n,
  );
}

Future<void> _saveLocaleSettings(
  BuildContext context,
  WidgetRef ref, {
  String? defaultCurrency,
  String? defaultCalcScope,
}) async {
  final l10n = AppLocalizations.of(context);
  try {
    final user = await AuthRepository().updateSettings(
      defaultCurrency: defaultCurrency,
      defaultCalcScope: defaultCalcScope,
    );
    ref.read(authProvider.notifier).applyUser(user);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authSaved)),
      );
    }
  } on DioException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractDetail(e, l10n))),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authSaveFailedRetry)),
      );
    }
  }
}

Future<void> _saveLocalePreferences(
  BuildContext context,
  WidgetRef ref, {
  required String uiLocale,
  required String? formatLocale,
  required AppLocalizations localizedFallback,
}) async {
  try {
    final user = await AuthRepository().updateLocalePreferences(
      locale: uiLocale,
      formatLocale: formatLocale,
    );
    ref.read(authProvider.notifier).applyUser(user);
    await ref.read(localeSettingsProvider.notifier).applyUser(user);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedFallback.authSaved)),
      );
    }
  } on DioException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractDetail(e, localizedFallback))),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedFallback.authSaveFailedRetry)),
      );
    }
  }
}

String _extractDetail(DioException e, AppLocalizations l10n) {
  final data = e.response?.data;
  if (data is Map && data['detail'] is String) {
    return data['detail'] as String;
  }
  return l10n.authSaveFailedCheckInput;
}
