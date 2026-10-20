import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/recipes/utils/ingredient_colors.dart';
import 'package:com_a4ding_livecalc/features/planner/screens/plan_detail_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/providers/calc_context_provider.dart';

class _PlanDetailApiAdapter implements HttpClientAdapter {
  final Completer<ResponseBody> trendCompleter = Completer<ResponseBody>();

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
        'name': 'Trend plan',
        'kind': 'meal',
        'items': [
          {
            'item_type': 'recipe',
            'recipe_id': 11,
            'ingredient_id': null,
            'product_id': null,
            'servings': 1,
            'quantity': null,
            'unit_id': null,
            'group': 'dinner',
            'name': 'Recipe',
          },
        ],
      });
    }
    if (path == '/meal-plans/evaluate') {
      return _json({
        'totals': {'cost': 12, 'currency': 'CNY'},
        'targets': {},
        'items': [
          {
            'item_id': 77,
            'name': 'Recipe',
            'cost': 12,
            'unit': 'serving',
          },
        ],
        'nutrition': {
          'per_serving_nutrition': {
            'core_nutrients': {
              'protein': {
                'value': 10,
                'unit': 'g',
                'key': 'protein',
                'nrp_pct': 10,
              },
            },
          },
          'ingredient_details': [
            {
              'ingredient_id': 77,
              'ingredient_name': 'Recipe',
              'nutrition_contribution': {
                'protein': {'value': 10, 'unit': 'g'},
              },
            },
          ],
        },
      });
    }
    if (path == '/meal-plans/1/cost-trend') {
      return trendCompleter.future;
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

GoRouter _router() => GoRouter(
      initialLocation: '/plans/1',
      routes: [
        GoRoute(
          path: '/plans/:id',
          builder: (_, state) => PlanDetailScreen(
            planId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ],
    );

Widget _wrap(GoRouter router) => ProviderScope(
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

  testWidgets('shows cost trend spinner while trend is loading',
      (tester) async {
    final adapter = _PlanDetailApiAdapter();
    final previousAdapter = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.interceptors.clear();
    ApiClient.instance.dio.httpClientAdapter = adapter;
    addTearDown(() {
      if (!adapter.trendCompleter.isCompleted) {
        adapter.trendCompleter.completeError(Exception('cancelled'));
      }
      ApiClient.instance.dio.httpClientAdapter = previousAdapter;
    });

    await tester.pumpWidget(_wrap(_router()));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No nutrition data'), findsNothing);
    expect(find.text('No cost trend data'), findsNothing);

    adapter.trendCompleter.complete(
      ResponseBody.fromString(
        jsonEncode([
          {
            'date': '2026-10-16',
            'total_cost': 11,
            'min_cost': 10,
            'max_cost': 12,
            'avg_cost': 11,
            'currency': 'CNY',
          },
          {
            'date': '2026-10-17',
            'total_cost': 12,
            'min_cost': 11,
            'max_cost': 13,
            'avg_cost': 12,
            'currency': 'CNY',
          },
        ]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No nutrition data'), findsNothing);
  });

  testWidgets('cost share and nutrition source use the same item color',
      (tester) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final adapter = _PlanDetailApiAdapter();
    final previousAdapter = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.interceptors.clear();
    ApiClient.instance.dio.httpClientAdapter = adapter;
    addTearDown(() {
      if (!adapter.trendCompleter.isCompleted) {
        adapter.trendCompleter.completeError(Exception('cancelled'));
      }
      ApiClient.instance.dio.httpClientAdapter = previousAdapter;
    });

    await tester.pumpWidget(_wrap(_router()));
    adapter.trendCompleter.complete(
      ResponseBody.fromString(
        jsonEncode([]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    await tester.pumpAndSettle();

    List<Color> segmentColors(Key key) {
      final surface = Theme.of(tester.element(find.byKey(key).first))
          .colorScheme
          .surface;
      return tester
          .widgetList<ColoredBox>(find.descendant(
            of: find.byKey(key),
            matching: find.byType(ColoredBox),
          ))
          .where((widget) => widget.color != surface)
          .map((widget) => widget.color)
          .toList();
    }

    final costColors = segmentColors(const Key('cost_bar'));
    final nutritionColors = segmentColors(const Key('nrv_bar'));
    expect(costColors, [getIngredientColor(77)]);
    expect(nutritionColors, [getIngredientColor(77)]);
    expect(costColors.first, nutritionColors.first);
  });
}
