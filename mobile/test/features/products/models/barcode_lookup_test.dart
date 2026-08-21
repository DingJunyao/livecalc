import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/products/models/barcode_lookup.dart';

void main() {
  test('parses a local product lookup', () {
    final result = BarcodeLookupResult.fromJson(const {
      'found': true,
      'source': 'local',
      'product': {
        'id': 7,
        'barcode': '123',
        'name': 'Milk',
        'brand': 'Brand',
      },
      'errors': [],
    });

    expect(result.found, isTrue);
    expect(result.source, 'local');
    expect(result.product.id, 7);
    expect(result.product.name, 'Milk');
    expect(result.product.brand, 'Brand');
  });

  test('parses an external lookup and preserves missing fields', () {
    final result = BarcodeLookupResult.fromJson(const {
      'found': true,
      'source': 'openfoodfacts',
      'product': {
        'barcode': '123',
        'name': 'Milk',
        'spec': '500 ml',
        'manufacturer': 'Factory',
      },
      'errors': ['mxnzp: miss'],
    });

    expect(result.product.id, isNull);
    expect(result.product.brand, isNull);
    expect(result.product.spec, '500 ml');
    expect(result.product.manufacturer, 'Factory');
    expect(result.errors, ['mxnzp: miss']);
  });

  test('parses a miss with an empty product', () {
    final result = BarcodeLookupResult.fromJson(const {
      'found': false,
      'source': null,
      'product': {},
      'errors': ['not found'],
    });

    expect(result.found, isFalse);
    expect(result.source, isNull);
    expect(result.product.name, isNull);
    expect(result.errors, ['not found']);
  });
}
