import 'package:flutter/foundation.dart';

import 'compliance_repository.dart';

/// 进程内缓存的公开合规配置（`/api/v1/app/config`）。
///
/// 用单例 ValueNotifier 而不是 Riverpod：地图角标要在任意 widget 里零依赖使用，
/// 且很多组件测试不建 ProviderScope。加载失败保持 null，调用方自行降级。
class AppComplianceCache {
  AppComplianceCache._();

  static final AppComplianceCache instance = AppComplianceCache._();

  final ValueNotifier<AppComplianceConfig?> config = ValueNotifier(null);

  bool _started = false;

  /// 首次访问时拉一次；并发调用共享同一次加载。
  Future<void> ensureLoaded() async {
    if (_started) return;
    _started = true;
    final loaded = await ComplianceRepository().fetchAppConfig();
    if (loaded != null) config.value = loaded;
  }

  /// 测试/退出登录后重置。
  void reset() {
    _started = false;
    config.value = null;
  }
}
