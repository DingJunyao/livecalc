import 'package:flutter/widgets.dart';

/// 应用内法律文档（隐私政策 / 用户协议）。
///
/// 正文放在 `assets/legal/<doc>_<lang>.md`，与商店提交用的 HTML 版本同源维护。
/// 目前只提供中文与英文；其他语言（如阿语）回退到英文版。
enum LegalDocument { privacy, terms }

extension LegalDocumentX on LegalDocument {
  String get slug => this == LegalDocument.privacy ? 'privacy' : 'terms';

  static LegalDocument? fromSlug(String? slug) {
    switch (slug) {
      case 'privacy':
        return LegalDocument.privacy;
      case 'terms':
        return LegalDocument.terms;
      default:
        return null;
    }
  }
}

String legalAssetPath(LegalDocument document, Locale locale) {
  final lang = locale.languageCode == 'zh' ? 'zh' : 'en';
  return 'assets/legal/${document.slug}_$lang.md';
}
