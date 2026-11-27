import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../../features/legal/app_compliance_cache.dart';
import '../../features/legal/compliance_repository.dart';
import '../../l10n/app_localizations.dart';

/// 地图角落的「数据来源 · 审图号」角标。
///
/// 合规依据：自然资源部/工信部《关于规范移动互联网应用程序中登载使用地图行为的通知》
/// （自然资办函〔2024〕972 号）要求在地图的适当位置显著标注审图号、引用地图注明来源。
///
/// 审图号按「实际展示的底图」取自服务器配置（管理端 → 合规信息）：
/// - iOS：Apple 地图（中国区数据由高德提供）一条；
/// - Android：当前选中的瓦片底图（高德/腾讯/天地图/OSM）。
/// 卫星影像另有一个审图号（[satellite]），不能拿普通底图的号顶替。
/// 服务器未配置或不可达时不渲染（不编造审图号）。
class MapAttribution extends StatefulWidget {
  /// 当前实际显示的底图 id（amap / tencent / osm / tianditu / baidu / apple）。
  final String layerId;

  /// 角标位置，默认左下角（右上角通常被底图切换/定位按钮占用）。
  final AlignmentGeometry alignment;

  /// 当前是否显示卫星影像。
  final bool satellite;

  const MapAttribution({
    super.key,
    required this.layerId,
    this.alignment = AlignmentDirectional.bottomStart,
    this.satellite = false,
  });

  @override
  State<MapAttribution> createState() => _MapAttributionState();
}

class _MapAttributionState extends State<MapAttribution> {
  @override
  void initState() {
    super.initState();
    // 幂等：全进程只拉一次；失败保持 null（不渲染角标）
    AppComplianceCache.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppComplianceConfig?>(
      valueListenable: AppComplianceCache.instance.config,
      builder: (context, config, _) {
        if (config == null || !config.mapEnabled) {
          return const SizedBox.shrink();
        }
        final info = _resolve(config);
        if (info == null) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context);
        final source = info.note.isEmpty
            ? info.displayName
            : '${info.displayName}（${info.note}）';
        // 卫星图必须标卫星审图号；没填就提示待补，不能拿普通底图的号顶替
        final approvalNo =
            widget.satellite ? info.approvalNoSatellite : info.approvalNo;
        final approval = approvalNo.isEmpty
            ? l10n.mapApprovalPending
            : '${l10n.aboutApprovalNo} $approvalNo';

        return IgnorePointer(
          child: Align(
            alignment: widget.alignment,
            child: Container(
              margin: const EdgeInsets.all(6),
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$source · $approval',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  MapProviderInfo? _resolve(AppComplianceConfig config) {
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (isIos) return config.appleMap;
    for (final provider in config.mapProviders) {
      if (provider.key == widget.layerId) return provider;
    }
    return null;
  }
}
