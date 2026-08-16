import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_form_screen.dart';
import 'package:com_a4ding_livecalc/shared/widgets/alias_tags_field.dart';

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository(this.existing);

  final Product existing;
  String? lastCreatedName;
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
    lastCreatedAliases = aliases;
    return Product(id: 1, name: name);
  }

  @override
  Future<Product> updateProduct(
    int id, {
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
    return existing;
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
}
