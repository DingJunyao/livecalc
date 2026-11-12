import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_form_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeProductRepository extends ProductRepository {}

/// 记录创建商品时携带的关联原料 id（回声用例断言保存成功且原料未被清空）。
class _RecordingProductRepository extends ProductRepository {
  int? createdIngredientId;

  @override
  Future<Product> createProduct({
    required String name,
    required int ingredientId,
    String? brand,
    String? barcode,
    List<String> aliases = const [],
    List<String> tags = const [],
  }) async {
    createdIngredientId = ingredientId;
    return Product(id: 1, name: name);
  }
}

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
    bool favoritesOnly = false,
    bool favoritesFirst = false,
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
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: screen,
  )));
  await tester.pumpAndSettle();
}

/// 表单挂在导航栈上（而不是 home）：保存成功后的 pop 才有上一页可回。
Future<void> pumpLauncherApp(
  WidgetTester tester,
  IngredientRepository ingredientRepo,
  ProductRepository productRepo,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductFormScreen(
                repository: productRepo,
                ingredientRepository: ingredientRepo,
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  ));
  await tester.pump();
}

Finder get ingredientField => find.widgetWithText(
    TextField, 'Search and select a linked ingredient *');

void main() {
  testWidgets('duplicate composition text keeps the pending search future',
      (tester) async {
    final repo = _LatencyIngredientRepository(
      _milkLikeIngredients,
      latency: const Duration(milliseconds: 20),
    );
    await pumpApp(tester, await buildScreen(tester, repo));
    await tester.tap(ingredientField);
    await tester.pump();

    final milk = _milkLikeIngredients[0].name;
    tester.testTextInput.updateEditingValue(TextEditingValue(
      text: milk,
      selection: TextSelection.collapsed(offset: milk.length),
      composing: TextRange(start: 0, end: milk.length),
    ));
    await tester.pump(const Duration(milliseconds: 30));

    // IME finalization keeps the same text but clears the composing range.
    // A second optionsBuilder call with the same text must not restart the
    // search, otherwise the first (applicable) call is cancelled.
    tester.testTextInput.updateEditingValue(TextEditingValue(
      text: milk,
      selection: TextSelection.collapsed(offset: milk.length),
      composing: TextRange.empty,
    ));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.widgetWithText(ListTile, milk), findsWidgets);
  });

  testWidgets('IME composition queries are debounced to the final keyword',
      (tester) async {
    final repo = _LatencyIngredientRepository(
      _milkLikeIngredients,
      latency: const Duration(milliseconds: 20),
    );
    await pumpApp(tester, await buildScreen(tester, repo));
    await tester.tap(ingredientField);
    await tester.pump();

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
    await tester.pump(const Duration(milliseconds: 350));

    expect(repo.searchLog, ['牛奶'],
        reason: 'IME 组合期间的中间拼音不应逐键请求服务端');
    expect(find.widgetWithText(ListTile, '牛奶'), findsWidgets);
  });

  testWidgets('单次输入完整词「牛奶」应显示下拉项（复现：转圈结束后无内容）',
      (tester) async {
    final repo = _LatencyIngredientRepository(
      _milkLikeIngredients,
      latency: const Duration(milliseconds: 120),
    );
    await pumpApp(tester, await buildScreen(tester, repo));

    await tester.enterText(ingredientField, '牛奶');
    await tester.pump(const Duration(milliseconds: 60)); // 请求进行中
    await tester.pump(const Duration(milliseconds: 400)); // 响应到达

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
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

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
    await tester.pump(const Duration(milliseconds: 450));

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
    await tester.pump(const Duration(milliseconds: 220)); // 之前的空结果陆续返回
    await tester.pump(const Duration(milliseconds: 220)); // 「牛奶」响应到达

    expect(find.widgetWithText(ListTile, '牛奶'), findsWidgets,
        reason: 'IME 组合输入后提交「牛奶」，最后一次查询的结果应显示');
  });

  testWidgets('点选原料后的输入法回声不清空选择，保存成功', (tester) async {
    // 真机复现：点选下拉项后，输入法补发滞留的组合态/上屏回声，
    // 文本与所选原料名不一致 → onChanged 把刚选好的原料静默清空 →
    // 保存误报「请选择关联的原料」。选中即释放焦点后 IME 连接已关闭，
    // 回声在框架侧按失效 client 丢弃；保护窗口保留作纵深防御。
    // 两种机制下选择都必须完好、保存成功。
    final productRepo = _RecordingProductRepository();
    await pumpLauncherApp(
      tester,
      _LatencyIngredientRepository(_milkLikeIngredients),
      productRepo,
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(ingredientField, '牛奶');
    await tester.pump(const Duration(milliseconds: 400)); // 防抖 300ms + 搜索返回
    await tester.tap(find.widgetWithText(ListTile, '牛奶').first);
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      tester.widget<TextField>(ingredientField).focusNode?.hasFocus,
      isFalse,
      reason: '选中即释放焦点（对齐商家下拉，避免扫码/选日期返回下拉重现）',
    );

    // 回声 1：输入法补发组合态（文本带拼音尾巴，组合态未上屏）
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '牛奶n',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 2, end: 3),
    ));
    await tester.pump(const Duration(milliseconds: 30));
    // 回声 2：滞留拼音上屏提交（组合态已清，文本仍与所选原料名不一致）
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '牛奶牛',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange.empty,
    ));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product name *'),
      '鲜牛奶',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(productRepo.createdIngredientId, 81,
        reason: '回声不应清空刚点选的原料，保存必须带上 ingredient_id=81');
    expect(find.text('Open'), findsOneWidget, reason: '保存成功后应返回上一页');
  });

  testWidgets('保护窗口结束后的正常编辑仍会清空选择（对照）', (tester) async {
    final productRepo = _RecordingProductRepository();
    await pumpLauncherApp(
      tester,
      _LatencyIngredientRepository(_milkLikeIngredients),
      productRepo,
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(ingredientField, '牛奶');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(ListTile, '牛奶').first);
    // 等保护窗口（300ms）过期，再输入新关键词 → 应清空选择
    await tester.pump(const Duration(milliseconds: 400));
    // 选中即释放焦点后需重新聚焦（真机用户点输入框），IME 才重新接管
    await tester.tap(ingredientField);
    await tester.pump();
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '牛',
      selection: TextSelection.collapsed(offset: 1),
      composing: TextRange.empty,
    ));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product name *'),
      '鲜牛奶',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(productRepo.createdIngredientId, isNull, reason: '选择已清空，不应发起创建');
    expect(
      find.byType(SnackBar),
      findsOneWidget,
    );
    expect(find.textContaining('Select a linked ingredient'), findsOneWidget);
  });

  testWidgets('点选原料后释放焦点，避免扫码/选日期返回时下拉重现', (tester) async {
    // SDK 在重新获得焦点且 options 非空时会直接把面板重新弹出（不重跑
    // optionsBuilder）；本页有条码扫码，进出扫码页焦点恢复就会重现旧结果。
    final repo = _LatencyIngredientRepository(_milkLikeIngredients);
    await pumpApp(tester, await buildScreen(tester, repo));

    await tester.enterText(ingredientField, '牛奶');
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<TextField>(ingredientField).focusNode?.hasFocus,
      isTrue,
      reason: '输入时应持有焦点',
    );

    await tester.tap(find.widgetWithText(ListTile, '牛奶').first);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(ingredientField).focusNode?.hasFocus,
      isFalse,
    );
  });
}
