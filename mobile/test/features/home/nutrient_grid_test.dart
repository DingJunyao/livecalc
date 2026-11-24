import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/home/widgets/nutrient_grid.dart';

const _items = [
  NutrientGridItem(
      icon: Icons.local_fire_department, label: '热量', value: '1 kJ'),
  NutrientGridItem(icon: Icons.egg_outlined, label: '蛋白质', value: '2 g'),
  NutrientGridItem(icon: Icons.water_drop_outlined, label: '脂肪', value: '3 g'),
  NutrientGridItem(icon: Icons.grain, label: '碳水化合物', value: '4 g'),
];

Future<void> _pump(WidgetTester tester,
    {required double width, int? wideColumns}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: NutrientGrid(items: _items, wideColumns: wideColumns),
          ),
        ),
      ),
    ),
  );
}

/// 各条目的行号（按 label 的纵向位置去重排序）。
List<double> _rows(WidgetTester tester) {
  final tops = [
    for (final it in _items) tester.getTopLeft(find.text(it.label)).dy
  ];
  return tops.toSet().toList()..sort();
}

void main() {
  testWidgets('宽屏（≥760）+ wideColumns: 4 → 四项排成一行、等分', (tester) async {
    await _pump(tester, width: 800, wideColumns: 4);

    expect(_rows(tester), hasLength(1));
    for (final label in ['热量', '蛋白质', '脂肪', '碳水化合物']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(800));
    }
    expect(
      tester.getTopLeft(find.text('蛋白质')).dx,
      greaterThan(tester.getTopRight(find.text('热量')).dx),
    );
  });

  testWidgets('展开竖屏（卡内 605）：四项也排成一行', (tester) async {
    await _pump(tester, width: 605, wideColumns: 4);

    expect(_rows(tester), hasLength(1));
  });

  testWidgets('窄屏：仍是 2×2', (tester) async {
    await _pump(tester, width: 400, wideColumns: 4);

    expect(_rows(tester), hasLength(2));
  });

  testWidgets('未指定 wideColumns：再宽也是 2×2（餐卡等窄容器）', (tester) async {
    await _pump(tester, width: 800);

    expect(_rows(tester), hasLength(2));
  });
}
