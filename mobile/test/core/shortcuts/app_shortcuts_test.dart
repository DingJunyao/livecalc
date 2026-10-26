import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/services/app_shortcuts_service.dart';
import 'package:com_a4ding_livecalc/core/shortcuts/app_shortcuts.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AppShortcutsService.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AppShortcut', () {
    test('fromId 解析已知 id，未知/空值返回 null', () {
      expect(AppShortcut.fromId('record_price'), AppShortcut.recordPrice);
      expect(
        AppShortcut.fromId('daily_recommendation'),
        AppShortcut.dailyRecommendation,
      );
      expect(AppShortcut.fromId('recipes'), AppShortcut.recipes);
      expect(AppShortcut.fromId('unknown'), isNull);
      expect(AppShortcut.fromId(''), isNull);
      expect(AppShortcut.fromId(null), isNull);
    });

    test('三个快捷方式分别跳转计价 / 推荐 / 菜谱 tab', () {
      expect(AppShortcut.recordPrice.route, '/prices');
      expect(AppShortcut.dailyRecommendation.route, '/home');
      expect(AppShortcut.recipes.route, '/recipes');
    });

    test('标题走 i18n，中文与产品文案一致', () {
      final zh = lookupAppLocalizations(const Locale('zh'));
      final en = lookupAppLocalizations(const Locale('en'));
      final ar = lookupAppLocalizations(const Locale('ar'));

      expect(AppShortcut.recordPrice.label(zh), '计价');
      expect(AppShortcut.dailyRecommendation.label(zh), '每日推荐');
      expect(AppShortcut.recipes.label(zh), '菜谱');

      for (final shortcut in AppShortcut.values) {
        expect(shortcut.label(en).trim(), isNotEmpty);
        expect(shortcut.label(ar).trim(), isNotEmpty);
      }
    });

    test('toChannelItem 透传 id / 标题 / iOS 图标名', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        AppShortcut.recipes.toChannelItem(en),
        {'id': 'recipes', 'title': 'Recipes', 'icon': 'bookmark'},
      );
      expect(
        AppShortcut.dailyRecommendation.toChannelItem(en)['icon'],
        'home',
      );
      expect(AppShortcut.recordPrice.toChannelItem(en)['icon'], 'add');
    });
  });

  group('AppShortcutsService', () {
    test('initialize 取回冷启动动作且只消费一次', () async {
      String? pending = 'recipes';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'ready');
        final value = pending;
        pending = null;
        return value;
      });

      final service = AppShortcutsService(channel: channel);
      addTearDown(service.dispose);

      expect(await service.initialize(), AppShortcut.recipes);
      expect(await service.initialize(), isNull);
    });

    test('initialize 遇到未知 id 返回 null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => 'legacy_action');

      final service = AppShortcutsService(channel: channel);
      addTearDown(service.dispose);

      expect(await service.initialize(), isNull);
    });

    test('setItems 把标题与图标透传给原生', () async {
      List<dynamic>? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'setShortcutItems');
        captured = call.arguments as List<dynamic>;
        return null;
      });

      final service = AppShortcutsService(channel: channel);
      addTearDown(service.dispose);
      final l10n = lookupAppLocalizations(const Locale('zh'));

      await service.setItems(
        AppShortcut.values
            .map((shortcut) => shortcut.toChannelItem(l10n))
            .toList(growable: false),
      );

      expect(captured, hasLength(3));
      expect(captured!.first, containsPair('id', 'record_price'));
      expect(captured!.first, containsPair('title', '计价'));
    });

    test('原生 shortcut 事件进入 actions 流', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      final service = AppShortcutsService(channel: channel);
      addTearDown(service.dispose);
      await service.initialize();

      final actions = <AppShortcut>[];
      final subscription = service.actions.listen(actions.add);
      addTearDown(subscription.cancel);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AppShortcutsService.channelName,
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('shortcut', 'record_price')),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(actions, [AppShortcut.recordPrice]);
    });

    test('没有原生实现时静默降级（桌面/测试环境）', () async {
      final service = AppShortcutsService();

      expect(await service.initialize(), isNull);
      await service.setItems(const []);
      service.dispose();
    });
  });
}
