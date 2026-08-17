import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/prices/models/price_record.dart';
import 'package:com_a4ding_livecalc/features/prices/repositories/price_repository.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/screens/paste_import_screen.dart';

/// 可控的 PriceRepository：按 productId 决定 createRecord 抛异常或成功。
class _FakePriceRepository extends PriceRepository {
  _FakePriceRepository({
    this.failProductIds = const {},
    this.productIdSeq,
  });

  /// 命中 productId 抛异常（existing 模式按此判断）
  final Set<int> failProductIds;

  /// 新建商品时分配的 productId（用于 new_same 响应）
  final int Function()? productIdSeq;

  int createCount = 0;
  final List<Map<String, dynamic>> createCalls = [];
  int aliasCount = 0;
  final List<({int productId, String name})> aliasCalls = [];

  @override
  Future<PriceRecord> createRecord({
    int? productId,
    String? productName,
    required double price,
    double quantity = 1,
    String unit = '个',
    int? merchantId,
    int? ingredientId,
    String recordType = 'purchase',
    String? notes,
    DateTime? recordedAt,
  }) async {
    createCount++;
    createCalls.add({
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'merchant_id': merchantId,
      'ingredient_id': ingredientId,
      'record_type': recordType,
      'recorded_at': recordedAt,
    });
    if (productId != null && failProductIds.contains(productId)) {
      throw Exception('导入失败: productId=$productId');
    }
    return PriceRecord.fromJson({
      'id': createCount,
      'product_id': productId ?? (productIdSeq?.call() ?? 0),
      'product_name': productName ?? '',
      'price': price,
      'original_quantity': quantity,
      'original_unit': unit,
      'record_type': recordType,
    });
  }

  @override
  Future<void> addImportAlias(int productId, String name) async {
    aliasCount++;
    aliasCalls.add((productId: productId, name: name));
  }
}

/// 可控的 ProductRepository：autocomplete 按查询名返回预设列表。
/// [delays] 可对特定 query 注入延迟（用于 I1 竞态测试）。
class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository(this.table, {this.delays = const {}});
  final Map<String, List<Map<String, dynamic>>> table;
  final Map<String, Duration> delays;

  @override
  Future<List<Map<String, dynamic>>> autocomplete(String q,
      {int limit = 20}) async {
    final d = delays[q];
    if (d != null) await Future.delayed(d);
    return table[q] ?? const [];
  }
}

