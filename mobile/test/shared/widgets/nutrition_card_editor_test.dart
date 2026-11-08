import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/models/nutrition.dart';
import 'package:com_a4ding_livecalc/shared/screens/nutrition_edit_screen.dart';
import 'package:com_a4ding_livecalc/shared/widgets/nutrition_card.dart';
import 'package:go_router/go_router.dart';

/// 合并值（详情卡展示用：商品自定义 + 原料继承），编辑器**不应**预填它。
NutritionInfo _merged() => const NutritionInfo(
      entityId: 12,
      entityName: 'Cabbage',
      baseQuantity: 100,
      baseUnit: 'g',
      nutrients: [
        NutrientEntry(key: '能量', label: '能量', value: 88, unit: 'kcal'),
        NutrientEntry(key: '蛋白质', label: '蛋白质', value: 9, unit: 'g'),
      ],
    );

/// 商品自身的自定义营养（编辑器**应该**预填它）。
NutritionInfo _own() => const NutritionInfo(
      entityId: 12,
      entityName: 'Cabbage',
      baseQuantity: 100,
      baseUnit: 'g',
      nutrients: [
        NutrientEntry(key: '能量', label: '能量', value: 100, unit: 'kcal'),
      ],
    );

Widget _app({required NutritionInfo nutrition, NutritionInfo? editorNutrition}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: NutritionCard(
            nutrition: nutrition,
            editorNutrition: editorNutrition,
            loading: false,
            saving: false,
            entityType: 'product',
            entityId: 12,
            entityName: 'Cabbage',
            onSave: (_, __) async => null,
          ),
        ),
      ),
      GoRoute(
        path: '/entities/:entityType/:entityId/nutrition',
        builder: (_, state) {
          final args = state.extra! as NutritionEditArguments;
          return NutritionEditScreen(
            entityType: args.entityType,
            entityId: args.entityId,
            entityName: args.entityName,
            nutrition: args.nutrition,
            allowClear: args.allowClear,
            onRefresh: args.onRefresh,
            onSave: args.onSave,
            onClear: args.onClear,
          );
        },
      ),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('editor prefills editorNutrition (product-own data only)',
      (tester) async {
    await tester.pumpWidget(_app(nutrition: _merged(), editorNutrition: _own()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // '100' 命中两处：营养基准量输入框（默认 100）+ 能量行数值（商品自身值）
    expect(find.widgetWithText(TextField, '100'), findsNWidgets(2),
        reason: '编辑器预填商品自身的自定义营养');
    expect(find.widgetWithText(TextField, '88'), findsNothing,
        reason: '合并值里原料继承的部分不得预填进编辑器');
    expect(find.widgetWithText(TextField, '9'), findsNothing);
  });

  testWidgets('editor falls back to nutrition when editorNutrition is omitted',
      (tester) async {
    // 原料详情不传 editorNutrition：预填数据源保持原样（merged 即自身链路数据）。
    await tester.pumpWidget(_app(nutrition: _merged()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '88'), findsOneWidget);
    expect(find.widgetWithText(TextField, '9'), findsOneWidget);
  });

  testWidgets('empty editorNutrition prefalls default nutrient rows',
      (tester) async {
    // 商品没填过营养：编辑器落到「默认七项」空行，而不是带出原料的合并值。
    await tester.pumpWidget(_app(
      nutrition: _merged(),
      editorNutrition: const NutritionInfo(entityId: 12),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '88'), findsNothing);
    expect(find.widgetWithText(TextField, '9'), findsNothing);
    // 默认行：能量 / 蛋白质 / 脂肪 / 饱和脂肪 / 碳水化合物 / 糖 / 钠
    expect(find.text('Protein'), findsWidgets);
  });
}
