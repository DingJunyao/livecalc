import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString('{"id":1,"username":"u","email":"e"}', 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    ApiClient.instance.updateBaseUrl('https://example.test');
  });

  test('fromJson 解析完整字段（含昵称/营养目标/单位偏好）', () {
    final user = User.fromJson({
      'id': 1,
      'username': 'alice',
      'email': 'a@test.com',
      'phone': '13800138000',
      'is_admin': true,
      'avatar': 'avatars/abc.jpg',
      'nickname': '小艾',
      'nutrition_goals': {
        'daily_calorie_target': 2000,
        'daily_protein_target': 60,
        'daily_carb_target': null,
        'daily_fat_target': 65,
      },
      'daily_budget': 50.5,
      'unit_preferences': {
        'energy_unit': 'kcal',
        'mass_unit': {'id': 3, 'name': '克', 'abbreviation': 'g'},
        'volume_unit': {'id': 8, 'name': '毫升', 'abbreviation': 'ml'},
        'price_unit': null,
      },
    });

    expect(user.nickname, '小艾');
    expect(user.displayName, '小艾');
    expect(user.nutritionGoals['daily_calorie_target'], 2000);
    expect(user.nutritionGoals['daily_carb_target'], isNull);
    expect(user.dailyBudget, 50.5);
    expect(user.unitPreferences?.energyUnit, 'kcal');
    expect(user.unitPreferences?.massUnit?.abbreviation, 'g');
    expect(user.unitPreferences?.volumeUnit?.name, '毫升');
    expect(user.unitPreferences?.priceUnit, isNull);
  });

  test('无昵称时 displayName 回退 username', () {
    const user = User(id: 1, username: 'bob', email: 'b@test.com');
    expect(user.displayName, 'bob');
  });

  test('avatarUrl 拼接服务器地址，无头像时为 null', () {
    const user = User(
        id: 1, username: 'a', email: 'a@test.com', avatar: 'avatars/x.png');
    expect(user.avatarUrl, 'https://example.test/api/v1/images/avatars/x.png');

    const noAvatar = User(id: 2, username: 'b', email: 'b@test.com');
    expect(noAvatar.avatarUrl, isNull);
  });

  test('字段缺失时全部容错（后端旧版本不返回新字段）', () {
    final user = User.fromJson({'id': 3, 'username': 'c'});
    expect(user.email, '');
    expect(user.nickname, isNull);
    expect(user.nutritionGoals, isEmpty);
    expect(user.dailyBudget, isNull);
    expect(user.unitPreferences, isNull);
    expect(user.avatarUrl, isNull);
  });

  test('UnitPreferences.fromJson 空 map 解析为 null 字段', () {
    final prefs = UnitPreferences.fromJson({});
    expect(prefs.energyUnit, isNull);
    expect(prefs.massUnit, isNull);
  });

  test('User.fromJson reads locale payload keys', () {
    final user = User.fromJson({
      'id': 1,
      'username': 'ding',
      'email': 'ding@example.test',
      'locale': 'ar',
      'format_locale': 'de-DE',
    });

    expect(user.locale, 'ar');
    expect(user.formatLocale, 'de-DE');
  });

  test('updateLocalePreferences sends only locale payload keys', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final client = _MockApiClient();
    when(() => client.dio).thenReturn(dio);

    final user = await AuthRepository(client: client)
        .updateLocalePreferences(locale: 'ar', formatLocale: 'de-DE');

    expect(adapter.request!.path, '/auth/me');
    expect(adapter.request!.method, 'PATCH');
    expect(adapter.request!.data, {
      'locale': 'ar',
      'format_locale': 'de-DE',
    });
    expect(user.id, 1);
  });
}
