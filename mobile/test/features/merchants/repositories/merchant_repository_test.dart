import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient client;
  late MockDio dio;
  late MerchantRepository repository;

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    repository = MerchantRepository(client: client);
  });

  test('non-admin update is pending even when backend echoes old merchant',
      () async {
    when(() => dio.put('/merchants/4',
            data: any(named: 'data', that: isA<Map<String, dynamic>>())))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: 200,
              data: {'id': 4, 'name': 'Hema', 'is_open': true},
            ));

    final result = await repository.updateMerchant(
      4,
      isAdmin: false,
      name: 'Hema Pudong',
    );

    expect(result.pending, isTrue);
    expect(result.merchant?.name, 'Hema');
  });

  test('delete parses a pending proposal response', () async {
    when(() => dio.delete('/merchants/4')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: {
          'proposal_id': 9,
          'status': 'pending',
          'message': '删除提议已提交，待管理员审核',
        },
      ),
    );

    final result = await repository.deleteMerchant(4);

    expect(result.pending, isTrue);
    expect(result.message, contains('待管理员审核'));
  });
}
