import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/features/auth/models/login_request.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late AuthRepository repository;
  late MockApiClient mockClient;
  late MockDio mockDio;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repository = AuthRepository(client: mockClient);
  });

  group('getConfig', () {
    test('返回 AuthConfig', () async {
      when(() => mockDio.get('/auth/config')).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            data: {'registration_require_invite_code': true},
            statusCode: 200,
          ));

      final config = await repository.getConfig();
      expect(config.requireInviteCode, true);
      expect(config.allowRegistration, true);
    });
  });

  group('login', () {
    test('返回 LoginResponse', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ''),
                data: {
                  'access_token': 'abc',
                  'refresh_token': 'def',
                  'token_type': 'bearer'
                },
                statusCode: 200,
              ));

      final response = await repository
          .login(const LoginRequest(username: 'test', passwordHash: 'pass'));
      expect(response.accessToken, 'abc');
      expect(response.refreshToken, 'def');
    });
  });

  group('updateMe', () {
    test('PATCH /auth/me 并返回 User', () async {
      when(() => mockDio.patch('/auth/me', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ''),
                data: {
                  'id': 1,
                  'username': 'test',
                  'email': 't@test.com',
                  'nickname': '新昵称',
                  'nutrition_goals': {'daily_calorie_target': 1800},
                },
                statusCode: 200,
              ));

      final user = await repository.updateMe({'default_energy_unit': 'kJ'});
      expect(user.nickname, '新昵称');
      expect(user.nutritionGoals['daily_calorie_target'], 1800);
    });
  });

  group('updateAccount', () {
    test('PUT /auth/me/account 返回用户与 token（可为空）', () async {
      when(() => mockDio.put('/auth/me/account', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ''),
                data: {
                  'user': {'id': 1, 'username': 'new', 'email': 'n@test.com'},
                  'access_token': null,
                  'refresh_token': null,
                },
                statusCode: 200,
              ));

      final resp = await repository.updateAccount({'username': 'new'});
      expect(resp.user.username, 'new');
      expect(resp.accessToken, isNull);
    });
  });

  group('uploadAvatar', () {
    test('multipart 上传，Content-Type 覆盖为 multipart/form-data', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            data: {'avatar_key': 'avatars/x.jpg'},
            statusCode: 200,
          ));

      final xfile = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'avatar.png',
      );
      await repository.uploadAvatar(xfile);

      final captured = verify(() => mockDio.post(
            captureAny(),
            data: any(named: 'data'),
            options: captureAny(named: 'options'),
          )).captured;
      expect(captured[0], '/auth/me/avatar');
      final opts = captured[1] as Options;
      expect(opts.headers?['Content-Type'], 'multipart/form-data');
    });
  });
}
