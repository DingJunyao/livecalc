import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/profile/repositories/profile_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late ProfileRepository repository;
  late MockApiClient mockClient;
  late MockDio mockDio;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repository = ProfileRepository(client: mockClient);
  });

  group('getProposals', () {
    test('传 scope=mine&limit=100，解析裸数组', () async {
      when(() => mockDio.get('/proposals',
          queryParameters: any(named: 'queryParameters'))).thenAnswer(
          (_) async => Response(
                requestOptions: RequestOptions(path: ''),
                data: [
                  {
                    'id': 1,
                    'entity_type': 'ingredient',
                    'entity_id': 5,
                    'entity_label': '番茄',
                    'action': 'update',
                    'status': 'pending',
                    'created_at': '2026-08-01T10:00:00',
                  },
                ],
                statusCode: 200,
              ));

      final items = await repository.getProposals();
      expect(items.length, 1);
      expect(items.first.id, 1);
      final captured = verify(() => mockDio.get('/proposals',
              queryParameters: captureAny(named: 'queryParameters')))
          .captured;
      final params = captured.first as Map<String, dynamic>;
      expect(params['scope'], 'mine');
      expect(params['limit'], 100);
    });
  });

  group('getUnits', () {
    test('必须带尾斜杠 /units/（后端 redirect_slashes=False）', () async {
      when(() => mockDio.get('/units/')).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            data: [
              {'id': 1, 'name': '克', 'abbreviation': 'g', 'unit_type': 'mass'},
              {
                'id': 2,
                'name': '毫升',
                'abbreviation': 'ml',
                'unit_type': 'volume'
              },
            ],
            statusCode: 200,
          ));

      final items = await repository.getUnits();
      expect(items.length, 2);
      expect(items.first.unitType, 'mass');
      expect(items.last.abbreviation, 'ml');
      // 只允许带斜杠路径
      verify(() => mockDio.get('/units/')).called(1);
    });
  });

  group('places CRUD', () {
    test('createPlace POST /places 返回新建地点', () async {
      when(() => mockDio.post('/places', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ''),
                data: {
                  'id': 9,
                  'name': '家',
                  'kind': 'home',
                  'latitude': 31.2,
                  'longitude': 121.4,
                  'is_default': false,
                  'view_radius_km': 5,
                },
                statusCode: 201,
              ));

      final place = await repository.createPlace({
        'name': '家',
        'kind': 'home',
        'latitude': 31.2,
        'longitude': 121.4,
        'view_radius_km': 5,
      });
      expect(place.id, 9);
      expect(place.isDefault, false);
      expect(place.viewRadiusKm, 5);
    });

    test('updatePlace PUT /places/{id}', () async {
      when(() => mockDio.put('/places/9', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ''),
                data: {'id': 9, 'name': '公司', 'latitude': 0, 'longitude': 0},
                statusCode: 200,
              ));

      final place = await repository.updatePlace(9, {'name': '公司'});
      expect(place.name, '公司');
    });

    test('deletePlace DELETE /places/{id}', () async {
      when(() => mockDio.delete('/places/9')).thenAnswer((_) async =>
          Response(
              requestOptions: RequestOptions(path: ''),
              data: {'message': '已删除'},
              statusCode: 200));
      await repository.deletePlace(9);
      verify(() => mockDio.delete('/places/9')).called(1);
    });

    test('setDefaultPlace PUT /places/{id}/default', () async {
      when(() => mockDio.put('/places/9/default')).thenAnswer((_) async =>
          Response(
              requestOptions: RequestOptions(path: ''),
              data: {'id': 9, 'name': '家', 'is_default': true},
              statusCode: 200));

      final place = await repository.setDefaultPlace(9);
      expect(place.isDefault, true);
    });
  });
}
