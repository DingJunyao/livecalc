import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/recipes/models/recipe_detail.dart';

void main() {
  test('parses and merges every pending recipe proposal in order', () {
    final detail = RecipeDetail.fromJson(const {
      'id': 3,
      'name': 'base recipe',
      'cooking_steps': [
        {'step': 1, 'content': 'base step'},
      ],
      'tips': ['base tip'],
      'pending_proposals': [
        {
          'id': 11,
          'action': 'update',
          'payload': {
            'update_data': {
              'tips': ['first pending tip']
            },
          },
        },
        {
          'id': 12,
          'action': 'update',
          'payload': {
            'update_data': {
              'cooking_steps': [
                {'step': 1, 'content': 'second pending step'},
              ],
            },
          },
        },
      ],
    });

    expect(detail.pendingProposals.map((proposal) => proposal.id), [11, 12]);
    expect(detail.pendingProposal?.id, 12);
    expect(detail.pendingChangeSummary, '小贴士、做法步骤');

    final merged = detail.mergedWithPending();
    expect(merged.tips, ['first pending tip']);
    expect(merged.steps.single.content, 'second pending step');
    expect(merged.pendingProposals.map((proposal) => proposal.id), [11, 12]);
  });

  test('pending change summary de-duplicates fields across proposals', () {
    final detail = RecipeDetail.fromJson(const {
      'id': 3,
      'name': 'base recipe',
      'pending_proposals': [
        {
          'id': 11,
          'action': 'update',
          'payload': {
            'update_data': {'cooking_steps': []},
          },
        },
        {
          'id': 12,
          'action': 'update',
          'payload': {
            'update_data': {
              'cooking_steps': [],
              'tips': [],
            },
          },
        },
      ],
    });

    expect(detail.pendingChangeSummary, '做法步骤、小贴士');
  });

  test('pending ingredient changes keep row identity and unit', () {
    final detail = RecipeDetail.fromJson(const {
      'id': 3,
      'name': 'base recipe',
      'ingredients': [
        {
          'id': 31,
          'ingredient_id': 8,
          'name': 'beef',
          'quantity': '100',
          'unit': 'g',
        },
      ],
      'pending_proposals': [
        {
          'id': 13,
          'action': 'update',
          'payload': {
            'update_data': {
              'ingredients': [
                {
                  'id': 31,
                  'ingredient_id': 8,
                  'ingredient_name': 'beef',
                  'name': 'beef',
                  'quantity': '200',
                  'unit_id': 2,
                  'unit': 'g',
                  'is_optional': false,
                },
              ],
            },
          },
        },
      ],
    });

    final ingredient = detail.mergedWithPending().ingredients.single;
    expect(ingredient.id, 31);
    expect(ingredient.ingredientId, 8);
    expect(ingredient.quantity, '200');
    expect(ingredient.unit, 'g');
  });

  test('falls back to the legacy single pending proposal', () {
    final detail = RecipeDetail.fromJson(const {
      'id': 3,
      'name': 'base recipe',
      'pending_proposal': {
        'id': 21,
        'action': 'update',
        'payload': {
          'update_data': {'name': 'legacy merged recipe'},
        },
      },
    });

    expect(detail.pendingProposals, hasLength(1));
    expect(detail.pendingProposals.single.id, 21);
    expect(detail.mergedWithPending().name, 'legacy merged recipe');
  });

  test('pending added ingredient keeps a stable negative row id', () {
    final detail = RecipeDetail.fromJson(const {
      'id': 3,
      'name': 'base recipe',
      'ingredients': [],
      'pending_proposals': [
        {
          'id': 14,
          'action': 'update',
          'payload': {
            'update_data': {
              'ingredients': [
                {
                  'id': -1,
                  'ingredient_id': 8,
                  'ingredient_name': 'beef',
                  'name': 'beef',
                  'quantity': '100',
                },
              ],
            },
          },
        },
      ],
    });

    final ingredient = detail.mergedWithPending().ingredients.single;
    expect(ingredient.id, -1);
    expect(ingredient.ingredientId, 8);
  });

  test('pending recipe changes use Chinese field labels', () {
    final proposal = RecipePendingProposal.fromJson(const {
      'id': 12,
      'action': 'update',
      'payload': {
        'update_data': {
          'cooking_steps': [],
          'tips': [],
          'custom_field': 1,
        },
      },
    });

    expect(proposal.changeSummary, '做法步骤、小贴士、custom_field');
  });
}
