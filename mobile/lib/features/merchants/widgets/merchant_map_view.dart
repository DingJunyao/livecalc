import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/widgets/empty_state.dart';
import '../models/merchant.dart';

/// 商家地图（列表内嵌 / 详情位置卡共用）。
class MerchantMapView extends StatelessWidget {
  final List<Merchant> merchants;
  final int? selectedId;
  final MapController? controller;

  const MerchantMapView({
    super.key,
    required this.merchants,
    this.selectedId,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markers = merchants
        .where((m) => m.latitude != null && m.longitude != null)
        .toList();
    if (markers.isEmpty) {
      return const EmptyState(
        icon: Icons.map_outlined,
        title: '暂无商家位置',
        subtitle: '商家缺少坐标信息时无法在地图显示',
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FlutterMap(
        mapController: controller,
        options: const MapOptions(
          initialCenter: LatLng(39.9042, 116.4074),
          initialZoom: 11.0,
          backgroundColor: Color(0xFFE8EAED),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'livecalc_mobile',
          ),
          MarkerLayer(
            markers: [
              for (final m in markers)
                Marker(
                  point: LatLng(m.latitude!, m.longitude!),
                  child: GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(m.name))),
                    child: Icon(
                      Icons.store,
                      color: m.id == selectedId
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      size: m.id == selectedId ? 40 : 30,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
