import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/profile/models/user_place.dart';

void main() {
  test('fromJson 解析 is_default / view_radius_km', () {
    final place = UserPlace.fromJson({
      'id': 5,
      'name': '家',
      'kind': 'home',
      'latitude': 31.2304,
      'longitude': 121.4737,
      'address': '上海市',
      'is_default': true,
      'view_radius_km': 5,
    });

    expect(place.isDefault, true);
    expect(place.viewRadiusKm, 5);
    expect(place.kind, 'home');
  });

  test('字段缺失时容错默认值', () {
    final place = UserPlace.fromJson({
      'id': 6,
      'name': '公司',
      'latitude': 31.2,
      'longitude': 121.4,
    });

    expect(place.isDefault, false);
    expect(place.viewRadiusKm, isNull);
    expect(place.address, isNull);
  });
}
