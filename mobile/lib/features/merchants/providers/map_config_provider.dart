import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/merchant_repository.dart';

/// 可用的底图层（仅用户要求的三种位图瓦片）。
class MapLayerOption {
  final String id; // amap / tencent / osm
  final String label;
  final String urlTemplate;
  final List<String> subdomains;
  final bool gcj02;
  /// 瓦片 y 轴是否为 TMS（从南到北）。腾讯是 TMS，不翻转则北半球取到南半球瓦片。
  final bool tms;

  const MapLayerOption({
    required this.id,
    required this.label,
    required this.urlTemplate,
    this.subdomains = const [],
    required this.gcj02,
    this.tms = false,
  });
}

const amapLayer = MapLayerOption(
  id: 'amap',
  label: '高德',
  urlTemplate:
      'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
  subdomains: ['1', '2', '3', '4'],
  gcj02: true,
);
const tencentLayer = MapLayerOption(
  id: 'tencent',
  label: '腾讯',
  // 样式参数对齐 web leaflet.chinatmsproviders（styleid=3 带标注、无 version）
  urlTemplate:
      'https://rt{s}.map.gtimg.com/tile?z={z}&x={x}&y={y}&type=vector&styleid=3',
  subdomains: ['0', '1', '2'],
  gcj02: true,
  // 腾讯瓦片 y 轴从南到北（TMS），与高德/OSM 相反，须翻转
  tms: true,
);
const osmLayer = MapLayerOption(
  id: 'osm',
  label: 'OSM',
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  gcj02: false,
);

const mapLayerOptions = <MapLayerOption>[amapLayer, tencentLayer, osmLayer];

/// 兜底图层（请求失败时仅 OSM）。
const osmOnlyLayers = [osmLayer];

class MapConfigState {
  /// 实际可用的图层（与后端 available_maps 求交集）。
  final List<MapLayerOption> layers;
  final String defaultId;
  final bool mapEnabled;
  final bool loading;

  const MapConfigState({
    this.layers = osmOnlyLayers,
    this.defaultId = 'osm',
    this.mapEnabled = true,
    this.loading = false,
  });

  MapConfigState copyWith({
    List<MapLayerOption>? layers,
    String? defaultId,
    bool? mapEnabled,
    bool? loading,
  }) {
    return MapConfigState(
      layers: layers ?? this.layers,
      defaultId: defaultId ?? this.defaultId,
      mapEnabled: mapEnabled ?? this.mapEnabled,
      loading: loading ?? this.loading,
    );
  }
}

class MapConfigNotifier extends StateNotifier<MapConfigState> {
  final MerchantRepository _repo;
  MapConfigNotifier(this._repo) : super(const MapConfigState());

  /// 加载底图配置：available_maps 与三常量交集，default_map 取交集内的，
  /// 否则 amap；请求失败兜底仅 OSM（web 同：失败回退启用）。
  Future<void> load() async {
    state = state.copyWith(loading: true);
    try {
      final data = await _repo.getMapConfig();
      final available =
          (data['available_maps'] as List?)?.cast<String>() ?? const [];
      final layers = mapLayerOptions
          .where((o) => available.contains(o.id))
          .toList();
      final defaultId = layers.any((o) => o.id == data['default_map'])
          ? data['default_map'] as String
          : (layers.isNotEmpty ? layers.first.id : 'osm');
      state = MapConfigState(
        layers: layers.isEmpty ? osmOnlyLayers : layers,
        defaultId: defaultId,
        mapEnabled: data['map_enabled'] != false,
      );
    } catch (_) {
      // 失败回退仅 OSM + 启用（对齐 web 保守策略）
      state = const MapConfigState();
    } finally {
      state = state.copyWith(loading: false);
    }
  }
}

final mapConfigProvider =
    StateNotifierProvider<MapConfigNotifier, MapConfigState>((ref) {
  return MapConfigNotifier(MerchantRepository());
});
