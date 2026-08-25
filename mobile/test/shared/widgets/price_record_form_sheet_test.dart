import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/shared/screens/price_record_edit_screen.dart';

/// 宿主：触发底部表单并通过 Text 暴露结果，便于断言。
class _FormHost extends StatefulWidget {
  final List<Merchant> merchants;
  final int? initialMerchantId;
  final String? initialRecordType;
  final DateTime? initialRecordedAt;
  final String? initialNotes;
  const _FormHost({
    required this.merchants,
    this.initialMerchantId,
    this.initialRecordType,
    this.initialRecordedAt,
    this.initialNotes,
  });

  @override
  State<_FormHost> createState() => _FormHostState();
}

class _FormHostState extends State<_FormHost> {
  PriceRecordFormResult? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () async {
                  result = await Navigator.of(ctx).push<PriceRecordFormResult>(
                    MaterialPageRoute(
                      builder: (_) => PriceRecordEditScreen(
                        arguments: PriceRecordFormArguments(
                          merchants: widget.merchants,
                          initialMerchantId: widget.initialMerchantId,
                          initialRecordType: widget.initialRecordType,
                          initialRecordedAt: widget.initialRecordedAt,
                          initialNotes: widget.initialNotes,
                        ),
                      ),
                    ),
                  );
                  setState(() {});
                },
                child: const Text('打开表单'),
              ),
              if (result != null) Text('merchantId=${result!.merchantId}'),
              if (result != null) Text('recordType=${result!.recordType}'),
              if (result != null) Text('notes=${result!.notes}'),
            ],
          ),
        ),
      ),
    );
  }
}

/// 定位商家 Autocomplete<Merchant> 内的 TextField
Finder merchantFieldFinder() => find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Merchant>),
      matching: find.byType(TextField),
    );

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    List<Merchant> merchants = const [],
    int? initialMerchantId,
    String? initialRecordType,
    DateTime? initialRecordedAt,
    String? initialNotes,
  }) async {
    // 底部表单内容较高，放大视口确保保存按钮被构建
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: _FormHost(
          merchants: merchants,
          initialMerchantId: initialMerchantId,
          initialRecordType: initialRecordType,
          initialRecordedAt: initialRecordedAt,
          initialNotes: initialNotes,
        ),
      ),
    ));
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();

    expect(find.byType(PriceRecordEditScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppBar, '记录价格'), findsOneWidget);
  }

  /// 价格 TextField 通过 labelText('价格') 定位
  Finder priceFieldFinder() => find.widgetWithText(TextField, '价格');

  testWidgets('预填商家时显示商家名', (tester) async {
    await pumpSheet(
      tester,
      merchants: const [Merchant(id: 1, name: '超市')],
      initialMerchantId: 1,
    );

    final textField = tester.widget<TextField>(merchantFieldFinder());
    expect(textField.controller?.text, '超市');
  });

  testWidgets('Autocomplete 过滤商家', (tester) async {
    await pumpSheet(
      tester,
      merchants: const [
        Merchant(id: 1, name: '超市'),
        Merchant(id: 2, name: '便利店'),
      ],
    );

    await tester.enterText(merchantFieldFinder(), '超');
    await tester.pumpAndSettle();

    expect(find.text('超市'), findsOneWidget);
    expect(find.text('便利店'), findsNothing);
  });

  testWidgets('选中商家后提交，结果携带 merchantId', (tester) async {
    await pumpSheet(
      tester,
      merchants: const [
        Merchant(id: 1, name: '超市'),
        Merchant(id: 2, name: '便利店'),
      ],
    );

    // 选商家
    await tester.enterText(merchantFieldFinder(), '超');
    await tester.pumpAndSettle();
    await tester.tap(find.text('超市'));
    await tester.pumpAndSettle();

    // 输入价格（数量默认 1）
    await tester.enterText(priceFieldFinder(), '5');

    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('merchantId=1'), findsOneWidget);
  });

  testWidgets('清空商家文本后提交，merchantId 为 null', (tester) async {
    await pumpSheet(
      tester,
      merchants: const [Merchant(id: 1, name: '超市')],
      initialMerchantId: 1,
    );

    // 默认显示「超市」，清空文本触发 onChanged 置空 _merchantId
    await tester.enterText(merchantFieldFinder(), '');
    await tester.pumpAndSettle();

    // 输入价格（同时让商家字段失焦，关闭 Autocomplete 浮层）
    await tester.enterText(priceFieldFinder(), '5');
    await tester.pumpAndSettle();

    // initialMerchantId 非空但 initialPrice 为空 → isEdit=false → 按钮文本「添加」
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('merchantId=null'), findsOneWidget);
  });

  testWidgets('不指定商家（默认）提交，merchantId 为 null', (tester) async {
    await pumpSheet(
      tester,
      merchants: const [Merchant(id: 1, name: '超市')],
    );

    await tester.enterText(priceFieldFinder(), '5');

    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('merchantId=null'), findsOneWidget);
  });


  testWidgets('计入支出默认开启，关闭后提交 recordType=price', (tester) async {
    await pumpSheet(tester);

    // 默认开启（purchase）
    var sw = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '计入支出'));
    expect(sw.value, isTrue);

    // 输入价格，关闭计入支出，提交
    await tester.enterText(priceFieldFinder(), '5');
    await tester.tap(find.text('计入支出'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('recordType=price'), findsOneWidget);
  });

  testWidgets('预填 recordType=price 时计入支出关闭', (tester) async {
    await pumpSheet(tester, initialRecordType: 'price');

    final sw = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '计入支出'));
    expect(sw.value, isFalse);
  });

  testWidgets('可填写备注并随结果返回', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(priceFieldFinder(), '5');
    await tester.enterText(find.widgetWithText(TextField, '备注'), '临期特价');
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('notes=临期特价'), findsOneWidget);
  });

  testWidgets('预填备注显示在输入框', (tester) async {
    await pumpSheet(tester, initialNotes: '旧备注');

    final notesField = tester.widget<TextField>(find.widgetWithText(TextField, '备注'));
    expect(notesField.controller?.text, '旧备注');
  });

  testWidgets('渲染记录时间字段（可点击打开时间选择器）', (tester) async {
    await pumpSheet(tester);

    expect(find.text('记录时间'), findsOneWidget);
    // 点击打开日期选择器，随后取消不报错
    await tester.tap(find.text('记录时间'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('选中商家后再编辑文本，merchantId 复位 null（防 stale id）', (tester) async {
    await pumpSheet(
      tester,
      merchants: const [
        Merchant(id: 1, name: '超市'),
        Merchant(id: 2, name: '便利店'),
      ],
    );

    // 选中「超市」
    await tester.enterText(merchantFieldFinder(), '超');
    await tester.pumpAndSettle();
    await tester.tap(find.text('超市'));
    await tester.pumpAndSettle();

    // 在选中后继续编辑文本（非空），_merchantId 应被清空
    await tester.enterText(merchantFieldFinder(), '超市X');
    await tester.pumpAndSettle();

    // 输入价格（让商家字段失焦关闭 Autocomplete 浮层）
    await tester.enterText(priceFieldFinder(), '5');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('merchantId=null'), findsOneWidget);
  });
}
