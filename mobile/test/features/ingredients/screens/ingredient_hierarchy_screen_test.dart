import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/ingredients/screens/ingredient_hierarchy_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

void main() {
  testWidgets('hierarchy maintenance is a full page with graph and form',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: IngredientHierarchyScreen(
        ingredientId: 8,
        ingredientName: '猪肉',
        hierarchyData: const IngredientHierarchyData(),
        isAdmin: true,
        onAdd: (_) async => null,
        onUpdateStrength: (_, __) async => null,
        onDelete: (_) async => null,
      ),
    ));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppBar, 'Manage ingredient relations'),
        findsOneWidget);
    expect(find.text('Relation graph'), findsOneWidget);
    expect(find.text('Relation list'), findsOneWidget);
    expect(find.text('Search ingredient *'), findsOneWidget);
    expect(find.text('Relation type'), findsOneWidget);
  });
}
