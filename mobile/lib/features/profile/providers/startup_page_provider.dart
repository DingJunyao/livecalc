import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 允许的起始页值：home（推荐）/ prices（计价）/ recipes（菜谱）。
const kStartupPages = ['home', 'prices', 'recipes'];

/// 起始页值 → 中文显示名（未知值兜底为「推荐」）。
String startupPageDisplayName(String page) {
  switch (page) {
    case 'prices':
      return '计价';
    case 'recipes':
      return '菜谱';
    default:
      return '推荐';
  }
}

/// 启动时起始页配置，仅存本地 SharedPreferences，不上云端。
class StartupPageNotifier extends StateNotifier<String> {
  StartupPageNotifier() : super('home');
  static const _key = 'startup_page';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (kStartupPages.contains(saved)) state = saved!;
  }

  Future<void> setPage(String page) async {
    assert(kStartupPages.contains(page));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, page);
    state = page;
  }
}

final startupPageProvider =
    StateNotifierProvider<StartupPageNotifier, String>((ref) {
  return StartupPageNotifier();
});
