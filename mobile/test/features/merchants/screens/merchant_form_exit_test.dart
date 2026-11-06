import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/map_config_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/merchants/screens/merchant_form_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

class MockRepo extends Mock implements MerchantRepository {}

/// 内存瓦片：消除测试里真实网络请求的噪音。
class _MemoryTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

/// 商家表单（新增态）退出二次确认：写过信息返回时弹对话框，未写直接退出。
void main() {
  late MockRepo repo;

  setUp(() {
    repo = MockRepo();
    when(() => repo.getMapConfig()).thenAnswer((_) async => {
          'available_maps': ['osm'],
          'default_map': 'osm',
          'map_enabled': true,
        });
  });

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mapConfigProvider.overrideWith((ref) => MapConfigNotifier(repo)),
      ],
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MerchantFormScreen(
                  isAdmin: false,
                  repository: repo,
                  mapTileProvider: _MemoryTileProvider(),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('没写过信息：返回不弹对话框，直接退出', (tester) async {
    await pumpForm(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('写过名称：返回弹确认；取消留在页面，放弃后退出', (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextField, '商家名称（可留空）'),
      '盒马鲜生',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('放弃未保存的修改？'), findsOneWidget);

    // 取消 → 留在表单
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('盒马鲜生'), findsOneWidget);
    expect(find.text('Open'), findsNothing);

    // 再返回 → 放弃并退出
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃并退出'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('编辑态不弹确认（本次只对新增态启用）', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mapConfigProvider.overrideWith((ref) => MapConfigNotifier(repo)),
      ],
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MerchantFormScreen(
                  merchant: const Merchant(id: 5, name: '原商家'),
                  isAdmin: false,
                  repository: repo,
                  mapTileProvider: _MemoryTileProvider(),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '商家名称（可留空）'),
      '改名商家',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
