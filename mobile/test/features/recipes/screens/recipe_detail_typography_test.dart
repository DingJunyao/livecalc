import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/core/theme/app_theme.dart';
import 'package:com_a4ding_livecalc/features/recipes/providers/recipe_provider.dart';
import 'package:com_a4ding_livecalc/features/recipes/repositories/recipe_repository.dart';
import 'package:com_a4ding_livecalc/features/recipes/screens/recipe_detail_screen.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);

    // 菜谱详情主路径
    when(() => mockDio.get('/recipes/1')).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {
            'id': 1,
            'name': '番茄炒蛋',
            'servings': 2,
            'ingredients': [],
            'cooking_steps': [
              {'step': 1, 'content': '这是做法步骤正文', 'duration_minutes': 5},
            ],
            'tips': ['这是小贴士正文内容'],
          },
        ));

    // load() 触发的其余 dio 路径全部 stub 抛异常：
    // provider 的 on Exception catch 吞掉，显示“暂无”状态，不影响排版断言。
    // mocktail 未匹配的调用返回 MissingStubError（Error 而非 Exception）会击穿
    // provider 的 catch，故各路径按 repository 实际调用签名逐一显式 stub。
    when(() => mockDio.get('/recipes/1/cost'))
        .thenAnswer((_) async => throw Exception('boom'));
    when(() => mockDio.get('/recipes/1/nutrition'))
        .thenAnswer((_) async => throw Exception('boom'));
    when(() => mockDio.get('/recipes/1/cost-history-range',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => throw Exception('boom'));
    when(() => mockDio.get('/recipes/1/merchant-costs',
            options: any(named: 'options')))
        .thenAnswer((_) async => throw Exception('boom'));
  });

  testWidgets('小贴士正文与做法步骤同为 bodyLarge(16)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        recipeDetailPageProvider(1).overrideWith((ref) =>
            RecipeDetailPageNotifier(RecipeRepository(client: mockClient), 1)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const RecipeDetailScreen(id: 1),
      ),
    ));
    await tester.pumpAndSettle();

    final stepText = tester.widget<Text>(find.text('这是做法步骤正文'));
    final tipText = tester.widget<Text>(find.text('这是小贴士正文内容'));
    expect(stepText.style!.fontSize, 16);
    expect(tipText.style!.fontSize, 16, reason: '小贴士应与步骤同为 bodyLarge');
  });
}
