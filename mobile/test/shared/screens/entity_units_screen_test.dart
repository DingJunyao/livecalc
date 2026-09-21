import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/i18n/app_formatters.dart';
import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';
import 'package:com_a4ding_livecalc/shared/models/entity_unit.dart';
import 'package:com_a4ding_livecalc/shared/screens/entity_units_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

void main() {
  testWidgets('unit maintenance is a full page and saves multi-field form',
      (tester) async {
    String? savedName;
    double? savedWeight;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EntityUnitsScreen(
        entityType: 'ingredient',
        entityId: 5,
        units: const [],
        unmappedUnits: const [],
        densities: const [],
        isAdmin: true,
        onAddUnit: (args) async {
          savedName = args.unitName;
          savedWeight = args.weightPerUnit;
          return null;
        },
        onEditUnit: (_, __) async => null,
        onDeleteUnit: (_) async => null,
        onQuickAddUnmapped: (_) async => null,
        onAddDensity: (_) async => null,
        onDeleteDensity: (_) async => null,
      ),
    ));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppBar, '单位与密度'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, '单位名称 *'),
      '碗',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '单重（g/个）'),
      '250',
    );
    await tester.tap(find.text('保存单位'));
    await tester.pumpAndSettle();

    expect(savedName, '碗');
    expect(savedWeight, 250);
  });

  testWidgets('Arabic unit usage and conversion digits are localized',
      (tester) async {
    final original = localeSettingsStore.current;
    localeSettingsStore.update(const LocaleSettings(uiLocale: 'ar'));
    addTearDown(() => localeSettingsStore.update(original));

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EntityUnitsScreen(
        entityType: 'ingredient',
        entityId: 5,
        units: const [
          EntityUnit(
            id: 1,
            unitName: 'كوب',
            conversionFactor: 2.5,
            weightPerUnit: 250,
          ),
        ],
        unmappedUnits: const [
          UnmappedUnit(unitId: 2, unitName: 'حزمة', usageCount: 12),
        ],
        densities: const [],
        isAdmin: true,
        onAddUnit: (_) async => null,
        onEditUnit: (_, __) async => null,
        onDeleteUnit: (_) async => null,
        onQuickAddUnmapped: (_) async => null,
        onAddDensity: (_) async => null,
        onDeleteDensity: (_) async => null,
      ),
    ));

    expect(find.textContaining(formatNumber(12)), findsOneWidget);
    expect(find.textContaining(formatNumber(2.5)), findsOneWidget);
    expect(find.textContaining(formatNumber(250)), findsOneWidget);
    // 不能再出现 ASCII 数字。
    expect(find.textContaining('12'), findsNothing);
    expect(find.textContaining('2.5'), findsNothing);
    expect(find.textContaining('250'), findsNothing);
  });
}
