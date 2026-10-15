import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/auth_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/shared/models/nutrition.dart';
import 'package:com_a4ding_livecalc/shared/utils/nutrition_basis.dart';
import 'package:com_a4ding_livecalc/shared/screens/nutrition_edit_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

/// 带单位偏好的假登录态（编辑器从 authProvider 读能量单位偏好）。
class _PrefAuthNotifier extends AuthNotifier {
  _PrefAuthNotifier(User user) : super(AuthRepository()) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  @override
  Future<void> checkAuth() async {}
}

void main() {
  testWidgets('nutrition editor is a full page and saves parsed rows', (
    tester,
  ) async {
    List<NutrientEntry>? saved;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NutritionEditScreen(
          basisUnitsLoader: () async => const [],
          initialNutrients: const [
            NutrientEntry(key: 'energy', label: '能量', value: 120, unit: 'kcal'),
          ],
          onSave: (rows, basis) async => saved = rows,
        ),
      ),
    ));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppBar, '编辑营养成分'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '120').first,
      '125.5',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved?.single.value, 125.5);
  });

  testWidgets('nutrition editor prefills rows from detail nutrition data', (
    tester,
  ) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NutritionEditScreen(
        basisUnitsLoader: () async => const [],
        nutrition: const NutritionInfo(
          entityId: 8,
          nutrients: [
            NutrientEntry(
              key: 'energy',
              label: '能量',
              value: 120,
              unit: 'kcal',
            ),
          ],
        ),
        onSave: (rows, _) async => null,
      ),
    )));

    expect(find.widgetWithText(TextField, '120'), findsOneWidget);
  });

  testWidgets('nutrition rows fit narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NutritionEditScreen(
        basisUnitsLoader: () async => const [],
        initialNutrients: const [
          NutrientEntry(
            key: 'saturated_fat',
            label: '饱和脂肪',
            value: 12,
            unit: 'g',
          ),
        ],
        onSave: (rows, _) async => null,
      ),
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('饱和脂肪'), findsOneWidget);
  });

  testWidgets('新建营养预填五项（能量随偏好 / 钠 mg），空保存不写数据', (tester) async {
    // 用户要求：新建原料/商品添加营养时默认带出能量、蛋白质、脂肪、碳水化合物、
    // 钠，能量默认**跟随能量单位偏好**（无偏好回退 kcal）、钠默认 mg；
    // 只点进来没填的话不记录。
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    List<NutrientEntry>? saved;
    var saveCalls = 0;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NutritionEditScreen(
        entityType: 'ingredient',
        entityId: 0,
        basisUnitsLoader: () async => const ['袋', 'g', 'mL'],
        onSave: (rows, basis) async {
          saveCalls++;
          saved = rows;
          return null;
        },
      ),
    )));
    await tester.pumpAndSettle();

    for (final label in const ['能量', '蛋白质', '脂肪', '碳水化合物', '钠']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // 无登录用户 → 能量偏好回退 kcal；钠固定 mg（各自下拉的当前值）
    expect(find.text('kcal'), findsWidgets);
    expect(find.text('mg'), findsWidgets);

    // 只点进来看看，什么都没填：不发起保存
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saveCalls, 0);
    expect(saved, isNull);
  });

  testWidgets('能量偏好为 kJ 的用户：默认行能量单位跟到 kJ', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifier = _PrefAuthNotifier(
      const User(
        id: 1,
        username: 'u',
        email: 'u@b.c',
        unitPreferences: UnitPreferences(energyUnit: 'kJ'),
      ),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((_) => notifier)],
      child: MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NutritionEditScreen(
        entityType: 'ingredient',
        entityId: 0,
        basisUnitsLoader: () async => const [],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('kJ'), findsWidgets);
    expect(find.text('kcal'), findsNothing);
  });

  testWidgets('填了值后保存，带上「每 X 单位」的营养基准', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    List<NutrientEntry>? saved;
    NutritionBasis? savedBasis;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NutritionEditScreen(
        entityType: 'product',
        entityId: 42,
        basisUnitsLoader: () async => const ['袋', 'g', 'mL'],
        onSave: (rows, basis) async {
          saved = rows;
          savedBasis = basis;
          return null;
        },
      ),
    )));
    await tester.pumpAndSettle();

    // 基准量改成 1，单位选自助加载的自定义单位「袋」
    await tester.enterText(find.widgetWithText(TextField, '100'), '1');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('袋').last);
    await tester.pumpAndSettle();

    // 填钠（钠在最后一行，按行内 Column 定位其数值输入框）
    final sodiumRow = find
        .ancestor(of: find.text('钠'), matching: find.byType(Column))
        .first;
    await tester.enterText(
      find.descendant(of: sodiumRow, matching: find.byType(TextField)),
      '480',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved?.length, 1);
    expect(saved?.single.label, '钠');
    expect(saved?.single.value, 480);
    expect(savedBasis?.amount, 1);
    expect(savedBasis?.unit, '袋');
  });

  testWidgets('已有数据全清空时仍提示至少填一项（不静默丢弃）', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NutritionEditScreen(
        entityType: 'ingredient',
        entityId: 5,
        basisUnitsLoader: () async => const [],
        initialNutrients: const [
          NutrientEntry(key: 'energy', label: '能量', value: 120, unit: 'kcal'),
        ],
        onSave: (rows, _) async => null,
      ),
    )));
    await tester.pumpAndSettle();

    // 把唯一一行清空 → 保存应提示，而不是当作「没填写」静默返回
    // （编辑器保证至少保留一行，所以「清空全部」只能靠清空输入框）
    await tester.enterText(find.widgetWithText(TextField, '120'), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('请至少填写一项营养素'), findsOneWidget);
  });
}
