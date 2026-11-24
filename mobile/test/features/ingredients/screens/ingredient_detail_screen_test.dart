import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/providers/ingredient_provider.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/ingredients/screens/ingredient_detail_screen.dart';
import 'package:com_a4ding_livecalc/features/ingredients/widgets/hierarchy_graph.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/models/price_record.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/models/hierarchy_relation.dart';

class _FakeIngredientDetailNotifier extends IngredientDetailPageNotifier {
  _FakeIngredientDetailNotifier(super.id, {this.records = const []});

  final List<PriceRecord> records;

  @override
  Future<void> load({int initialDays = 30, int? regionId}) async {
    state = const IngredientDetailPageState(
      ingredient: Ingredient(id: 8, name: '番茄'),
      hierarchy: IngredientHierarchyData(
        childRelations: [
          HierarchyRelation(
            id: 1,
            parentId: 8,
            parentName: '番茄',
            childId: 9,
            childName: '圣女果',
            relationType: 'substitutable',
          ),
        ],
      ),
    );
    if (records.isNotEmpty) {
      state = state.copyWith(records: records);
    }
  }
}

class _FakeMerchantRepository extends MerchantRepository {
  @override
  Future<MerchantPage> search({
    String? search,
    bool includeClosed = false,
    bool noPrice = false,
    bool includeOtherRegions = false,
    int skip = 0,
    int limit = 20,
  }) async {
    return const MerchantPage(items: [], total: 0);
  }
}

void main() {
  testWidgets('ingredient detail embeds the hierarchy graph', (tester) async {
    // 单位与密度卡内新增「关联与换算」后，层级卡初始位置更靠下；
    // 加高视口，确保层级图在首屏被构建（与真实滚动一致）。
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ingredientDetailPageProvider.overrideWith(
            (ref, id) => _FakeIngredientDetailNotifier(id),
          ),
          merchantListProvider.overrideWith(
            (ref) => MerchantListNotifier(_FakeMerchantRepository()),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: IngredientDetailScreen(id: 8),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HierarchyGraph), findsOneWidget);
    expect(find.text('Hierarchy'), findsOneWidget);
    expect(find.text('番茄'), findsAtLeastNWidgets(1));
  });

  testWidgets('ingredient records keep native currency and show conversion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ingredientDetailPageProvider.overrideWith(
            (ref, id) => _FakeIngredientDetailNotifier(
              id,
              records: [
                const PriceRecord(
                  id: 1,
                  productId: 10,
                  productName: 'Cabbage',
                  price: 1250,
                  quantity: 1,
                  unit: '颗',
                  currency: 'IDR',
                  exchangeRate: 0.1,
                  recordedAt: '2026-10-18T00:00:00Z',
                ),
              ],
            ),
          ),
          merchantListProvider.overrideWith(
            (ref) => MerchantListNotifier(_FakeMerchantRepository()),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: IngredientDetailScreen(id: 8),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1,250 IDR'), findsOneWidget);
    expect(find.textContaining('125 CNY'), findsOneWidget);
    expect(find.textContaining('1,250 CNY'), findsNothing);
  });

  testWidgets('展开竖屏（669×951，内容宽 637）双列布局不溢出', (tester) async {
    tester.view.physicalSize = const Size(669, 951);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ingredientDetailPageProvider.overrideWith(
            (ref, id) => _FakeIngredientDetailNotifier(id),
          ),
          merchantListProvider.overrideWith(
            (ref) => MerchantListNotifier(_FakeMerchantRepository()),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: IngredientDetailScreen(id: 8),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 溢出会以异常形式抛给测试框架：无异常即通过
    expect(tester.takeException(), isNull);
    // 不分栏：基本信息在上、最新价格在下（用户定调：详情页只在展开横屏分栏）
    final basic = tester.getRect(find.text('基本信息').first);
    final latest = tester.getRect(find.text('最新价格').first);
    expect(latest.top, greaterThan(basic.bottom));
    expect(tester.takeException(), isNull);
  });
}
