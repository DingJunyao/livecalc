import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/i18n/app_formatters.dart';
import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';
import 'package:com_a4ding_livecalc/shared/models/entity_unit.dart';
import 'package:com_a4ding_livecalc/shared/widgets/entity_units_card.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

/// 单位表单下拉用的全局质量/体积单位（g / mL）。
const _globalUnits = <GlobalUnitOption>[
  GlobalUnitOption(
    id: 3,
    name: '克',
    abbreviation: 'g',
    unitType: 'mass',
    siFactor: 1,
  ),
  GlobalUnitOption(
    id: 5,
    name: '毫升',
    abbreviation: 'mL',
    unitType: 'volume',
    siFactor: 1,
  ),
];

Future<void> _pumpCard(
  WidgetTester tester, {
  required List<EntityUnit> units,
  List<EntityDensity> densities = const [],
  List<UnmappedUnit> unmappedUnits = const [],
  double? effectiveDensityKgM3,
  Locale locale = const Locale('zh', 'CN'),
  Future<Object?> Function(UnitWriteInput input)? onAddUnit,
  Future<Object?> Function(int unitId, UnitWriteInput input)? onEditUnit,
  Future<Object?> Function(DensityWriteInput input)? onAddDensity,
  Future<Object?> Function(int unitId)? onDeleteUnit,
}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: EntityUnitsCard(
          entityType: 'ingredient',
          entityId: 5,
          units: units,
          unmappedUnits: unmappedUnits,
          densities: densities,
          globalUnitOptions: _globalUnits,
          effectiveDensityKgM3: effectiveDensityKgM3,
          onAddUnit: onAddUnit ?? (_) async => null,
          onEditUnit: onEditUnit ?? (_, __) async => null,
          onDeleteUnit: onDeleteUnit ?? (_) async => null,
          onAddDensity: onAddDensity ?? (_) async => null,
          onDeleteDensity: (_) async => null,
        ),
      ),
    ),
  ));
  await tester.pump();
}

