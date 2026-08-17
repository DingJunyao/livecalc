import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/nutrition/repositories/usda_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient client;
  late MockDio dio;
  late UsdaRepository repository;

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    repository = UsdaRepository(client: client);
  });

  test('parses USDA search and detail responses like the web client', () async {
    when(() =>
            dio.get('/usda/search', queryParameters: {'q': '黄油', 'limit': 50}))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              data: [
                {
                  'fdc_id': 123,
                  'description': 'Butter, salted',
                  'description_zh': '黄油',
                  'data_type': 'Foundation',
                  'nutrient_count': 2,
                }
              ],
            ));
    when(() => dio.get('/usda/123')).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {
            'fdc_id': 123,
            'description': 'Butter, salted',
            'description_zh': '黄油',
            'nutrients': [
              {
                'name': 'Energy',
                'name_zh': '能量',
                'amount': 717,
                'unit_name': 'kcal',
              },
            ],
          },
        ));

    final results = await repository.search('黄油');
    final detail = await repository.getFood(123);

    expect(results.single.descriptionZh, '黄油');
    expect(detail.nutrients.single.nameZh, '能量');
    expect(detail.nutrients.single.amount, 717);
  });

  test('match returns backend review message without discarding it', () async {
    const message = '营养数据提案已提交（status=pending，待管理员审核）';
    when(() => dio.post('/usda/match/ingredient/8', data: {'fdc_id': 123}))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              data: {'success': true, 'message': message},
            ));

    final result = await repository.match(
      entityType: 'ingredient',
      entityId: 8,
      fdcId: 123,
    );

    expect(result.pending, isTrue);
    expect(result.message, contains('待管理员审核'));
  });
}