/// 用 Navigator.push 宿主模拟进入页面，可捕获 pop 返回值。
class _Host extends StatefulWidget {
  final PasteImportScreen screen;
  const _Host({required this.screen});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  dynamic poppedResult;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              poppedResult = await Navigator.of(ctx).push<dynamic>(
                MaterialPageRoute(builder: (_) => widget.screen),
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );
  }
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required PasteImportScreen screen,
    Size size = const Size(900, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: _Host(screen: screen)));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('入口参数渲染：标题 + 复制模板按钮', (tester) async {
    await pumpScreen(
      tester,
      screen: PasteImportScreen(
        merchantId: 7,
        historyProductNames: const ['芹菜', '土豆'],
        priceRepository: _FakePriceRepository(),
        productRepository: _FakeProductRepository({}),
      ),
    );
    expect(find.text('粘贴导入价格'), findsOneWidget); // AppBar 标题
    expect(find.text('复制模板'), findsOneWidget);
    expect(find.byKey(const Key('paste-recorded-at-field')), findsOneWidget);

    final rawFieldFinder = find.byKey(const Key('paste-raw-text-field'));
    final rawField = tester.widget<TextField>(rawFieldFinder);
    expect(rawField.maxLines, 4);
    expect(rawField.minLines, 4);
    expect(
      find.text('粘贴价格文本\n（每行一条，格式：名称 价格[/单位]）'),
      findsOneWidget,
    );

    final initialSize = tester.getSize(rawFieldFinder);
    await tester.enterText(
      rawFieldFinder,
      List.filled(40, '商品 1').join('\n'),
    );
    await tester.pump();
    expect(tester.getSize(rawFieldFinder), initialSize);
  });

  testWidgets('复制模板写入剪贴板（每行商品名+空格）', (tester) async {
    String? captured;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          captured = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpScreen(
      tester,
      screen: PasteImportScreen(
        merchantId: 7,
        historyProductNames: const ['芹菜', '土豆'],
        priceRepository: _FakePriceRepository(),
        productRepository: _FakeProductRepository({}),
      ),
    );

    await tester.tap(find.text('复制模板'));
    await tester.pumpAndSettle();

    expect(captured, '芹菜 \n土豆 ');
  });

  testWidgets('解析并匹配：matched/unmatched/invalid 三态', (tester) async {
    final productRepo = _FakeProductRepository({
      '芹菜': [
        {'id': 1, 'name': '芹菜', 'match_type': 'name'}
      ],
      // '番茄' 不在表中 → unmatched
    });
    await pumpScreen(
      tester,
      screen: PasteImportScreen(
        merchantId: 7,
        historyProductNames: const [],
        priceRepository: _FakePriceRepository(),
        productRepository: productRepo,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('paste-raw-text-field')),
      '芹菜 1.88\n番茄 3\n坏数据',
    );
    await tester.tap(find.text('解析并匹配'));
    await tester.pumpAndSettle();

    // summary 文本三态计数正确
    expect(find.textContaining('已匹配 1'), findsOneWidget);
    expect(find.textContaining('待处理 1'), findsOneWidget);
    expect(find.textContaining('无法识别 1'), findsOneWidget);
  });

  testWidgets('导入成功：existing 模式 pop(savedIds) + 加别名 + recordType=price',
      (tester) async {
    final priceRepo = _FakePriceRepository();
    final productRepo = _FakeProductRepository({
      '芹菜': [
        {'id': 1, 'name': '芹菜', 'match_type': 'name'}
      ],
    });
    late final _HostState hostState;
    await pumpScreen(
      tester,
      screen: PasteImportScreen(
        merchantId: 7,
        historyProductNames: const [],
        priceRepository: priceRepo,
        productRepository: productRepo,
      ),
    );
    // push 后 _Host 在栈底（offstage），用 skipOffstage:false 才能定位
    hostState =
        tester.state(find.byType(_Host, skipOffstage: false)) as _HostState;

    await tester.enterText(
      find.byKey(const Key('paste-raw-text-field')),
      '芹菜 1.88',
    );
    await tester.tap(find.text('解析并匹配'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('paste-import-button')));
    await tester.pumpAndSettle();

    expect(priceRepo.createCount, 1);
    // 必须显式传 recordType='price'（默认是 purchase）
    expect(priceRepo.createCalls.single['record_type'], 'price');
    expect(priceRepo.createCalls.single['merchant_id'], 7);
    expect(priceRepo.createCalls.single['recorded_at'], isA<DateTime>());
    // existing 成功后加别名
    expect(priceRepo.aliasCount, 1);
    expect(priceRepo.aliasCalls.single, (productId: 1, name: '芹菜'));
    // 页面关闭 + pop 返回 savedIds 含 existing 的 productId
    expect(find.byType(PasteImportScreen), findsNothing);
    expect(hostState.poppedResult, isA<List<int>>());
    expect((hostState.poppedResult as List<int>), contains(1));
  });

  testWidgets('导入失败统计：成功的仍导入，失败计数正确，页面不关闭', (tester) async {
    // 「番茄」productId=2 → existing 模式按 productId 判定失败
    final priceRepo = _FakePriceRepository(failProductIds: {2});
    final productRepo = _FakeProductRepository({
      '芹菜': [
        {'id': 1, 'name': '芹菜', 'match_type': 'name'}
      ],
      '番茄': [
        {'id': 2, 'name': '番茄', 'match_type': 'name'}
      ],
    });
    await pumpScreen(
      tester,
      screen: PasteImportScreen(
        merchantId: 7,
        historyProductNames: const [],
        priceRepository: priceRepo,
        productRepository: productRepo,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('paste-raw-text-field')),
      '芹菜 1.88\n番茄 3',
    );
    await tester.tap(find.text('解析并匹配'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('paste-import-button')));
    await tester.pumpAndSettle();

    expect(priceRepo.createCount, 2); // 两条都尝试
    // 失败时页面不关闭
    expect(find.byType(PasteImportScreen), findsOneWidget);
    expect(find.textContaining('成功 1 条'), findsOneWidget);
    expect(find.textContaining('失败 1 条'), findsOneWidget);
  });

  testWidgets('new_same 模式：手动创建同名商品，不加别名', (tester) async {
    final priceRepo = _FakePriceRepository(productIdSeq: () => 88);
    final productRepo = _FakeProductRepository({}); // 全部 unmatched
    late final _HostState hostState;
    await pumpScreen(
      tester,
      screen: PasteImportScreen(
        merchantId: 7,
        historyProductNames: const [],
        priceRepository: priceRepo,
        productRepository: productRepo,
      ),
    );
    hostState =
        tester.state(find.byType(_Host, skipOffstage: false)) as _HostState;

    await tester.enterText(
      find.byKey(const Key('paste-raw-text-field')),
      '新菜 5',
    );
    await tester.tap(find.text('解析并匹配'));
    await tester.pumpAndSettle();

    // unmatched 行点商品名展开内联面板
    await tester.tap(find.text('新菜'));
    await tester.pumpAndSettle();
    final newSameButton = find.byKey(const Key('paste-new-same-button'));
    await tester.ensureVisible(newSameButton);
    await tester.pumpAndSettle();
    await tester.tap(newSameButton);
    await tester.pumpAndSettle();

    // 状态变 matched（导入按钮可见且计数为 1）
    expect(find.byKey(const Key('paste-import-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('paste-import-button')));
    await tester.pumpAndSettle();

    expect(priceRepo.createCount, 1);
    expect(priceRepo.createCalls.single['product_name'], '新菜');
    expect(priceRepo.createCalls.single['product_id'], isNull);
    // new_same 不加别名
    expect(priceRepo.aliasCount, 0);
    // pop 返回的 savedIds 含新建商品 id（来自 productIdSeq=88）
    expect(hostState.poppedResult, isA<List<int>>());
    expect((hostState.poppedResult as List<int>), contains(88));
  });

  testWidgets('unmatched 行手动关联已有商品（existing 分支）', (tester) async {
    final priceRepo = _FakePriceRepository();
    final productRepo = _FakeProductRepository({
      // 初始解析时无匹配 → unmatched
      // 展开后再次 autocomplete '青茄' → 返回商品
      '青茄': [
        {'id': 9, 'name': '青茄子', 'match_type': 'name'}
      ],
    });
    await pumpScreen(
      tester,
      screen: PasteImportScreen(
        merchantId: 7,
        historyProductNames: const [],
        priceRepository: priceRepo,
        productRepository: productRepo,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('paste-raw-text-field')),
      '青茄 2',
    );
    await tester.tap(find.text('解析并匹配'));
    await tester.pumpAndSettle();

    // 展开
    await tester.tap(find.text('青茄'));
    await tester.pumpAndSettle();

    // 在「关联已有商品」TextField 里输入并选中（ListTile 带 suggestion key）
    final existingField = find.byKey(const Key('paste-existing-search'));
    await tester.enterText(existingField, '青茄');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paste-suggestion-9')));
    await tester.pumpAndSettle();

    // 状态变 matched
    await tester.tap(find.byKey(const Key('paste-import-button')));
    await tester.pumpAndSettle();

    expect(priceRepo.createCount, 1);
    expect(priceRepo.createCalls.single['product_id'], 9);
    expect(priceRepo.aliasCount, 1); // existing 加别名
  });

  // ---- 代码质量审查补强 ----

  testWidgets('C1: 搜索框 controller 持久化（rebuild 不 new 新实例）', (tester) async {
    final productRepo = _FakeProductRepository({}); // 全 unmatched
    await pumpScreen(
      tester,
      screen: PasteImportScreen(
        merchantId: 7,
        historyProductNames: const [],
        priceRepository: _FakePriceRepository(),
        productRepository: productRepo,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('paste-raw-text-field')),
      '番茄 3',
    );
    await tester.tap(find.text('解析并匹配'));
    await tester.pumpAndSettle();

    // 展开
    await tester.tap(find.text('番茄'));
    await tester.pumpAndSettle();

    final field1 = tester
        .widget<TextField>(find.byKey(const Key('paste-existing-search')));
    final c1 = field1.controller;

    // 通过输入触发 _onExistingSearch → setState → rebuild
    await tester.enterText(
        find.byKey(const Key('paste-existing-search')), 'ABC');
    await tester.pumpAndSettle();
    final field2 = tester
        .widget<TextField>(find.byKey(const Key('paste-existing-search')));
    final c2 = field2.controller;
    expect(identical(c1, c2), isTrue,
        reason: 'controller 应持久，rebuild 不应 new 新实例');

    // 取消释放 controller；再次展开应 new 新实例
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('番茄'));
    await tester.pumpAndSettle();
    final field3 = tester
        .widget<TextField>(find.byKey(const Key('paste-existing-search')));
    final c3 = field3.controller;
    expect(identical(c1, c3), isFalse,
        reason: '取消 dispose 后重新展开应 new 新 controller');
  });

  testWidgets('I1: _onExistingSearch 竞态——后请求先回不被旧结果覆盖', (tester) async {
    // '番' 故意延迟返回；'番茄' 立即返回
    final productRepo = _FakeProductRepository({
      '番': [
        {'id': 1, 'name': '番茄旧', 'match_type': 'name'}
      ],
      '番茄': [
        {'id': 2, 'name': '番茄新', 'match_type': 'name'}
      ],
    }, delays: {
      '番': const Duration(milliseconds: 300),
    });
    await pumpScreen(
      tester,
      screen: PasteImportScreen(
        merchantId: 7,
        historyProductNames: const [],
        priceRepository: _FakePriceRepository(),
        productRepository: productRepo,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('paste-raw-text-field')),
      '番茄 3',
    );
    await tester.tap(find.text('解析并匹配'));
    await tester.pumpAndSettle();

    // 展开（自动匹配阶段查 '番茄' 返回 '番茄新'，但 name != '番茄' → unmatched）
    await tester.tap(find.text('番茄'));
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('paste-existing-search'));
    // 输入 '番'（在途，300ms 后才回）
    await tester.enterText(field, '番');
    await tester.pump(const Duration(milliseconds: 50));
    // 立即输入 '番茄'（立即返回）
    await tester.enterText(field, '番茄');
    await tester.pump(const Duration(milliseconds: 50));

    // 等待 '番' 的延迟也跑完
    await tester.pumpAndSettle();

    // 期望：suggestions 是第二次 '番茄' 的结果（'番茄新'），
    // 而非被晚到的 '番' 结果（'番茄旧'）覆盖
    expect(find.text('番茄新'), findsOneWidget);
    expect(find.text('番茄旧'), findsNothing);
  });

  testWidgets('I2/I3: autocomplete 返回 double 类型 id 不崩（_toInt 保护）',
      (tester) async {
    // 后端某些字段可能返回 double（如 9.0），裸 `as int` 会抛 TypeError
    final productRepo = _FakeProductRepository({
      '芹菜': [
        {
          'id': 1.0,
          'name': '芹菜',
          'match_type': 'name',
          'ingredient_id': 2.0,
          'ingredient_product_count': 1.0,
        }
      ],
    });
    await pumpScreen(
      tester,
      screen: PasteImportScreen(
        merchantId: 7,
        historyProductNames: const [],
        priceRepository: _FakePriceRepository(),
        productRepository: productRepo,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('paste-raw-text-field')),
      '芹菜 1.88',
    );
    await tester.tap(find.text('解析并匹配'));
    await tester.pumpAndSettle();

    // 修复前：`nameMatch['id'] as int` 抛 TypeError（Error 不被 on Exception 接住）
    //         → _parse 崩溃、pumpAndSettle 失败
    // 修复后：_toInt 安全转换 → 正常 matched
    expect(find.textContaining('已匹配 1'), findsOneWidget);
  });
}
