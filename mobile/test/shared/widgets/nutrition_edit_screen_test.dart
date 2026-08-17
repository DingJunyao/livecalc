import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/models/nutrition.dart';
import 'package:com_a4ding_livecalc/shared/screens/nutrition_edit_screen.dart';

void main() {
  testWidgets('nutrition editor is a full page and saves parsed rows', (
    tester,
  ) async {
    List<NutrientEntry>? saved;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: NutritionEditScreen(
          initialNutrients: const [
            NutrientEntry(key: 'energy', label: '能量', value: 120, unit: 'kcal'),
          ],
          onSave: (rows) async => saved = rows,
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
    await tester.pumpWidget(MaterialApp(
      home: NutritionEditScreen(
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
        onSave: (rows) async => null,
      ),
    ));

    expect(find.widgetWithText(TextField, '120'), findsOneWidget);
  });

  testWidgets('nutrition rows fit narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: NutritionEditScreen(
        initialNutrients: const [
          NutrientEntry(
            key: 'saturated_fat',
            label: '饱和脂肪',
            value: 12,
            unit: 'g',
          ),
        ],
        onSave: (rows) async => null,
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('饱和脂肪'), findsOneWidget);
  });
}
