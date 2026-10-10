import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_form_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

class _FakeProductRepository extends ProductRepository {}

class _LatencyIngredientRepository extends IngredientRepository {
  _LatencyIngredientRepository(this.items, {this.latency = Duration.zero});

  final List<Ingredient> items;
  final Duration latency;
  final List<String> searchLog = [];

  @override
  Future<IngredientPage> search({
    String? search,
    List<int>? categoryIds,
    List<String>? conditions,
    int skip = 0,
    int limit = 20,
    String sortBy = 'price_records',
  }) async {
    searchLog.add(search ?? '');
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    final q = (search ?? '').trim().toLowerCase();
    final filtered = items
        .where((i) => q.isEmpty || i.name.toLowerCase().contains(q))
        .toList();
    return IngredientPage(items: filtered, total: filtered.length);
  }
}

const _milkLikeIngredients = [
  Ingredient(id: 81, name: '牛奶'),
  Ingredient(id: 305, name: '全脂牛奶'),
];

Future<ProductFormScreen> buildScreen(
  WidgetTester tester,
  IngredientRepository ingredientRepo,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return ProductFormScreen(
    repository: _FakeProductRepository(),
    ingredientRepository: ingredientRepo,
  );
}

Future<void> pumpApp(WidgetTester tester, ProductFormScreen screen) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: screen,
  ));
  await tester.pumpAndSettle();
}

Finder get ingredientField => find.widgetWithText(
    TextField, 'Search and select a linked ingredient *');

void main() {  testWidgets('单次输入完整词「牛奶」应显示下拉项（复现：转圈结束后无内容）',
      (tester) async {
    final repo = _LatencyIngredientRepository(
      _milkLikeIngredients,
      latency: const Duration(milliseconds: 120),
    );
    await pumpApp(tester, await buildScreen(tester, repo));

    await tester.enterText(ingredientField, '牛奶');
    await tester.pump(const Duration(milliseconds: 60)); // 请求进行中
    await tester.pump(const Duration(milliseconds: 150)); // 响应到达

    expect(find.widgetWithText(ListTile, '牛奶'), findsWidgets,
        reason: '搜索「牛奶」返回 2 条结果时下拉必须显示');
  });

  testWidgets('逐字输入「牛」→「牛奶」应显示下拉项', (tester) async {
    final repo = _LatencyIngredientRepository(
      _milkLikeIngredients,
      latency: const Duration(milliseconds: 120),
    );
    await pumpApp(tester, await buildScreen(tester, repo));

    await tester.enterText(ingredientField, '牛');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.enterText(ingredientField, '牛奶');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.widgetWithText(ListTile, '牛奶'), findsWidgets,
        reason: '最后一次查询「牛奶」的结果应显示');
  });

  testWidgets('输入「牛」应显示下拉项（对照）', (tester) async {
    final repo = _LatencyIngredientRepository(
      [..._milkLikeIngredients, const Ingredient(id: 5, name: '牛肉')],
      latency: const Duration(milliseconds: 120),
    );
    await pumpApp(tester, await buildScreen(tester, repo));

    await tester.enterText(ingredientField, '牛');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.widgetWithText(ListTile, '牛奶'), findsWidgets);
  });

  testWidgets('模拟中文 IME：拼音组合文本逐键更新后提交「牛奶」应显示下拉项',
      (tester) async {
    final repo = _LatencyIngredientRepository(
      _milkLikeIngredients,
      latency: const Duration(milliseconds: 80),
    );
    await pumpApp(tester, await buildScreen(tester, repo));

    // 先聚焦输入框，建立 IME 连接（真机上点击输入框）
    await tester.tap(ingredientField);
    await tester.pump();

    // 真机拼音 IME：组合文本逐键变化（ASCII，查询均返回空），最后提交汉字
    for (final composing in ['n', 'ni', 'niu', 'niun', 'niuna', 'niunai']) {
      tester.testTextInput.updateEditingValue(TextEditingValue(
        text: composing,
        selection: TextSelection.collapsed(offset: composing.length),
        composing: TextRange(start: 0, end: composing.length),
      ));
      await tester.pump(const Duration(milliseconds: 30));
    }
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '牛奶',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 0, end: 2),
    ));
    await tester.pump(const Duration(milliseconds: 120)); // 之前的空结果陆续返回
    await tester.pump(const Duration(milliseconds: 120)); // 「牛奶」响应到达

    expect(find.widgetWithText(ListTile, '牛奶'), findsWidgets,
        reason: 'IME 组合输入后提交「牛奶」，最后一次查询的结果应显示');
  });
}
