import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/map_config_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';

class MockRepo extends Mock implements MerchantRepository {}

void main() {
  late MockRepo repo;

  setUp(() {
    repo = MockRepo();
  });

  Future<MapConfigState> loadState() async {
    final container = ProviderContainer(overrides: [
      mapConfigProvider.overrideWith((ref) => MapConfigNotifier(repo)),
    ]);
    addTearDown(container.dispose);
    await container.read(mapConfigProvider.notifier).load();
    return container.read(mapConfigProvider);
  }

  test('load merges concurrent requests and caches the completed config',
      () async {
    final response = Completer<Map<String, dynamic>>();
    when(() => repo.getMapConfig()).thenAnswer((_) => response.future);
    final container = ProviderContainer(overrides: [
      mapConfigProvider.overrideWith((ref) => MapConfigNotifier(repo)),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(mapConfigProvider.notifier);

    final first = notifier.load();
    final second = notifier.load();
    expect(container.read(mapConfigProvider).loading, isTrue);

    response.complete({
      'available_maps': ['amap', 'tencent', 'osm'],
      'default_map': 'amap',
      'map_enabled': true,
    });
    await Future.wait([first, second]);

    expect(container.read(mapConfigProvider).loaded, isTrue);
    await notifier.load();
    verify(() => repo.getMapConfig()).called(1);
  });

  test('available_maps 过滤：仅保留 高德/腾讯/OSM，去掉 baidu/tianditu', () async {
    when(() => repo.getMapConfig()).thenAnswer((_) async => {
          'available_maps': ['baidu', 'amap', 'tianditu', 'tencent', 'osm'],
          'default_map': 'amap',
          'map_enabled': true,
        });
    final state = await loadState();
    expect(state.layers.map((o) => o.id), ['amap', 'tencent', 'osm']);
    expect(state.defaultId, 'amap');
    expect(state.mapEnabled, isTrue);
  });

  test('default_map 不在交集：回退常量表顺序第一个（amap）', () async {
    when(() => repo.getMapConfig()).thenAnswer((_) async => {
          'available_maps': ['osm', 'tencent'],
          'default_map': 'baidu',
          'map_enabled': true,
        });
    final state = await loadState();
    expect(state.layers.map((o) => o.id), ['tencent', 'osm']);
    expect(state.defaultId, 'tencent');
  });

  test('default_map 在交集：直接用后端指定', () async {
    when(() => repo.getMapConfig()).thenAnswer((_) async => {
          'available_maps': ['amap', 'osm'],
          'default_map': 'osm',
          'map_enabled': true,
        });
    final state = await loadState();
    expect(state.defaultId, 'osm');
  });

  test('map_enabled=false 透传（web 用 !== false 判定）', () async {
    when(() => repo.getMapConfig()).thenAnswer((_) async => {
          'available_maps': ['amap'],
          'default_map': 'amap',
          'map_enabled': false,
        });
    final state = await loadState();
    expect(state.mapEnabled, isFalse);
  });

  test('available_maps 为空：同样使用完整三层兜底', () async {
    when(() => repo.getMapConfig()).thenAnswer((_) async => {
          'available_maps': [],
          'default_map': 'baidu',
          'map_enabled': true,
        });
    final state = await loadState();
    expect(state.layers.map((o) => o.id), ['amap', 'tencent', 'osm']);
    expect(state.defaultId, 'amap');
  });

  test('请求失败：兜底完整三层且启用', () async {
    when(() => repo.getMapConfig()).thenThrow(Exception('network'));
    final state = await loadState();
    expect(state.layers.map((o) => o.id), ['amap', 'tencent', 'osm']);
    expect(state.defaultId, 'amap');
    expect(state.mapEnabled, isTrue);
  });
}
