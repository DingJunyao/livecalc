import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';

void main() {
  test('ingredient detail shows pending update values', () {
    final ingredient = Ingredient.fromJson(const {
      'id': 8,
      'name': 'base ingredient',
      'category_id': 1,
      'aliases': ['old alias'],
      'pending_proposal': {
        'id': 20,
        'action': 'update',
        'payload': {
          'name': 'pending ingredient',
          'category_id': 3,
          'aliases': ['pending alias'],
        },
      },
    });

    final merged = ingredient.mergedWithPending();
    expect(merged.name, 'pending ingredient');
    expect(merged.categoryId, 3);
    expect(merged.category, '分类 #3');
    expect(merged.aliases, ['pending alias']);
    expect(merged.pendingProposal?.id, 20);
  });

  test('ingredient delete proposals keep official values', () {
    final ingredient = Ingredient.fromJson(const {
      'id': 8,
      'name': 'base ingredient',
      'pending_proposal': {
        'id': 21,
        'action': 'delete',
        'payload': {},
      },
    });

    expect(ingredient.mergedWithPending().name, 'base ingredient');
  });
}
