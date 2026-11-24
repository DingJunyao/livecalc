// heatmap_canvas.dart — 商家物价热力图画布（flutter_map 统一渲染）。
// 每商家一个着色圆点（按价格分位分档：绿→红），点击弹出商家名+价格+样本数。
// 不复用 MerchantMapView：那是商家列表形态（药丸标记/常用地点/定位），
// 热力是对比页专属形态，独立组件避免双端（iOS 原生地图）回归风险。
// 底图图层从 mapConfigProvider 取默认层（与商家地图同一套瓦片配置）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../merchants/providers/map_config_provider.dart';
// iOS 用苹果地图 SDK（与商家地图一致）；Android 用 flutter_map
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple;

class HeatmapPoint {
  final int merchantId;
  final String name;
  final double latitude;
  final double longitude;
  final double price;
  final bool isStale;
  final int sampleCount;
  final double? priceIndex;

  const HeatmapPoint({
    required this.merchantId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.price,
    required this.isStale,
    required this.sampleCount,
    this.priceIndex,
  });

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return HeatmapPoint(
      merchantId: (json['merchant_id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      price: toDouble(json['price']),
      isStale: json['is_stale'] == true,
      sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
      priceIndex:
          json['price_index'] == null ? null : toDouble(json['price_index']),
    );
  }
}

class HeatmapBuckets {
  final double? p25;
  final double? p50;
  final double? p75;
  final double? p90;

  const HeatmapBuckets({this.p25, this.p50, this.p75, this.p90});

  factory HeatmapBuckets.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return HeatmapBuckets(
      p25: toDouble(json['p25']),
      p50: toDouble(json['p50']),
      p75: toDouble(json['p75']),
      p90: toDouble(json['p90']),
    );
  }

  bool get hasData => p50 != null;
}

const List<Color> kHeatmapColors = [
  Color(0xFF2E7D32), // 绿 ≤p25
  Color(0xFF7CB342), // 浅绿 p25-p50
  Color(0xFFF9A825), // 黄 p50-p75
  Color(0xFFEF6C00), // 橙 p75-p90
  Color(0xFFC62828), // 红 >p90
];

Color heatmapColorFor(double price, HeatmapBuckets? buckets) {
  if (buckets == null || !buckets.hasData) return kHeatmapColors[1];
  final b = buckets;
  if (price <= (b.p25 ?? b.p50!)) return kHeatmapColors[0];
  if (price <= b.p50!) return kHeatmapColors[1];
  if (price <= (b.p75 ?? b.p50!)) return kHeatmapColors[2];
  if (price <= (b.p90 ?? b.p75 ?? b.p50!)) return kHeatmapColors[3];
  return kHeatmapColors[4];
}

class HeatmapCanvas extends ConsumerStatefulWidget {
  final List<HeatmapPoint> points;
  final HeatmapBuckets? buckets;
  final bool loading;
  final bool overallMode; // overall=显示物价指数；item=显示价格
  final String userCurrency;
  final fm.TileProvider? tileProvider; // 测试注入内存瓦片

  const HeatmapCanvas({
    super.key,
    required this.points,
    this.buckets,
    this.loading = false,
    this.overallMode = false,
    this.userCurrency = 'CNY',
    this.tileProvider,
  });

  @override
  ConsumerState<HeatmapCanvas> createState() => _HeatmapCanvasState();
}

