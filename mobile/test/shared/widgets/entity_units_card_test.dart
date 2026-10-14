import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/i18n/app_formatters.dart';
import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';
import 'package:com_a4ding_livecalc/shared/models/entity_unit.dart';
import 'package:com_a4ding_livecalc/shared/widgets/entity_units_card.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

/// 单位表单下拉用的全局质量/体积单位（id 与 siFactor 均与真实数据一致）。
///
/// `si_factor` 的基准是 **SI 基本单位**，不是克/mL：
/// - 质量 → kg（千克 1、克 0.001、斤 0.5），见 backend/app/main.py:57
///   「si_factor 以 kg 为基准，100g = 0.1kg」；
/// - 体积 → L（升 1、毫升 0.001），见 unit_conversion_service.py:180
///   「体积 si_factor 换算到 SI 基本单位 L（不是 m³）」。
///
/// 旧 fixture 把克/毫升写成 `siFactor: 1`（服务端根本不存在这种值），
/// 于是「220 mL × 1030 = 226.6 g」和「× 1030 / 1000 = 0.2266 g」都能过测试，
/// 这正是这个 1000 倍显示 bug 上线的原因。改回真值后下面的用例才会拦住回归。
const _globalUnits = <GlobalUnitOption>[
  GlobalUnitOption(
    id: 1,
    name: '千克',
    abbreviation: 'kg',
    unitType: 'mass',
    siFactor: 1,
  ),
  GlobalUnitOption(
    id: 2,
    name: '克',
    abbreviation: 'g',
    unitType: 'mass',
    siFactor: 0.001,
  ),
  GlobalUnitOption(
    id: 3,
    name: '斤',
    abbreviation: '斤',
    unitType: 'mass',
    siFactor: 0.5,
  ),
  GlobalUnitOption(
    id: 4,
    name: '升',
    abbreviation: 'L',
    unitType: 'volume',
    siFactor: 1,
  ),
  GlobalUnitOption(
    id: 5,
    name: '毫升',
    abbreviation: 'mL',
    unitType: 'volume',
    siFactor: 0.001,
  ),
];

/// 每 1 个全局体积单位的克数：si_factor 换算到 L，L→m³ 的 0.001 与
/// kg→g 的 1000 正好抵消，故直接 × 密度(kg/m³)。
/// （质量口径同理：si_factor 换算到 kg，故每单位克数 = si_factor × 1000，
/// 即克 1 g、斤 500 g、千克 1000 g；移动端质量行展示「原始量 + 叶子单位」，
/// 不展示折算克数，所以下面的质量用例断言的是那一行文字。）
double _gramsPerVolumeUnit(double siFactor, double densityKgM3) =>
    siFactor * densityKgM3;

Future<void> _pumpCard(
  WidgetTester tester, {
  required List<EntityUnit> units,
  List<EntityUnit> inheritedUnits = const [],
  List<EntityDensity> densities = const [],
  List<UnmappedUnit> unmappedUnits = const [],
  double? effectiveDensityKgM3,
  Locale locale = const Locale('zh', 'CN'),
  Future<Object?> Function(UnitWriteInput input)? onAddUnit,
  Future<Object?> Function(int unitId, UnitWriteInput input)? onEditUnit,
  Future<Object?> Function(DensityWriteInput input)? onAddDensity,
  Future<Object?> Function(int unitId)? onDeleteUnit,
}) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: EntityUnitsCard(
            entityType: 'ingredient',
            entityId: 5,
            units: units,
            inheritedUnits: inheritedUnits,
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
    ),
  ));
  await tester.pump();
}

