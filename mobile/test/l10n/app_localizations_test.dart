import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

void main() {
  test('generated catalogs load complete translations', () async {
    final zh = await AppLocalizations.delegate.load(const Locale('zh', 'CN'));
    final en = await AppLocalizations.delegate.load(const Locale('en', 'US'));
    final ar = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(zh.appTitle, '生计 - 生活成本计算器');
    expect(en.appTitle, 'LiveCalc - Living Cost Calculator');
    expect(ar.appTitle, 'لايف كالك - حاسبة تكاليف المعيشة');
    expect(zh.commonSave, '保存');
    expect(en.commonSave, 'Save');
    expect(ar.commonSave, 'حفظ');
  });
}
