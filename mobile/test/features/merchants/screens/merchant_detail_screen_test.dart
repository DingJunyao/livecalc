import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/map_config_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/merchants/screens/merchant_detail_screen.dart';

class MockMerchantRepository extends Mock implements MerchantRepository {}

class _FakeDetailNotifier extends MerchantDetailPageNotifier {
  _FakeDetailNotifier() : super(1);

  @override
  Future<void> load() async {
    state = state.copyWith(
      merchant: const Merchant(
        id: 1,
        name: 'merchant',
        latitude: 31.2304,
        longitude: 121.4737,
      ),
      loading: false,
    );
  }
}

void main() {
  testWidgets('detail map waits for map config before rendering',
      (tester) async {
    final repo = MockMerchantRepository();
    final response = Completer<Map<String, dynamic>>();
    when(() => repo.getMapConfig()).thenAnswer((_) => response.future);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        merchantDetailPageProvider(1)
            .overrideWith((ref) => _FakeDetailNotifier()),
        mapConfigProvider.overrideWith((ref) => MapConfigNotifier(repo)),
      ],
      child: const MaterialApp(home: MerchantDetailScreen(id: 1)),
    ));
    await tester.pump();

    expect(find.byType(FlutterMap), findsNothing);
  });
}
