import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/offline_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android 全面屏：让应用内容延伸到系统导航栏区域（API < 35 默认不开启），
  // 配合 app.dart 中透明的系统栏样式，避免底部手势提示线区域显示黑色。
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final connectivity = ConnectivityService();
  await connectivity.initialize();

  final syncService = OfflineSyncService();
  syncService.start(connectivity.onConnectivityChanged);

  runApp(
    const ProviderScope(
      child: LiveCalcApp(),
    ),
  );
}
