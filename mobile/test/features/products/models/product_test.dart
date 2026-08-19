import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';

void main() {
  test('product detail shows pending update values', () {
    final product = Product.fromJson(const {
      'id': 5,
      'name': 'base product',
      'brand': 'old brand',
      'barcode': 'old-barcode',
      'aliases': ['old alias'],
      'tags': ['old tag'],
      'pending_proposal': {
        'id': 30,
        'action': 'update',
        'payload': {
          'name': 'pending product',
          'brand': 'pending brand',
          'barcode': 'pending-barcode',
          'ingredient_id': 8,
          'aliases': ['pending alias'],
          'tags': ['pending tag'],
        },
      },
    });

    final merged = product.mergedWithPending();
    expect(merged.name, 'pending product');
    expect(merged.brand, 'pending brand');
    expect(merged.barcode, 'pending-barcode');
    expect(merged.ingredientId, 8);
    expect(merged.ingredientName, '原料 #8');
    expect(merged.aliases, ['pending alias']);
    expect(merged.tags, ['pending tag']);
  });

  test('product delete proposals keep official values', () {
    final product = Product.fromJson(const {
      'id': 5,
      'name': 'base product',
      'pending_proposal': {
        'id': 31,
        'action': 'delete',
        'payload': {},
      },
    });

    expect(product.mergedWithPending().name, 'base product');
  });
}
