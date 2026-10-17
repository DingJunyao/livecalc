import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/planner/screens/planner_screens.dart';
import 'package:com_a4ding_livecalc/features/planner/widgets/cost_trend_chart.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/providers/calc_context_provider.dart';

class _PlannerApiAdapter implements HttpClientAdapter {
  _PlannerApiAdapter({this.kind = 'meal'});

  final String kind;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path == '/meal-plans/1') {
      return _json({
        'id': 1,
        'name': 'Breakfast plan',
        'kind': kind,
        'items': [
          {
            'item_type': 'recipe',
            'recipe_id': 11,
            'ingredient_id': null,
            'product_id': null,
            'servings': 2,
            'quantity': null,
            'group': kind == 'day' ? 'other' : 'dinner',
            'unit_id': null,
            'name': 'Eggs',
          },
          {
            'item_type': 'ingredient',
            'recipe_id': null,
            'ingredient_id': 12,
            'product_id': null,
            'servings': null,
            'quantity': 150,
            'group': kind == 'day' ? 'other' : 'dinner',
            'unit_id': null,
            'name': 'Rice',
          },
          {
            'item_type': 'product',
            'recipe_id': null,
            'ingredient_id': null,
            'product_id': 13,
            'servings': null,
            'quantity': 80,
            'group': kind == 'day' ? 'other' : 'dinner',
            'unit_id': null,
            'name': 'Milk',
          },
        ],
      });
    }
    if (path == '/units/') {
      return _json({
        'items': [
          {'id': 101, 'name': 'gram', 'abbreviation': 'g', 'is_active': true},
          {'id': 102, 'name': 'box', 'abbreviation': 'box', 'is_active': true},
          {'id': 103, 'name': '袋', 'abbreviation': '袋', 'is_active': true},
        ],
      });
    }
    if (path == '/meal-plans/evaluate') {
      return _json({
        'totals': {'cost': 0},
        'targets': {},
        'items': [
          {'unit': 'serving'},
          {'unit': 'g'},
          {'unit': 'box'},
        ],
      });
    }
    if (path.contains('/cost-trend')) {
      return _json(<dynamic>[]);
    }
    if (path == '/recipes' && options.method == 'GET') {
      return _json({'items': [], 'total': 0});
    }
    if (path == '/ingredients' && options.method == 'GET') {
      return _json({
        'items': [
          {
            'id': 12,
            'name': 'Rice',
            'default_unit': 'g',
          },
        ],
        'total': 1,
      });
    }
    if (path == '/products/entity' && options.method == 'GET') {
      return _json({
        'items': [
          {'id': 13, 'name': 'Ham', 'ingredient_id': 12},
        ],
        'total': 1,
      });
    }
    if (path == '/entities/product/13/units') {
      return _json({
        'items': [
          {
            'id': 268,
            'unit_name': '袋',
            'is_default': true,
            'is_active': true,
          },
        ],
      });
    }
    if (path == '/meal-plans' && options.method == 'POST') {
      return _json({'id': 42, 'name': 'New plan', 'items': []});
    }
    return ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _json(Object? data) => ResponseBody.fromString(
        jsonEncode(data),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
}

GoRouter _router({Map<String, dynamic>? plan}) => GoRouter(
      initialLocation: '/plans/edit',
      routes: [
        GoRoute(
          path: '/plans/edit',
          builder: (_, __) => PlannerEditScreen(plan: plan),
        ),
        GoRoute(
          path: '/plans/:id',
          builder: (_, __) => const Scaffold(body: Text('PLAN_DETAIL')),
        ),
      ],
    );

