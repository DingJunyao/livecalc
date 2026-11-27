import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/layout/shell_app_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../compliance_repository.dart';

/// 「关于」页：版本、服务器、法律文档、AI/地图合规信息、联系方式。
///
/// 合规展示依据：AI 生成内容需标明模型与备案信息（国区要求），
/// 地图服务需展示审图号。信息由服务器管理员在 Web 管理端填写，
/// 这里只做展示，不在客户端硬编码厂商信息。
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<PackageInfo> _packageFuture = PackageInfo.fromPlatform();
  late final Future<AppComplianceConfig?> _configFuture =
      ComplianceRepository().fetchAppConfig();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: ShellAppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        child: FutureBuilder<AppComplianceConfig?>(
          future: _configFuture,
          builder: (context, snapshot) {
            final config = snapshot.data;
            final loading = snapshot.connectionState == ConnectionState.waiting;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAppCard(theme, l10n),
                const SizedBox(height: 12),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (config == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.aboutLoadFailedHint,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                  _buildLegalCard(theme, l10n, config),
                  // 读不到服务器配置时，AI/地图卡片不渲染（否则会误报「未启用」）
                  if (config != null) ...[
                    const SizedBox(height: 12),
                    _buildAiCard(theme, l10n, config),
                    const SizedBox(height: 12),
                    _buildMapCard(theme, l10n, config),
                  ],
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppCard(ThemeData theme, AppLocalizations l10n) {
    final server = ApiClient.instance.baseUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l10n.appTitle, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<PackageInfo>(
              future: _packageFuture,
              builder: (context, snap) {
                final info = snap.data;
                final version = info == null
                    ? ''
                    : '${info.version} (${info.buildNumber})';
                return _kv(theme, l10n.aboutVersion, version);
              },
            ),
            if (server.isNotEmpty) _kv(theme, l10n.aboutServer, server),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalCard(
      ThemeData theme, AppLocalizations l10n, AppComplianceConfig? config) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.legalPrivacyPolicy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/legal/privacy'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.legalTermsOfService),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/legal/terms'),
          ),
          if ((config?.contactEmail ?? '').isNotEmpty)
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(l10n.aboutContact),
              subtitle: SelectableText(config!.contactEmail),
            ),
          if ((config?.legalUpdatedAt ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${l10n.aboutUpdatedAt}: ${config!.legalUpdatedAt.split('T').first}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiCard(
      ThemeData theme, AppLocalizations l10n, AppComplianceConfig? config) {
    final providers = config?.aiProviders ?? const <AiProviderInfo>[];
    final enabled = config?.aiEnabled == true && providers.isNotEmpty;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(l10n.aboutAiSection),
            subtitle: enabled
                ? null
                : Text(l10n.aboutAiDisabled,
                    style: theme.textTheme.bodySmall),
          ),
          if (enabled)
            ...providers.map((p) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.displayName, style: theme.textTheme.bodyLarge),
                      if (p.modelName.isNotEmpty)
                        Text('${l10n.aboutModel}: ${p.modelName}',
                            style: theme.textTheme.bodySmall),
                      if (p.filingNo.isNotEmpty)
                        Text('${l10n.aboutFilingNo}: ${p.filingNo}',
                            style: theme.textTheme.bodySmall),
                      if (p.note.isNotEmpty)
                        Text(p.note, style: theme.textTheme.bodySmall),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildMapCard(
      ThemeData theme, AppLocalizations l10n, AppComplianceConfig? config) {
    // 按平台只展示实际使用的那张底图：
    // iOS 走原生 MapKit（Apple 地图，中国区数据由高德提供），安卓走服务端配置的瓦片底图。
    // 审图号按「实际展示的地图产品」标注，不把所有引擎都列出来。
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final List<MapProviderInfo> providers;
    if (isIos) {
      final apple = config?.appleMap;
      providers = apple == null ? const [] : [apple];
    } else {
      providers = config?.mapProviders ?? const <MapProviderInfo>[];
    }
    // iOS 用原生 MapKit，不依赖服务端瓦片开关；只有服务端配置根本没读到时才算不可用
    final enabled =
        providers.isNotEmpty && (isIos || config?.mapEnabled == true);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(l10n.aboutMapSection),
            subtitle: enabled
                ? null
                : Text(l10n.aboutMapDisabled,
                    style: theme.textTheme.bodySmall),
          ),
          if (enabled)
            ...providers.map((p) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.displayName, style: theme.textTheme.bodyLarge),
                      Text(
                        p.approvalNo.isNotEmpty
                            ? '${l10n.aboutApprovalNo}: ${p.approvalNo}'
                            : '${l10n.aboutApprovalNo}: ${l10n.aboutApprovalMissing}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: p.approvalNo.isEmpty
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                      if (p.approvalNoSatellite.isNotEmpty)
                        Text('${l10n.aboutApprovalNo}（卫星）: ${p.approvalNoSatellite}',
                            style: theme.textTheme.bodySmall),
                      if (p.note.isNotEmpty)
                        Text(p.note, style: theme.textTheme.bodySmall),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _kv(ThemeData theme, String key, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(key,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
          Expanded(child: SelectableText(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
