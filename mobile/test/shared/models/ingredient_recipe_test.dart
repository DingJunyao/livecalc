import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/features/recipes/models/recipe_detail.dart';
import 'package:com_a4ding_livecalc/shared/models/ingredient_recipe.dart';

void main() {
  group('RecipeUsage.display（对齐 Web formatUsageText）', () {
    test('区间 + 非零精确值 → 区间并标注推荐值', () {
      const u = RecipeUsage(
        quantity: 150,
        quantityRange: QuantityRange(min: 100, max: 200),
        unit: 'g',
      );
      expect(u.display, '100~200 g（推荐 150 g）');
    });

    test('仅区间 → 显示区间', () {
      const u = RecipeUsage(
        quantityRange: QuantityRange(min: 100, max: 200),
        unit: 'g',
      );
      expect(u.display, '100~200 g');
    });

    test('仅精确值 → 显示精确值', () {
      const u = RecipeUsage(quantity: 150, unit: 'g');
      expect(u.display, '150 g');
    });

    test('模糊量 original_quantity 原样显示', () {
      const u = RecipeUsage(originalQuantity: '适量');
      expect(u.display, '适量');
    });

    test('无任何用量 → 显示 -', () {
      const u = RecipeUsage();
      expect(u.display, '-');
    });

    test('无单位时不渲染单位', () {
      const u = RecipeUsage(
        quantity: 150,
        quantityRange: QuantityRange(min: 100, max: 200),
      );
      expect(u.display, '100~200（推荐 150）');
    });
  });

  group('RecipeUsage.fromJson', () {
    test('解析 quantity_range 与 quantity', () {
      final u = RecipeUsage.fromJson({
        'quantity': 150,
        'quantity_range': {'min': 100, 'max': 200},
        'unit': 'g',
        'original_quantity': null,
      });
      expect(u.quantity, 150);
      expect(u.quantityRange?.min, 100);
      expect(u.quantityRange?.max, 200);
      expect(u.display, '100~200 g（推荐 150 g）');
    });

    test('带区间无精确值时 quantity=0 不显示 0', () {
      final u = RecipeUsage.fromJson({
        'quantity': null,
        'quantity_range': {'min': 100, 'max': 200},
        'unit': 'g',
      });
      expect(u.display, '100~200 g');
    });

    test('original_quantity 为字符串原样保留（适量）', () {
      final u = RecipeUsage.fromJson({
        'quantity': null,
        'quantity_range': null,
        'unit': null,
        'original_quantity': '适量',
      });
      expect(u.originalQuantity, '适量');
      expect(u.display, '适量');
    });
  });
}