Widget _wrap({required GoRouter router}) => ProviderScope(
      overrides: [
        displayCurrencyProvider.overrideWithValue('CNY'),
      ],
      child: MaterialApp.router(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );

void main() {
  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter.close();
  });

  testWidgets('enables save immediately after entering a new plan name',
      (tester) async {
    await tester.pumpWidget(_wrap(router: _router()));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'New plan');
    await tester.pump();

    final saveButton = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byIcon(Icons.save),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('plan editor omits trend and exposes numeric item quantities',
      (tester) async {
    final previousAdapter = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.interceptors.clear();
    ApiClient.instance.dio.httpClientAdapter = _PlannerApiAdapter();
    addTearDown(() {
      ApiClient.instance.dio.httpClientAdapter = previousAdapter;
    });

    await tester.pumpWidget(
      _wrap(router: _router(plan: {'id': 1})),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CostTrendChart), findsNothing);
    expect(find.widgetWithText(TextField, '2'), findsOneWidget);
    expect(find.widgetWithText(TextField, '150'), findsOneWidget);
    expect(find.widgetWithText(TextField, '80'), findsOneWidget);
    expect(find.byType(DropdownButton<int>), findsNWidgets(2));
    expect(find.byTooltip('Decrease quantity'), findsNothing);
    expect(find.byTooltip('Increase quantity'), findsNothing);
  });

  testWidgets('new plans load units and adding an ingredient shows one',
      (tester) async {
    final previousAdapter = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.interceptors.clear();
    ApiClient.instance.dio.httpClientAdapter = _PlannerApiAdapter();
    addTearDown(() {
      ApiClient.instance.dio.httpClientAdapter = previousAdapter;
    });

    await tester.pumpWidget(_wrap(router: _router()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingredient'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();

    expect(find.text('Added — adjust in the list'), findsNothing);
    expect(find.byType(DropdownButton<int>), findsOneWidget);
  });

  testWidgets('adding a product applies its maintenance-price default unit',
      (tester) async {
    final previousAdapter = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.interceptors.clear();
    ApiClient.instance.dio.httpClientAdapter = _PlannerApiAdapter();
    addTearDown(() {
      ApiClient.instance.dio.httpClientAdapter = previousAdapter;
    });

    await tester.pumpWidget(_wrap(router: _router()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ham'));
    await tester.pumpAndSettle();

    final unitDropdown = find.byType(DropdownButton<int>);
    expect(unitDropdown, findsOneWidget);
    expect(
      tester.widget<DropdownButton<int>>(unitDropdown.first).value,
      103,
    );
  });

  testWidgets('day plans expose a meal group selector for every item',
      (tester) async {
    final previousAdapter = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.interceptors.clear();
    ApiClient.instance.dio.httpClientAdapter = _PlannerApiAdapter(kind: 'day');
    addTearDown(() {
      ApiClient.instance.dio.httpClientAdapter = previousAdapter;
    });

    await tester.pumpWidget(
      _wrap(router: _router(plan: {'id': 1})),
    );
    await tester.pumpAndSettle();

    final groupDropdowns = find.byType(DropdownButton<String>);
    expect(groupDropdowns, findsNWidgets(3));

    final onChanged =
        tester.widget<DropdownButton<String>>(groupDropdowns.first).onChanged!;
    onChanged('breakfast');
    await tester.pumpAndSettle();

    expect(
      tester.widget<DropdownButton<String>>(groupDropdowns.first).value,
      'breakfast',
    );
  });

  testWidgets('add entry opens one tabbed drawer', (tester) async {
    final previousAdapter = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.interceptors.clear();
    ApiClient.instance.dio.httpClientAdapter = _PlannerApiAdapter();
    addTearDown(() {
      ApiClient.instance.dio.httpClientAdapter = previousAdapter;
    });

    await tester.pumpWidget(_wrap(router: _router()));
    await tester.pumpAndSettle();

    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Recipe'), findsOneWidget);
    expect(find.text('Ingredient'), findsOneWidget);
    expect(find.text('Product'), findsOneWidget);
  });

  testWidgets('saving a new plan navigates to its detail', (tester) async {
    final previousAdapter = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.interceptors.clear();
    ApiClient.instance.dio.httpClientAdapter = _PlannerApiAdapter();
    addTearDown(() {
      ApiClient.instance.dio.httpClientAdapter = previousAdapter;
    });

    final router = _router();
    await tester.pumpWidget(_wrap(router: router));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'New plan');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.save));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('PLAN_DETAIL'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/plans/42');
  });
}
