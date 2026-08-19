import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';

void main() {
  test('merchant detail shows pending update values', () {
    final merchant = Merchant.fromJson(const {
      'id': 4,
      'name': 'base merchant',
      'address': 'old address',
      'latitude': 31.0,
      'longitude': 121.0,
      'is_open': true,
      'pending_proposal': {
        'id': 40,
        'action': 'update',
        'payload': {
          'name': 'pending merchant',
          'address': 'pending address',
          'latitude': 32.0,
          'longitude': 122.0,
          'is_open': false,
        },
      },
    });

    final merged = merchant.mergedWithPending();
    expect(merged.name, 'pending merchant');
    expect(merged.address, 'pending address');
    expect(merged.latitude, 32.0);
    expect(merged.longitude, 122.0);
    expect(merged.isOpen, isFalse);
  });

  test('merchant delete proposals keep official values', () {
    final merchant = Merchant.fromJson(const {
      'id': 4,
      'name': 'base merchant',
      'pending_proposal': {
        'id': 41,
        'action': 'delete',
        'payload': {},
      },
    });

    expect(merchant.mergedWithPending().name, 'base merchant');
  });
}