Future<void> _openAddDialog(WidgetTester tester) async {
  await tester.tap(find.byTooltip('添加').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('custom units live on the card and open a dialog to add',
      (tester) async {
    UnitWriteInput? saved;
    await _pumpCard(
      tester,
      units: const [],
      onAddUnit: (input) async {
        saved = input;
        return null;
      },
    );

    // 不再跳转整页：卡片内直接出现标题 + 右上角添加按钮
    expect(find.text('单位与密度'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('完成'), findsNothing);

    await _openAddDialog(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('添加单位'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '单位名称 *'),
      '碗',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '单个重量'),
      '250',
    );
    await tester.tap(find.text('保存单位'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.unitName, '碗');
    expect(saved!.weightPerUnit, 250);
    // 换算系数留空 = 1（发送 null）
    expect(saved!.conversionFactor, isNull);
    expect(saved!.weightUnitId, isNull);
    expect(saved!.weightUnitOverrideId, isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('weight unit dropdown offers default, global units and other '
      'custom units but not itself', (tester) async {
    final units = <EntityUnit>[
      const EntityUnit(
          id: 11, unitName: '盒', weightUnitId: 5, weightPerUnit: 220),
      const EntityUnit(id: 12, unitName: '箱'),
    ];
    await _pumpCard(tester, units: units);

    // 第二个编辑按钮 = 第二行「箱」
    await tester.tap(find.byTooltip('编辑').at(1));
    await tester.pumpAndSettle();
    expect(find.text('编辑单位'), findsOneWidget);
    expect(find.text('单位名称 *'), findsOneWidget);

    await tester.tap(find.byKey(const Key('unit-weight-unit-dropdown')));
    await tester.pumpAndSettle();

    // 全局质量/体积单位：名称 (缩写)
    expect(find.text('克 (g)'), findsWidgets);
    expect(find.text('毫升 (mL)'), findsWidgets);
    // 另一个自定义单位可选，自身不可选
    expect(find.text('盒（自定义单位）'), findsWidgets);
    expect(find.text('箱（自定义单位）'), findsNothing);
  });

  testWidgets('editing pre-fills the nested weight unit override',
      (tester) async {
    UnitWriteInput? saved;
    int? editedId;
    final units = <EntityUnit>[
      const EntityUnit(
          id: 11, unitName: '盒', weightUnitId: 5, weightPerUnit: 220),
      const EntityUnit(
        id: 12,
        unitName: '箱',
        conversionFactor: 12,
        weightUnitOverrideId: 11,
      ),
    ];
    await _pumpCard(
      tester,
      units: units,
      onEditUnit: (unitId, input) async {
        editedId = unitId;
        saved = input;
        return null;
      },
    );

    await tester.tap(find.byTooltip('编辑').at(1));
    await tester.pumpAndSettle();
    // 嵌套引用回显为被引用单位
    expect(find.text('盒（自定义单位）'), findsOneWidget);

    await tester.tap(find.text('保存单位'));
    await tester.pumpAndSettle();

    expect(editedId, 12);
    expect(saved!.weightUnitOverrideId, 11);
    expect(saved!.weightUnitId, isNull);
    expect(saved!.conversionFactor, 12);
    expect(saved!.weightPerUnit, isNull);
  });

  testWidgets('editing pre-fills a global weight unit', (tester) async {
    final units = <EntityUnit>[
      const EntityUnit(
          id: 11, unitName: '盒', weightUnitId: 5, weightPerUnit: 220),
    ];
    await _pumpCard(tester, units: units);
    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('毫升 (mL)'), findsOneWidget);
  });

  testWidgets('conversion factor blank or zero saves as null (defaults to 1)',
      (tester) async {
    UnitWriteInput? saved;
    await _pumpCard(
      tester,
      units: const [],
      onAddUnit: (input) async {
        saved = input;
        return null;
      },
    );
    await _openAddDialog(tester);
    await tester.enterText(find.widgetWithText(TextField, '单位名称 *'), '把');
    await tester.enterText(
      find.widgetWithText(TextField, '换算系数（1单位 = ? 个）'),
      '0',
    );
    await tester.enterText(find.widgetWithText(TextField, '单个重量'), '300');
    await tester.tap(find.text('保存单位'));
    await tester.pumpAndSettle();

    expect(saved!.conversionFactor, isNull);
    expect(saved!.weightPerUnit, 300);
  });

  testWidgets('chain is resolved for nested, mass leaf and volume leaf',
      (tester) async {
    final units = <EntityUnit>[
      const EntityUnit(
        id: 11,
        unitName: '盒',
        weightUnitId: 5,
        weightPerUnit: 220,
      ),
      const EntityUnit(
        id: 12,
        unitName: '箱',
        conversionFactor: 12,
        weightUnitOverrideId: 11,
      ),
      const EntityUnit(
        id: 13,
        unitName: '个',
        weightPerUnit: 55,
      ),
    ];
    await _pumpCard(
      tester,
      units: units,
      effectiveDensityKgM3: 1030,
    );

    // 一箱奶 = 12 盒；盒 220mL 经密度 1030 折 226.6 g → 12 × 226.6 = 2719.2 g
    final boxedGrams = formatQuantity(12 * 220 * 1030 / 1000);
    expect(find.text('1 箱 = 12 盒（≈ $boxedGrams g）'), findsOneWidget);
    // 质量叶子：默认按克
    expect(find.text('1 个 = 55 g'), findsOneWidget);
    // 体积叶子
    final cartonGrams = formatQuantity(220 * 1030 / 1000);
    expect(find.text('1 盒 = 220 mL（≈ $cartonGrams g）'), findsOneWidget);
  });

  testWidgets('unit without weight data only shows the name', (tester) async {
    await _pumpCard(
      tester,
      units: const [EntityUnit(id: 21, unitName: '把', conversionFactor: 3)],
    );
    expect(find.text('把'), findsOneWidget);
    // 未设置重量单位时按克，1 把 = 3 g
    expect(find.text('1 把 = 3 g'), findsOneWidget);
  });

  testWidgets('row actions: pending rows have none, active rows edit/delete',
      (tester) async {
    final units = <EntityUnit>[
      const EntityUnit(
        id: -7,
        unitName: '待审单位',
        isPending: true,
        source: 'pending',
        weightPerUnit: 100,
      ),
      const EntityUnit(id: 8, unitName: '已生效单位', weightPerUnit: 100),
    ];
    int? deleted;
    await _pumpCard(
      tester,
      units: units,
      onDeleteUnit: (unitId) async {
        deleted = unitId;
        return null;
      },
    );

    expect(find.text('待审'), findsOneWidget);
    // 待审行没有编辑/删除按钮，只有生效行有
    expect(find.byTooltip('编辑'), findsOneWidget);
    expect(find.byTooltip('删除'), findsOneWidget);

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除单位'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(deleted, 8);
  });

  testWidgets('density section shows the single active density with actions',
      (tester) async {
    DensityWriteInput? saved;
    await _pumpCard(
      tester,
      units: const [],
      densities: const [
        EntityDensity(id: 4, density: 1030, condition: '常温'),
      ],
      onAddDensity: (input) async {
        saved = input;
        return null;
      },
    );

    expect(find.text('${formatQuantity(1030)} kg/m³'), findsOneWidget);
    expect(find.text('常温'), findsOneWidget);
    expect(find.text('暂无密度数据'), findsNothing);

    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('编辑单位'), findsOneWidget);
    // 预设 chips 在密度对话框内
    expect(find.textContaining('水'), findsWidgets);
    expect(find.textContaining('牛奶'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, '密度（kg/m³）*'),
      '1100',
    );
    await tester.tap(find.text('保存密度'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.density, 1100);
    expect(saved!.condition, '常温');
  });

  testWidgets('density add action appears when no density exists',
      (tester) async {
    DensityWriteInput? saved;
    await _pumpCard(
      tester,
      units: const [],
      onAddDensity: (input) async {
        saved = input;
        return null;
      },
    );
    expect(find.text('暂无密度数据'), findsOneWidget);
    // 单位区一个添加，密度区一个添加
    expect(find.byTooltip('添加'), findsNWidgets(2));

    await tester.tap(find.byTooltip('添加').last);
    await tester.pumpAndSettle();
    expect(find.text('添加密度'), findsOneWidget);
    await tester.tap(find.textContaining('牛奶'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存密度'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull, reason: 'density callback was not invoked');
    expect(saved!.density, 1030);
  });

  testWidgets('Arabic unit usage and conversion digits are localized',
      (tester) async {
    final original = localeSettingsStore.current;
    localeSettingsStore.update(const LocaleSettings(uiLocale: 'ar'));
    addTearDown(() => localeSettingsStore.update(original));

    await _pumpCard(
      tester,
      locale: const Locale('ar'),
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
    );

    expect(find.textContaining(formatNumber(12)), findsOneWidget);
    // 1 كوب = 625 g（2.5 × 250，默认按克）
    expect(find.textContaining(formatNumber(625)), findsOneWidget);
    // 不能再出现 ASCII 数字。
    expect(find.textContaining('12'), findsNothing);
    expect(find.textContaining('2.5'), findsNothing);
    expect(find.textContaining('250'), findsNothing);
  });
}
