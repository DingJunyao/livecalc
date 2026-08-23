import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/products/models/barcode_lookup.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_form_screen.dart';
import 'package:com_a4ding_livecalc/features/nutrition/models/usda_models.dart';
import 'package:com_a4ding_livecalc/shared/widgets/alias_tags_field.dart';
import 'package:com_a4ding_livecalc/shared/widgets/loading_overlay.dart';

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository(this.existing);

  final Product existing;
  String? lastCreatedName;
  int? lastCreatedIngredientId;
  List<String>? lastCreatedAliases;
  String? lastName;
  List<String>? lastAliases;
  List<String>? lastTags;

  @override
  Future<Product> getProduct(int id) async => existing;

  @override
  Future<Product> createProduct({
    required String name,
    required int ingredientId,
    String? brand,
    String? barcode,
    List<String> aliases = const [],
    List<String> tags = const [],
  }) async {
    lastCreatedName = name;
    lastCreatedIngredientId = ingredientId;
    lastCreatedAliases = aliases;
    return Product(id: 1, name: name);
  }

  @override
  Future<ProductMutationResult> updateProduct(
    int id, {
    required bool isAdmin,
    String? name,
    int? ingredientId,
    String? brand,
    String? barcode,
    List<String>? aliases,
    List<String>? tags,
  }) async {
    lastName = name;
    lastAliases = aliases;
    lastTags = tags;
    return ProductMutationResult(
      product: existing,
      review: const MutationReviewResult(
        applied: true,
        pending: false,
        message: '',
        raw: {},
      ),
    );
  }
}

class _ScanLookupRepository extends ProductRepository {
  _ScanLookupRepository(this.completer);

  final Completer<BarcodeLookupResult> completer;

  @override
  Future<BarcodeLookupResult> lookupBarcode(String barcode) {
    return completer.future;
  }
}

class _FakeIngredientRepository extends IngredientRepository {
  _FakeIngredientRepository(this.items);

  final List<Ingredient> items;
  String? lastSearch;

  @override
  Future<IngredientPage> search({
    String? search,
    List<int>? categoryIds,
    List<String>? conditions,
    int skip = 0,
    int limit = 20,
    String sortBy = 'price_records',
  }) async {
    lastSearch = search;
    final q = (search ?? '').trim().toLowerCase();
    final filtered = items
        .where((i) => q.isEmpty || i.name.toLowerCase().contains(q))
        .toList();
    return IngredientPage(items: filtered, total: filtered.length);
  }
}

void main() {
  Future<void> useTallViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('新增商品是全屏页面，别名不再按分隔符拆分', (tester) async {
    await useTallViewport(tester);
    const ingredient = Ingredient(id: 8, name: '面粉');
    final repo = _FakeProductRepository(const Product(id: 0, name: ''));
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductFormScreen(
                fixedIngredient: ingredient,
                repository: repo,
              ),
            ),
          ),
          child: const Text('打开'),
        ),
      ),
    ));

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppBar, '添加商品'), findsOneWidget);
    expect(find.text('面粉'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '商品名称 *'),
      '高筋粉',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, '别名'),
      '面包粉, 高粉',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AliasTagsField),
        matching: find.byIcon(Icons.add),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repo.lastCreatedName, '高筋粉');
    expect(repo.lastCreatedAliases, ['面包粉, 高粉']);
  });

  testWidgets('编辑商品加载现有数据并保留含空格别名', (tester) async {
    await useTallViewport(tester);
    final repo = _FakeProductRepository(const Product(
      id: 12,
      name: '低筋粉',
      ingredientId: 8,
      ingredientName: '面粉',
      aliases: ['蛋糕粉'],
      tags: ['烘焙'],
    ));
    await tester.pumpWidget(MaterialApp(
      home: ProductFormScreen(
        product: const Product(id: 12, name: '低筋粉'),
        repository: repo,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '编辑商品'), findsOneWidget);
    expect(find.text('蛋糕粉'), findsOneWidget);
    expect(find.text('烘焙'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '别名'),
      '低 粉',
    );
    await tester.tap(
      find
          .descendant(
            of: find.byType(AliasTagsField),
            matching: find.byIcon(Icons.add),
          )
          .first,
    );
    await tester.pump();
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repo.lastName, '低筋粉');
    expect(repo.lastAliases, ['蛋糕粉', '低 粉']);
    expect(repo.lastTags, ['烘焙']);
  });

  testWidgets('扫码后查询商品信息期间显示加载覆盖层', (tester) async {
    await useTallViewport(tester);
    final lookupCompleter = Completer<BarcodeLookupResult>();
    final repo = _ScanLookupRepository(lookupCompleter);
    await tester.pumpWidget(MaterialApp(
      home: ProductFormScreen(
        fixedIngredient: const Ingredient(id: 8, name: '面粉'),
        repository: repo,
        scanner: (_) async => '6901234567890',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.barcode_reader));
    await tester.tap(find.byIcon(Icons.barcode_reader));
    await tester.pump();

    // 查询进行中：显示加载覆盖层
    expect(find.byType(LoadingOverlay), findsOneWidget);
    expect(find.text('正在查询商品信息…'), findsOneWidget);

    // 查询完成：覆盖层消失
    lookupCompleter.complete(
      const BarcodeLookupResult(found: false, hasEnabledProviders: true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoadingOverlay), findsNothing);
  });

  testWidgets('关联原料为下拉带输入，可搜索并选择一项', (tester) async {
    await useTallViewport(tester);
    final repo = _FakeProductRepository(const Product(id: 0, name: ''));
    final ingredientRepo = _FakeIngredientRepository(const [
      Ingredient(id: 1, name: '面粉', category: '谷物'),
      Ingredient(id: 2, name: '砂糖', category: '调味'),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: ProductFormScreen(
        repository: repo,
        ingredientRepository: ingredientRepo,
      ),
    ));
    await tester.pumpAndSettle();

    // 下拉带输入：非 tag/Chip 形式
    final ingredientField = find.widgetWithText(TextField, '搜索并选择关联原料 *');
    expect(ingredientField, findsOneWidget);
    expect(find.byType(Chip), findsNothing);

    await tester.enterText(ingredientField, '面');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(ingredientRepo.lastSearch, '面');
    expect(find.text('面粉'), findsWidgets);
    expect(find.text('砂糖'), findsNothing);

    // 从下拉中选择一项
    await tester.tap(find.text('面粉').last);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(ingredientField);
    expect(field.controller?.text, '面粉');
    expect(find.byType(Chip), findsNothing);

    // 保存携带选中的 ingredientId
    await tester.enterText(
      find.widgetWithText(TextFormField, '商品名称 *'),
      '高筋粉',
    );
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repo.lastCreatedName, '高筋粉');
    expect(repo.lastCreatedIngredientId, 1);
  });
}
