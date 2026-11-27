import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

/// 登录前也能访问的合规入口：隐私政策 · 用户协议 · 关于。
///
/// 放在登录页 / 服务器配置页底部，保证审核人员和首次使用者不必先注册
/// 就能读到法律文档与 AI/地图合规信息。已登录用户走个人中心入口。
class LegalLinksRow extends StatelessWidget {
  const LegalLinksRow({super.key, this.showAbout = true});

  final bool showAbout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final links = <(String, String)>[
      (l10n.legalPrivacyPolicy, '/legal/privacy'),
      (l10n.legalTermsOfService, '/legal/terms'),
      if (showAbout) (l10n.aboutTitle, '/about'),
    ];
    final dividerStyle = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.outline.withValues(alpha: 0.6));
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: [
        for (var i = 0; i < links.length; i++) ...[
          if (i > 0) Text('·', style: dividerStyle),
          TextButton(
            onPressed: () => context.push(links[i].$2),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: theme.colorScheme.outline,
            ),
            child: Text(links[i].$1, style: theme.textTheme.bodySmall),
          ),
        ],
      ],
    );
  }
}
