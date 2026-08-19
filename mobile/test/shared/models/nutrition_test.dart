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
}
