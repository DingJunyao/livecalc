import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/screens/entity_units_screen.dart';

void main() {
  testWidgets('unit maintenance is a full page and saves multi-field form',
      (tester) async {
    String? savedName;
    double? savedWeight;
    await tester.pumpWidget(MaterialApp(
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
}
