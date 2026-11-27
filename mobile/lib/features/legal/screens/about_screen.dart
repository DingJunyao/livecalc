import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/external_link_service.dart';
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
  /// 随包的 app-info.json（与 Web/后端同源，由 scripts/sync_versions.py 生成）
  late final Future<_AppInfo> _appInfoFuture = _loadAppInfo();

  Future<_AppInfo> _loadAppInfo() async {
    try {
      final raw = await rootBundle.loadString('assets/app_info.json');
      final data = json.decode(raw);
      if (data is Map) return _AppInfo.fromJson(data.cast<String, dynamic>());
    } catch (_) {
      // 资源缺失/损坏时退回空信息，页面仍可用
    }
    return const _AppInfo();
  }

  Future<void> _openLink(String url) async {
    final ok = await ExternalLinkService.open(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).aboutLinkOpenFailed)),
      );
    }
  }

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
                _buildAppCard(theme, l10n, config),
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

  Widget _buildAppCard(
      ThemeData theme, AppLocalizations l10n, AppComplianceConfig? config) {
    final server = ApiClient.instance.baseUrl;
    return FutureBuilder<_AppInfo>(
      future: _appInfoFuture,
      builder: (context, snap) {
        final info = snap.data ?? const _AppInfo();
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.name.isNotEmpty ? info.name : l10n.appTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                          if (info.description.isNotEmpty)
                            Text(
                              info.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 移动端版本：随包版本（与 Web/后端同一 app-info.json 同步）
                    FutureBuilder<PackageInfo>(
                      future: _packageFuture,
                      builder: (context, pkg) {
                        final data = pkg.data;
                        final version = data != null
                            ? '${data.version} (${data.buildNumber})'
                            : info.version;
                        return _kv(theme, l10n.aboutMobileVersion, version);
                      },
                    ),
                    // 服务端版本：来自 /app/config，便于排查版本不一致
                    _kv(
                      theme,
                      l10n.aboutServerVersion,
                      config?.serverVersion.isNotEmpty == true
                          ? config!.serverVersion
                          : '—',
                    ),
                    if (server.isNotEmpty)
                      _kv(theme, l10n.aboutServer, server),
                    if (info.copyright.isNotEmpty)
                      _kv(theme, l10n.aboutCopyright, info.copyright),
                  ],
                ),
              ),
              if (info.homepage.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(l10n.aboutProjectHomepage),
                  subtitle: Text(info.homepage,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openLink(info.homepage),
                ),
              ],
              if (info.authorHomepage.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(l10n.aboutAuthorHomepage),
                  subtitle: Text(info.authorHomepage,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openLink(info.authorHomepage),
                ),
            ],
          ),
        );
      },
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

/// 随包的应用身份信息（assets/app_info.json，由 scripts/sync_versions.py 生成）。
class _AppInfo {
  final String name;
  final String description;
  final String version;
  final String copyright;
  final String homepage;
  final String repository;
  final String authorHomepage;

  const _AppInfo({
    this.name = '',
    this.description = '',
    this.version = '',
    this.copyright = '',
    this.homepage = '',
    this.repository = '',
    this.authorHomepage = '',
  });

  factory _AppInfo.fromJson(Map<String, dynamic> json) {
    return _AppInfo(
      name: '${json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
      version: '${json['version'] ?? ''}',
      copyright: '${json['copyright'] ?? ''}',
      homepage: '${json['homepage'] ?? ''}',
      repository: '${json['repository'] ?? ''}',
      authorHomepage: '${json['authorHomepage'] ?? ''}',
    );
  }
}