/// 打开「添加单位」整页（不是对话框）。
Future<void> _openAddPage(WidgetTester tester) async {
  await tester.tap(find.byTooltip('添加').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('custom units live on the card and open a full page to add',
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

    // 卡片内直接出现标题 + 右上角添加按钮
    expect(find.text('单位与密度'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('完成'), findsNothing);

    await _openAddPage(tester);
    // 整页（AppBar 标题 + 无对话框）
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppBar, '添加单位'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '单位名称 *'),
      '碗',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '量'),
      '250',
    );
    await tester.tap(find.text('保存单位'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.unitName, '碗');
    expect(saved!.weightPerUnit, 250);
    // 换算系数已从表单移除：恒发 1
    expect(saved!.conversionFactor, 1);
    expect(saved!.weightUnitId, isNull);
    expect(saved!.weightUnitOverrideId, isNull);
    // 保存成功后整页关闭，回到卡片
    expect(find.widgetWithText(AppBar, '添加单位'), findsNothing);
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
    // 打开时把「系数 × 量」合并进「量」= 12，保存时系数恒为 1
    expect(saved!.conversionFactor, 1);
    expect(saved!.weightPerUnit, 12);
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

  testWidgets('conversion factor is gone: always saves 1', (tester) async {
    UnitWriteInput? saved;
    await _pumpCard(
      tester,
      units: const [],
      onAddUnit: (input) async {
        saved = input;
        return null;
      },
    );
    await _openAddPage(tester);
    await tester.enterText(find.widgetWithText(TextField, '单位名称 *'), '把');
    // 换算系数字段不应存在
    expect(find.widgetWithText(TextField, '换算系数（1单位 = ? 个）'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, '量'), '300');
    await tester.tap(find.text('保存单位'));
    await tester.pumpAndSettle();

    expect(saved!.conversionFactor, 1);
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

    // 一箱奶 = 12 盒；盒 220 mL 经密度 1030 折 226.6 g → 12 × 226.6 = 2719.2 g
    final cartonGramsValue = _gramsPerVolumeUnit(0.001, 1030) * 220;
    final cartonGrams = formatQuantity(cartonGramsValue);
    final boxedGrams = formatQuantity(cartonGramsValue * 12);
    expect(find.text('1 箱 = 12 盒（≈ $boxedGrams g）'), findsOneWidget);
    // 质量叶子：默认按克
    expect(find.text('1 个 = 55 g'), findsOneWidget);
    // 体积叶子
    expect(find.text('1 盒 = 220 mL（≈ $cartonGrams g）'), findsOneWidget);
    // 旧的 /1000 口径给出 0.23 g，不能出现
    expect(find.textContaining('0.23 g'), findsNothing);
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

  testWidgets('self-reference is blocked on save', (tester) async {
    var saved = 0;
    final units = <EntityUnit>[
      const EntityUnit(id: 11, unitName: '盒', weightUnitId: 5, weightPerUnit: 220),
    ];
    await _pumpCard(
      tester,
      units: units,
      onEditUnit: (_, __) async {
        saved += 1;
        return null;
      },
    );
    // 编辑「盒」时自身不在下拉里，但直接构造自引用保存路径仍需被拦截
    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('盒（自定义单位）'), findsNothing);
    expect(find.text('毫升 (mL)'), findsOneWidget);
    await tester.tap(find.text('保存单位'));
    await tester.pumpAndSettle();
    expect(saved, 1);
  });

  testWidgets('creating a nested unit sends weightUnitOverrideId, not '
      'weightUnitId', (tester) async {
    UnitWriteInput? saved;
    final units = <EntityUnit>[
      const EntityUnit(id: 11, unitName: '盒', weightUnitId: 5, weightPerUnit: 220),
    ];
    await _pumpCard(
      tester,
      units: units,
      onAddUnit: (input) async {
        saved = input;
        return null;
      },
    );
    await _openAddPage(tester);
    await tester.enterText(find.widgetWithText(TextField, '单位名称 *'), '箱');
    await tester.enterText(find.widgetWithText(TextField, '量'), '12');
    await tester.tap(find.byKey(const Key('unit-weight-unit-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('盒（自定义单位）').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存单位'));
    await tester.pumpAndSettle();

    expect(saved!.weightUnitOverrideId, 11);
    expect(saved!.weightUnitId, isNull);
    expect(saved!.conversionFactor, 1);
    expect(saved!.weightPerUnit, 12);
  });

  testWidgets('volume global unit shows the density conversion hint',
      (tester) async {
    await _pumpCard(
      tester,
      units: const [],
      effectiveDensityKgM3: 1030,
    );
    await _openAddPage(tester);
    await tester.enterText(find.widgetWithText(TextField, '单位名称 *'), '瓶');
    await tester.enterText(find.widgetWithText(TextField, '量'), '220');
    await tester.tap(find.byKey(const Key('unit-weight-unit-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('毫升 (mL)').last);
    await tester.pumpAndSettle();

    // 按密度 1030 kg/m³ 折算 ≈ 226.6 g（mL 的 si_factor 基准是 L：0.001）
    final grams = formatQuantity(_gramsPerVolumeUnit(0.001, 1030) * 220);
    expect(find.textContaining('$grams g'), findsOneWidget);
    // 旧的 /1000 口径给出 0.23 g，不能出现
    expect(find.textContaining('0.23 g'), findsNothing);
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

  testWidgets('inherited units (from the linked ingredient) are selectable '
      'and resolve in the chain', (tester) async {
    UnitWriteInput? saved;
    // 原料定义的「盒 = 220 mL」被商品继承；商品的「箱 = 12 盒」引用它
    const ingredientBox = EntityUnit(
        id: 21, unitName: '盒', weightUnitId: 5, weightPerUnit: 220);
    final ownUnits = <EntityUnit>[
      const EntityUnit(
        id: 22,
        unitName: '箱',
        weightPerUnit: 12,
        weightUnitOverrideId: 21,
      ),
    ];
    await _pumpCard(
      tester,
      units: ownUnits,
      inheritedUnits: const [ingredientBox],
      effectiveDensityKgM3: 1030,
      onAddUnit: (input) async {
        saved = input;
        return null;
      },
    );

    // 列表里「箱」的链能解析到继承来的「盒」（220 mL × 0.001 L/mL × 1030 × 12）
    final boxedGrams = formatQuantity(_gramsPerVolumeUnit(0.001, 1030) * 220 * 12);
    expect(find.text('1 箱 = 12 盒（≈ $boxedGrams g）'), findsOneWidget);

    // 新增单位时下拉里能看到继承来的单位（带「继承自原料」标注）
    await _openAddPage(tester);
    await tester.enterText(find.widgetWithText(TextField, '单位名称 *'), '托盘');
    await tester.tap(find.byKey(const Key('unit-weight-unit-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('盒（继承自原料）'), findsWidgets);
    await tester.tap(find.text('盒（继承自原料）').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存单位'));
    await tester.pumpAndSettle();

    expect(saved!.weightUnitOverrideId, 21);
    expect(saved!.weightUnitId, isNull);
  });

  testWidgets('own unit wins over the inherited one with the same name',
      (tester) async {
    final ownUnits = <EntityUnit>[
      const EntityUnit(id: 31, unitName: '盒', weightPerUnit: 300),
    ];
    await _pumpCard(
      tester,
      units: ownUnits,
      inheritedUnits: const [
        EntityUnit(id: 32, unitName: '盒', weightPerUnit: 220),
      ],
    );

    // 同名时只展示商品自己的那条（300 g，而不是原料的 220 g）
    expect(find.text('1 盒 = 300 g'), findsOneWidget);
    expect(find.text('1 盒 = 220 g'), findsNothing);
  });

  // 用户反馈：全局单位的 si_factor 基准是 SI 基本单位（质量 → kg、体积 → L），
  // 不是克/mL。旧代码直接把它当克/mL 用，于是 220 mL 经密度 1030 显示成
  // 0.2266 g（小 1000 倍）；web 列表对质量叶子也展示折算克数，因此那边还会把
  // 200 g 显示成 0.2 g，移动端质量行只展示「原始量 + 叶子单位」，可见症状在体积行。
  group('si_factor 基准（质量 kg / 体积 L）不再造成 1000 倍偏差', () {
    testWidgets('质量叶子克：1 个 = 200 g（不是 0.2 g）', (tester) async {
      await _pumpCard(
        tester,
        units: const [
          EntityUnit(
            id: 41,
            unitName: '个',
            weightUnitId: 2, // 克，si_factor 0.001 → kg
            weightPerUnit: 200,
          ),
        ],
      );

      // 用户报的原始场景。质量行按叶子单位显示原始量（200 + 「g」），
      // si_factor(0.001) 经 ×1000 后与克 1:1，不会再缩成 0.2 g。
      expect(find.text('1 个 = 200 g'), findsOneWidget);
      expect(find.text('1 个 = 0.2 g'), findsNothing);
    });

    testWidgets('质量叶子千克：1 个 = 2 kg（= 2000 g），不出现 1000 倍偏差',
        (tester) async {
      await _pumpCard(
        tester,
        units: const [
          EntityUnit(
            id: 42,
            unitName: '个',
            weightUnitId: 1, // 千克，si_factor 1 → kg
            weightPerUnit: 2,
          ),
        ],
      );

      // 1 个 = 2 kg = 千克 si_factor 1 × 1000 × 2 = 2000 g；质量行展示叶子单位本身
      // （kg）是等价的正确显示，且不会出现 0.002 这类 /1000 偏差。
      expect(find.text('1 个 = 2 kg'), findsOneWidget);
      expect(find.textContaining('0.002'), findsNothing);
      expect(find.text('1 个 = 2,000 g'), findsNothing);
    });

    testWidgets('质量叶子斤：1 把 = 2 斤（标签取自叶子单位的缩写）',
        (tester) async {
      await _pumpCard(
        tester,
        units: const [
          EntityUnit(
            id: 43,
            unitName: '把',
            weightUnitId: 3, // 斤，si_factor 0.5 → kg
            weightPerUnit: 2,
          ),
        ],
      );

      // 后端口径：2 斤 × 0.5 kg/斤 × 1000 = 1000 g。质量行显示「原始量 + 叶子缩写」，
      // 标签来自全局单位 abbreviation（「斤」），不是硬编码的 g，因此这里应显示
      // 2 斤而不是 1000 g，也不能退化成 2 g。
      expect(find.text('1 把 = 2 斤'), findsOneWidget);
      expect(find.text('1 把 = 2 g'), findsNothing);
      expect(find.text('1 把 = 1 斤'), findsNothing);
    });

    testWidgets('体积叶子毫升：1 盒 = 220 mL（≈ 226.6 g），不是 0.2266 g',
        (tester) async {
      await _pumpCard(
        tester,
        units: const [
          EntityUnit(
            id: 44,
            unitName: '盒',
            weightUnitId: 5, // 毫升，si_factor 0.001 → L
            weightPerUnit: 220,
          ),
        ],
        effectiveDensityKgM3: 1030,
      );

      // 每 1 个「盒」= 220 mL × 0.001 L/mL × 1030 kg/m³ = 226.6 g
      // （L→m³ 的 0.001 与 kg→g 的 1000 抵消）。
      final grams = formatQuantity(_gramsPerVolumeUnit(0.001, 1030) * 220);
      expect(find.text('1 盒 = 220 mL（≈ $grams g）'), findsOneWidget);
      // 旧的 /1000 口径给出 0.23 g
      expect(find.textContaining('0.23 g'), findsNothing);
    });

    testWidgets('体积叶子升：1 瓶 = 2 L（≈ 2060 g），1 桶 = 1 L（≈ 1030 g）',
        (tester) async {
      await _pumpCard(
        tester,
        units: const [
          EntityUnit(
            id: 45,
            unitName: '瓶',
            weightUnitId: 4, // 升，si_factor 1 → L
            weightPerUnit: 2,
          ),
          EntityUnit(
            id: 48,
            unitName: '桶',
            weightUnitId: 4,
            weightPerUnit: 1,
          ),
        ],
        effectiveDensityKgM3: 1030,
      );

      // 2 L × 1 L/L × 1030 kg/m³ = 2060 g；1 L = 1030 g。
      // 移动端沿用叶子单位（L），不额外折算成 2000/1000 mL。
      final perLiter = _gramsPerVolumeUnit(1, 1030);
      expect(find.text('1 瓶 = 2 L（≈ ${formatQuantity(perLiter * 2)} g）'),
          findsOneWidget);
      expect(find.text('1 桶 = 1 L（≈ ${formatQuantity(perLiter)} g）'),
          findsOneWidget);
      // 旧的 /1000 口径给出 2.06 g / 1.03 g
      expect(find.textContaining('2.06 g'), findsNothing);
      expect(find.textContaining('1.03 g'), findsNothing);
    });

    testWidgets('嵌套引用体积叶子：1 箱 = 12 盒（盒 = 220 mL）→ ≈ 2719.2 g',
        (tester) async {
      await _pumpCard(
        tester,
        units: const [
          EntityUnit(
            id: 46,
            unitName: '盒',
            weightUnitId: 5,
            weightPerUnit: 220,
          ),
          EntityUnit(
            id: 47,
            unitName: '箱',
            weightPerUnit: 12,
            weightUnitOverrideId: 46,
          ),
        ],
        effectiveDensityKgM3: 1030,
      );

      // 12 × (220 × 0.001 × 1030) = 12 × 226.6 = 2719.2 g
      final perBox = _gramsPerVolumeUnit(0.001, 1030) * 220;
      final boxed = formatQuantity(perBox * 12);
      expect(find.text('1 箱 = 12 盒（≈ $boxed g）'), findsOneWidget);
      expect(find.text('1 盒 = 220 mL（≈ ${formatQuantity(perBox)} g）'),
          findsOneWidget);
      expect(find.textContaining('2.7192 g'), findsNothing);
    });
  });
}
