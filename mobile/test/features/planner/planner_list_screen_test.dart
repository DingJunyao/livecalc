import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:com_a4ding_livecalc/features/planner/providers/planner_provider.dart';
import 'package:com_a4ding_livecalc/features/planner/screens/planner_screens.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/providers/calc_context_provider.dart';

class _StaticPlannerNotifier extends PlannerListNotifier {
  PlannerListState _initial;

  _StaticPlannerNotifier(this._initial);

  @override
  PlannerListState get state => _initial;

  @override
  set state(PlannerListState value) {
    _initial = value;
  }

  @override
  Future<void> load() async {}
}

GoRouter _router() => GoRouter(
      initialLocation: '/plans',
      routes: [
        GoRoute(
          path: '/plans',
          builder: (_, __) => const PlannerListScreen(),
        ),
      ],
    );

Widget _wrap(PlannerListState state) {
  final notifier = _StaticPlannerNotifier(state);
  return ProviderScope(
    overrides: [
      displayCurrencyProvider.overrideWithValue('CNY'),
      plannerListProvider.overrideWith((ref) => notifier),
    ],
    child: MaterialApp.router(
      locale: const Locale('en', 'US'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router(),
    ),
  );
}

void main() {
  testWidgets('plan list cards keep one fixed height while insights load',
      (tester) async {
    const initial = PlannerListState(plans: [
      {
        'id': 1,
        'name': 'Plan',
        'kind': 'meal',
        'items': <Map<String, dynamic>>[
          {'item_type': 'recipe', 'recipe_id': 1},
        ],
      },
    ]);

    await tester.pumpWidget(_wrap(initial));
    await tester.pump();

    final cards = find.byType(Card);
    expect(cards, findsOneWidget);
    final heightBefore = tester.getSize(cards.first).height;
    expect(heightBefore, 76.0);
    expect(find.text('Plan'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CircleAvatar),
        matching: find.text('Meal'),
      ),
      findsOneWidget,
    );
    expect(find.text('Meal'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Meal').last).dy,
      greaterThan(tester.getTopLeft(find.text('Plan')).dy),
    );
    expect(find.textContaining('Calories'), findsNothing);
    expect(find.textContaining('Protein'), findsNothing);
    expect(find.textContaining('Fat'), findsNothing);
    expect(find.textContaining('Carbs'), findsNothing);
    expect(find.textContaining('1 item'), findsNothing);
    expect(find.text('--'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-cost-sparkline')),
      findsOneWidget,
    );
    expect(find.byTooltip('Set as today'), findsOneWidget);

    final loaded = initial.copyWith(
      totals: {
        1: {
          'cost': 12.5,
          'currency': 'CNY',
          'calories': 300,
          'protein_g': 10,
          'fat_g': 4,
        },
      },
      trends: {
        1: <double>[1, 2, 3, 4],
      },
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_wrap(loaded));
    await tester.pump();

    expect(tester.getSize(find.byType(Card).first).height, heightBefore);
    expect(find.textContaining('12.5'), findsOneWidget);
  });
}
