import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/models/entity_pending_proposal.dart';
import 'package:com_a4ding_livecalc/shared/models/nutrition.dart';

void main() {
  test('nutrition detail shows pending manual values', () {
    final info = NutritionInfo.fromJson(const {
      'ingredient_id': 8,
      'ingredient_name': 'tomato',
      'base_quantity': 100,
      'base_unit': 'g',
      'nutrition': {
        'core_nutrients': {
          '能量': {'value': 20, 'unit': 'kcal'},
        },
      },
      'pending_proposal': {
        'id': 50,
        'action': 'update',
        'payload': {
          'custom_nutrition_source': 'custom',
          'custom_nutrition_data': {
            'core_nutrients': {
              '能量': {'value': 35, 'unit': 'kcal', 'key': 'energy'},
            },
            'all_nutrients': {
              'energy': {'value': 35, 'unit': 'kcal'},
            },
          },
        },
      },
    });

    final merged = info.mergedWithPending();
    expect(merged.pendingProposal?.id, 50);
    expect(merged.source, 'custom');
    expect(merged.nutrients.single.label, '能量');
    expect(merged.nutrients.single.value, 35);
  });

  test('fallback nutrient entries carry from-products provenance', () {
    final info = NutritionInfo.fromJson(const {
      'ingredient_id': 729,
      'ingredient_name': '浓汤宝',
      'reference_amount': 100,
      'reference_unit': 'g',
      'nutrition': {
        'core_nutrients': {
          '钠': {
            'value': 7709.57,
            'unit': 'mg',
            'nrp_pct': 385.48,
            'from_products': true,
            'products_used': 7,
          },
        },
        'all_nutrients': {
          '钠': {
            'value': 7709.57,
            'unit': 'mg',
            'nrp_pct': 385.48,
            'original_key': 'sodium',
            'from_products': true,
            'products_used': 7,
          },
        },
      },
    });

    final entry = info.nutrients.single;
    expect(entry.label, '钠');
    expect(entry.nrvPct, 385.48);
    expect(entry.fromProducts, isTrue);
    expect(entry.productsUsed, 7);
  });

  test('nutrition delete or malformed proposals keep official values', () {
    final info = NutritionInfo.fromJson(const {
      'product_id': 5,
      'nutrition': {
        'core_nutrients': {
          '蛋白质': {'value': 3, 'unit': 'g'},
        },
      },
      'pending_proposal': {
        'id': 51,
        'action': 'delete',
        'payload': {},
      },
    });

    final merged = info.mergedWithPending();
    expect(merged.nutrients.single.value, 3);
  });

  test('pending nutrition draft works without official data', () {
    final info = NutritionInfo.fromPendingProposal(
      entityId: 12,
      proposal: EntityPendingProposal.fromJson(const {
        'id': 52,
        'action': 'update',
        'payload': {
          'base_quantity': 100,
          'base_unit': 'g',
          'source': 'custom',
          'nutrients': {
            'core_nutrients': {
              '蛋白质': {'value': 4, 'unit': 'g'},
            },
          },
        },
      }),
    );

    expect(info.hasData, isTrue);
    expect(info.pendingProposal?.id, 52);
    expect(info.source, 'custom');
    expect(info.nutrients.single.label, '蛋白质');
    expect(info.nutrients.single.value, 4);
  });

  test('product merged response: ownNutrients carries only custom data', () {
    // GET /nutrition/products/{id} 的 nutrients 是「商品自定义 → 原料继承」
    // 的合并值；编辑器预填必须用 custom_nutrition_data（商品自身），否则
    // 商品没填营养时会带出原料的值。
    final info = NutritionInfo.fromJson(const {
      'product_id': 42,
      'source': 'merged',
      'custom_nutrition_data': {
        'core_nutrients': {
          '能量': {'value': 100, 'unit': 'kcal'},
        },
        'all_nutrients': {
          '能量': {'value': 100, 'unit': 'kcal'},
          '钠': {'value': 50, 'unit': 'mg'},
        },
      },
      'nutrition': {
        'core_nutrients': {
          '能量': {'value': 88, 'unit': 'kcal'},
          '蛋白质': {'value': 9, 'unit': 'g'},
        },
        'all_nutrients': {
          '能量': {'value': 88, 'unit': 'kcal'},
          '蛋白质': {'value': 9, 'unit': 'g'},
        },
      },
    });

    expect(info.nutrients.map((e) => e.label), contains('蛋白质'),
        reason: '展示用 nutrients 是合并值（含原料继承）');
    expect(info.ownNutrients.map((e) => e.label), isNot(contains('蛋白质')),
        reason: 'ownNutrients 不含原料继承的营养素');
    expect(info.ownNutrients.map((e) => e.label), containsAll(['能量', '钠']));
    final energy =
        info.ownNutrients.firstWhere((e) => e.label == '能量');
    expect(energy.value, 100);
  });

  test('product without custom data: ownNutrients empty', () {
    // 商品没填营养时响应里只有原料继承值，ownNutrients 必须为空，
    // 编辑器据此落到「默认七项」预填而不是带出原料值。
    final info = NutritionInfo.fromJson(const {
      'product_id': 42,
      'source': 'merged',
      'nutrition': {
        'core_nutrients': {
          '能量': {'value': 88, 'unit': 'kcal'},
        },
        'all_nutrients': {
          '能量': {'value': 88, 'unit': 'kcal'},
        },
      },
    });

    expect(info.nutrients, isNotEmpty);
    expect(info.ownNutrients, isEmpty);
  });
}
