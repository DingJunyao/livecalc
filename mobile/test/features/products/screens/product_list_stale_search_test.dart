import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/providers/product_provider.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_list_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

class _FakeProductRepository extends ProductRepository {
  final searches = <String?>[];

  @override
  Future<ProductPage> search({
    String? search,
    int? ingredientId,
    List<int>? ingredientIds,
    List<int>? ingredientCategoryIds,
    List<String>? brands,
    List<String>? conditions,
    int skip = 0,
    int limit = 20,
    String sortBy = 'price_records',
    bool favoritesOnly = false,
    bool favoritesFirst = false,
  }) async {
    searches.add(search);
    const all = [Product(id: 1, name: '苹果'), Product(id: 2, name: '香蕉')];
    if (search == null || search.isEmpty) {
      return const ProductPage(items: all, total: 2);
    }
    final filtered = all.where((p) => p.name.contains(search)).toList();
    return ProductPage(items: filtered, total: filtered.length);
  }
}

void main() {
  testWidgets('重新进入商品列表页时，残留的搜索词会被清空并加载全部商品', (tester) async {
    final repository = _FakeProductRepository();
    final container = ProviderContainer(
      overrides: [
        productListProvider.overrideWith((ref) => ProductListNotifier(repository)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(productListProvider.notifier);
    // testWidgets 运行在 FakeAsync 里，debounce 的 Timer 不会自然到期，
    // 预热「上次搜索留下的状态」放到 runAsync 中执行真实延时。
    await tester.runAsync(() async {
      await notifier.load();
      notifier.setSearch('苹果');
      await Future<void>.delayed(const Duration(milliseconds: 450));
    });
    expect(notifier.state.searchQuery, '苹果');
    expect(notifier.state.items.map((p) => p.id), [1]);

    // 重新进入页面（新的 Screen 实例、输入框为空）
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProductListScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 关键词被清空，且按「无关键词」重新请求（不会再拿旧过滤结果）
    expect(notifier.state.searchQuery, '');
    expect(repository.searches.last, isNull);
    expect(notifier.state.items.length, 2);
  });
}
