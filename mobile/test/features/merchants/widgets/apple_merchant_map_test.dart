import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/widgets/apple_merchant_map.dart';

void main() {
  testWidgets('海外商家不应用 GCJ02 偏移且地图手势可交互', (tester) async {
    const jakartaLat = -6.2088;
    const jakartaLng = 106.8456;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 500,
            height: 320,
            child: AppleMerchantMap(
              merchants: [
                Merchant(
                  id: 1,
                  name: 'Jakarta Merchant',
                  latitude: jakartaLat,
                  longitude: jakartaLng,
                ),
              ],
            ),
          ),
        ),
      ),
    ));

    final map = tester.widget<apple.AppleMap>(find.byType(apple.AppleMap));
    expect(
        map.initialCameraPosition.target.latitude, closeTo(jakartaLat, 1e-9));
    expect(
        map.initialCameraPosition.target.longitude, closeTo(jakartaLng, 1e-9));
    final annotation = map.annotations!.single;
    expect(annotation.position.latitude, closeTo(jakartaLat, 1e-9));
    expect(annotation.position.longitude, closeTo(jakartaLng, 1e-9));
    expect(map.gestureRecognizers, isNotNull);
    expect(map.gestureRecognizers, isNotEmpty);
  });
}