class _HeatmapCanvasState extends ConsumerState<HeatmapCanvas> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final mapCfg = ref.watch(mapConfigProvider);
    final layer = mapCfg.layers.isEmpty
        ? null
        : (mapCfg.layers.where((o) => o.id == mapCfg.defaultId).firstOrNull ??
            mapCfg.layers.first);
    final points = widget.points
        .where((p) => p.latitude != 0 || p.longitude != 0)
        .toList();

    // iOS：苹果地图 SDK（与商家地图一致）；圆点为 MapKit Circle 着色覆盖
    if (Platform.isIOS) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 420,
              child: apple.AppleMap(
                initialCameraPosition: apple.CameraPosition(
                  target: points.isEmpty
                      ? const apple.LatLng(34.5, 113.6)
                      : apple.LatLng(
                          points.first.latitude, points.first.longitude),
                  zoom: 10,
                ),
                circles: {
                  for (final p in points)
                    apple.Circle(
                      circleId: apple.CircleId('heat-${p.merchantId}'),
                      center: apple.LatLng(p.latitude, p.longitude),
                      radius: 800,
                      fillColor: heatmapColorFor(p.price, widget.buckets)
                          .withValues(alpha: 0.55),
                      strokeWidth: 1,
                      strokeColor: Colors.white,
                      onTap: () => _showPointSheet(p),
                    ),
                },
              ),
            ),
          ),
          if (widget.buckets != null && widget.buckets!.hasData)
            _buildLegend(theme),
          if (widget.loading)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }

    // Android / 其它平台：flutter_map
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 420,
            child: points.isEmpty
                ? Center(
                    child: Text(l10n.compareHeatmapEmpty,
                        style: theme.textTheme.bodyMedium),
                  )
                : fm.FlutterMap(
                    options: const fm.MapOptions(
                      initialCenter: latlong.LatLng(34.5, 113.6),
                      initialZoom: 10,
                    ),
                    children: [
                      if (layer != null)
                        fm.TileLayer(
                          urlTemplate: layer.urlTemplate,
                          subdomains: layer.subdomains,
                          tms: layer.tms,
                          userAgentPackageName: 'livecalc_mobile',
                          tileProvider: widget.tileProvider,
                        ),
                      fm.MarkerLayer(
                        markers: [
                          for (final p in points)
                            fm.Marker(
                              key: ValueKey('heat-${p.merchantId}'),
                              point: latlong.LatLng(p.latitude, p.longitude),
                              width: 22,
                              height: 22,
                              child: GestureDetector(
                                onTap: () => _showPointSheet(p),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        heatmapColorFor(p.price, widget.buckets)
                                            .withValues(alpha: 0.75),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
        // 图例（iOS / flutter_map 分支共用）
        if (widget.buckets != null && widget.buckets!.hasData)
          _buildLegend(theme),
        if (widget.loading)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  /// 分档图例（右下角浮层）。
  Widget _buildLegend(ThemeData theme) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(blurRadius: 4, color: Colors.black26),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendRow(theme, 0, _fmtBucket(widget.buckets!.p25, '≤')),
            _legendRow(theme, 1,
                '${_fmtVal(widget.buckets!.p25)} ~ ${_fmtVal(widget.buckets!.p50)}'),
            _legendRow(theme, 2,
                '${_fmtVal(widget.buckets!.p50)} ~ ${_fmtVal(widget.buckets!.p75)}'),
            _legendRow(theme, 3,
                '${_fmtVal(widget.buckets!.p75)} ~ ${_fmtVal(widget.buckets!.p90)}'),
            _legendRow(theme, 4, _fmtBucket(widget.buckets!.p90, '>')),
          ],
        ),
      ),
    );
  }

  String _fmtVal(double? v) {
    if (v == null) return '—';
    if (widget.overallMode) {
      final r = (v * 10).round() / 10;
      return r == r.roundToDouble() ? r.round().toString() : r.toString();
    }
    return formatMoney(v, widget.userCurrency);
  }

  String _fmtBucket(double? v, String prefix) {
    if (v == null) return '—';
    return '$prefix ${_fmtVal(v)}';
  }

  Widget _legendRow(ThemeData theme, int colorIndex, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: kHeatmapColors[colorIndex],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  void _showPointSheet(HeatmapPoint p) {
    final l10n = AppLocalizations.of(context);
    final valueLabel = widget.overallMode
        ? '${l10n.comparePriceIndexCaption}: ${p.priceIndex ?? '—'}'
        : '${formatMoney(p.price, widget.userCurrency)} / ${l10n.compareTrendUnit}';
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(valueLabel, style: Theme.of(ctx).textTheme.bodyLarge),
              if (p.sampleCount > 0)
                Text('${p.sampleCount} ${l10n.compareSampleCountUnit}',
                    style: Theme.of(ctx).textTheme.bodySmall),
              if (p.isStale)
                Text(l10n.compareStaleHint,
                    style: Theme.of(ctx)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(ctx).colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
