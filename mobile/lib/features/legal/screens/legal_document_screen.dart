import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../l10n/app_localizations.dart';
import '../../../core/layout/shell_app_bar.dart';
import '../compliance_repository.dart';
import '../legal_document.dart';

/// 应用内法律文档页（隐私政策 / 用户协议）。
///
/// 离线可读（正文随包分发），审核时即使服务器不可用也能看到；渲染器只支持
/// 文档里用到的极简 Markdown：`#` 标题、`##` 小节、`-` 列表、空行分段。
class LegalDocumentScreen extends StatefulWidget {
  final LegalDocument document;

  const LegalDocumentScreen({super.key, required this.document});

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  String? _content;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_content == null && !_failed) _load();
  }

  Future<void> _load() async {
    final locale = Localizations.localeOf(context);
    final lang = locale.languageCode == 'zh' ? 'zh' : 'en';
    // 优先使用服务器上由管理员编辑的版本（自建服务器的运营者才是个人信息处理者，
    // 其政策可能与本仓库默认文案不同）；服务器不可用时回退到随包分发的文案。
    final serverText = await ComplianceRepository().fetchLegalDocument(
      doc: widget.document.slug,
      locale: lang,
    );
    if (serverText != null) {
      if (mounted) setState(() => _content = serverText);
      return;
    }
    try {
      final text = await rootBundle.loadString(legalAssetPath(widget.document, locale));
      if (mounted) setState(() => _content = text);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.document == LegalDocument.privacy
        ? l10n.legalPrivacyPolicy
        : l10n.legalTermsOfService;

    return Scaffold(
      appBar: ShellAppBar(title: Text(title)),
      body: SafeArea(
        child: _failed
            ? Center(child: Text(l10n.legalDocLoadFailed))
            : _content == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _render(_content!, Theme.of(context)),
                    ),
                  ),
      ),
    );
  }

  List<Widget> _render(String markdown, ThemeData theme) {
    final widgets = <Widget>[];
    for (final raw in markdown.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 10));
        continue;
      }
      if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            line.substring(3),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ));
      } else if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            line.substring(2),
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ));
      } else if (line.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(line.substring(2), style: theme.textTheme.bodyMedium)),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(line, style: theme.textTheme.bodyMedium),
        ));
      }
    }
    return widgets;
  }
}
