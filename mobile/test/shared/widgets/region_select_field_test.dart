import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/shared/widgets/region_select_field.dart';

class MockRepo extends Mock implements MerchantRepository {}

void main() {
  late MockRepo repo;

  setUp(() {
    repo = MockRepo();
    when(() => repo.listRegions(
        parentId: any(named: 'parentId'), level: any(named: 'level')))
        .thenAnswer((invocation) async {
      final parentId = invocation.namedArguments[#parentId] as int?;
      final level = invocation.namedArguments[#level] as int?;
      if (parentId == null && level == 0) {
        return [
          {'id': 1, 'name': '中国'},
          {'id': 9, 'name': '美国'},
        ];
      }
      if (parentId == 1) {
        return [
          {'id': 2, 'name': '上海'},
        ];
      }
      return const <Map<String, dynamic>>[];
    });
  });

  Future<void> pumpField(WidgetTester tester, int? value) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: RegionSelectField(
            value: value,
            onChanged: (_) {},
            repository: repo,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('只填国家/地区：编辑回填已存值', (tester) async {
    when(() => repo.getRegion(1)).thenAnswer((_) async => {
      'id': 1,
      'name': '中国',
      'level': 0,
      'ancestors': <Map<String, dynamic>>[],
    });

    await pumpField(tester, 1);

    expect(find.text('中国'), findsOneWidget);
    expect(find.text('美国'), findsNothing);
  });

  testWidgets('完整链：编辑回填国家+省份', (tester) async {
    when(() => repo.getRegion(2)).thenAnswer((_) async => {
      'id': 2,
      'name': '上海',
      'level': 1,
      'ancestors': [
        {'id': 1, 'name': '中国', 'level': 0},
      ],
    });

    await pumpField(tester, 2);

    expect(find.text('中国'), findsOneWidget);
    expect(find.text('上海'), findsOneWidget);
  });
}
