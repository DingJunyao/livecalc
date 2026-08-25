import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/recipes/models/recipe_detail.dart';
import 'package:com_a4ding_livecalc/features/recipes/widgets/merchant_price_matrix.dart';
import 'package:com_a4ding_livecalc/features/recipes/repositories/recipe_repository.dart';

void main() {
  group('buildMatrixRows', () {
    test('total_cost 优先、缺失显示占位', () {
      final rows = buildMatrixRows(
        ingredients: const [
          RecipeIngredient(
              id: 10, ingredientId: 5, name: '鸡蛋', quantity: '100', unit: 'g'),
          RecipeIngredient(
              id: 11, ingredientId: 6, name: '番茄', quantity: '200', unit: 'g'),
        ],
        prices: const [
          MerchantPriceItem(
            recipeIngredientId: 10,
            ingredientId: 5,
            ingredientName: '鸡蛋',
            prices: [
              MerchantPriceRecord(
                  merchantId: 1,
                  merchantName: '盒马',
                  price: 3.0,
                  totalCost: 3.5,
                  isLowest: true),
              MerchantPriceRecord(
                  merchantId: 2, merchantName: '永辉', price: 3.2),
            ],
          ),
        ],
      );
      expect(rows.length, 2);
      final row0 = rows.first;
      expect(row0.name, '鸡蛋');
      // 盒马显示 total_cost 3.50 且最低价（带币种符号前缀，对齐 9337a66 币种显示）
      expect(row0.cells['盒马']!.display, '¥3.50');
      expect(row0.cells['盒马']!.isLowest, true);
      // 永辉回退 price 3.20
      expect(row0.cells['永辉']!.display, '¥3.20');
      expect(row0.cells['永辉']!.isLowest, false);
      // 番茄两商家都缺失
      expect(rows.last.cells['盒马']!.display, '—');
      expect(rows.last.cells['永辉']!.display, '—');
      expect(rows.last.cells['永辉']!.hasPrice, false);
    });

    test('quantityRange 食材显示范围用量', () {
      final rows = buildMatrixRows(
        ingredients: const [
          RecipeIngredient(
              id: 12,
              ingredientId: 7,
              name: '土豆',
              quantityRange: QuantityRange(min: 100, max: 200),
              unit: 'g'),
        ],
        prices: const [],
      );
      // 对齐 Web 端 MerchantPriceMatrix.vue:137「100-200 g」（数字与单位间空格）
      expect(rows.single.quantityDisplay, '100-200 g');
    });

    test('空 merchantName 回退商家 id 列标签', () {
      final rows = buildMatrixRows(
        ingredients: const [
          RecipeIngredient(
              id: 10, ingredientId: 5, name: '鸡蛋', quantity: '100', unit: 'g'),
        ],
        prices: const [
          MerchantPriceItem(
            recipeIngredientId: 10,
            ingredientId: 5,
            ingredientName: '鸡蛋',
            prices: [
              MerchantPriceRecord(merchantId: 9, merchantName: '', price: 1.0),
            ],
          ),
        ],
      );
      expect(rows.single.cells.containsKey('商家9'), isTrue);
      expect(rows.single.cells['商家9']!.display, '¥1.00');
    });
  });

  group('MerchantPriceMatrix', () {
    testWidgets('渲染矩阵：¥ 前缀显示 total_cost', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MerchantPriceMatrix(
            ingredients: [
              RecipeIngredient(
                  id: 10,
                  ingredientId: 5,
                  name: '鸡蛋',
                  quantity: '100',
                  unit: 'g'),
            ],
            prices: [
              MerchantPriceItem(
                recipeIngredientId: 10,
                ingredientId: 5,
                ingredientName: '鸡蛋',
                prices: [
                  MerchantPriceRecord(
                      merchantId: 1,
                      merchantName: '盒马',
                      price: 3.0,
                      totalCost: 3.5,
                      isLowest: true),
                ],
              ),
            ],
          ),
        ),
      ));
      // ¥ 是前缀而非后缀（web .vue:46 与 Task 8 一致）
      expect(find.text('¥3.50'), findsOneWidget);
      expect(find.text('盒马'), findsOneWidget);
      expect(find.text('鸡蛋'), findsOneWidget);
      // 用量显示在食材列（web .vue:31 qty-badge「100 g」灰色小字，数字与单位间空格）
      expect(find.text('100 g'), findsOneWidget);
    });

    testWidgets('食材/用量列冻结：横向滚动时首列不动', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MerchantPriceMatrix(
            ingredients: const [
              RecipeIngredient(
                  id: 10,
                  ingredientId: 5,
                  name: '鸡蛋',
                  quantity: '100',
                  unit: 'g'),
            ],
            prices: [
              MerchantPriceItem(
                recipeIngredientId: 10,
                ingredientId: 5,
                ingredientName: '鸡蛋',
                prices: [
                  for (var i = 1; i <= 8; i++)
                    MerchantPriceRecord(
                        merchantId: i, merchantName: '商家$i', price: 3.0 + i),
                ],
              ),
            ],
            loading: false,
          ),
        ),
      ));
      // 冻结列结构：食材名不在水平滚动区内
      final scrollableFinder = find.descendant(
        of: find.byType(MerchantPriceMatrix),
        matching: find.byType(Scrollable),
      );
      expect(
        find.descendant(of: scrollableFinder, matching: find.text('鸡蛋')),
        findsNothing,
      );
      // 滚动商家表后冻结列文本位置不变
      final posBefore = tester.getTopLeft(find.text('鸡蛋'));
      final position = tester.state<ScrollableState>(scrollableFinder).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(tester.getTopLeft(find.text('鸡蛋')), posBefore);
      expect(find.text('¥11.00'), findsOneWidget); // 最右商家（商家8）已滚入
    });

    testWidgets('fallback 链点击信息图标弹出弹窗', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MerchantPriceMatrix(
            ingredients: [
              RecipeIngredient(
                  id: 10,
                  ingredientId: 5,
                  name: '鸡蛋',
                  quantity: '100',
                  unit: 'g'),
            ],
            prices: [
              MerchantPriceItem(
                recipeIngredientId: 10,
                ingredientId: 5,
                ingredientName: '鸡蛋',
                fallbackChain: '盐 → 海盐',
                prices: [
                  MerchantPriceRecord(
                      merchantId: 1, merchantName: '盒马', price: 3.0),
                ],
              ),
            ],
          ),
        ),
      ));
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.text('根据以下食材计算价格：'), findsOneWidget);
      expect(find.text('盐 → 海盐'), findsOneWidget);
      // 关闭弹窗
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      expect(find.text('根据以下食材计算价格：'), findsNothing);
    });

    testWidgets('表头垂直居中（与数据行间隔一行行高）', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MerchantPriceMatrix(
            ingredients: [
              RecipeIngredient(
                  id: 10,
                  ingredientId: 5,
                  name: '鸡蛋',
                  quantity: '100',
                  unit: 'g'),
            ],
            prices: [
              MerchantPriceItem(
                recipeIngredientId: 10,
                ingredientId: 5,
                ingredientName: '鸡蛋',
                prices: [
                  MerchantPriceRecord(
                      merchantId: 1, merchantName: '商家1', price: 3.1),
                  MerchantPriceRecord(
                      merchantId: 2, merchantName: '商家2', price: 4.2),
                ],
              ),
            ],
            loading: false,
          ),
        ),
      ));
      // 视觉中心 = 字符 paint box 的中心（getBoxesForSelection 返回相对
      // RenderParagraph 的局部坐标，须加 box 顶部全局偏移）。不能用 getCenter：
      // SizedBox 的 tight 约束会把 Text 的 box 撑满整行高（44），box 中心恒等于
      // 行中心，顶对齐时（文本 paint 在顶部）getCenter 仍是假绿。
      double paintCenter(Finder f) {
        final para = tester.renderObject<RenderParagraph>(f);
        final boxes = para.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 1));
        return tester.getTopLeft(f).dy +
            (boxes.first.top + boxes.first.bottom) / 2;
      }

      // 表头若顶对齐（当前实现），视觉中心比居中时上移 ~14px：
      // 与数据行视觉中心的间距 ~58 vs 居中时的 44（一行行高）
      final headerTop = paintCenter(find.text('商家1'));
      final dataTop = paintCenter(find.text('¥3.10'));
      expect(dataTop - headerTop, closeTo(44, 2));
    });

    testWidgets('空数据显示空态', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body:
              MerchantPriceMatrix(ingredients: [], prices: [], loading: false),
        ),
      ));
      expect(find.text('暂无比价数据'), findsOneWidget);
    });

    testWidgets('鼠标滚轮可水平滚动比价矩阵', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MerchantPriceMatrix(
            ingredients: const [
              RecipeIngredient(
                  id: 10,
                  ingredientId: 5,
                  name: '鸡蛋',
                  quantity: '100',
                  unit: 'g'),
            ],
            prices: [
              MerchantPriceItem(
                recipeIngredientId: 10,
                ingredientId: 5,
                ingredientName: '鸡蛋',
                prices: [
                  for (var i = 1; i <= 8; i++)
                    MerchantPriceRecord(
                        merchantId: i, merchantName: '商家$i', price: 3.0 + i),
                ],
              ),
            ],
            loading: false,
          ),
        ),
      ));
      // 8 商家 + 食材列 = 9 列 × 110px > 800 测试视口，横向必然溢出
      final scrollableFinder = find.descendant(
        of: find.byType(MerchantPriceMatrix),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollableFinder).position;
      expect(position.pixels, 0);
      // 桌面鼠标滚轮（dy）应映射为水平滚动。
      // hover 必须在表格区域内（Scaffold 拉满全屏，组件中心在表格下方空白）。
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
          pointer.hover(tester.getCenter(find.byType(SingleChildScrollView))));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      await tester.pump();
      expect(position.pixels, greaterThan(0));
    });
  });
}
