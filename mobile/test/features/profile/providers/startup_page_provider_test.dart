import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:com_a4ding_livecalc/features/profile/providers/startup_page_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('默认值为 home（推荐）', () {
    SharedPreferences.setMockInitialValues({});
    expect(StartupPageNotifier().state, 'home');
  });

  test('load 读取已保存的配置', () async {
    SharedPreferences.setMockInitialValues({'startup_page': 'prices'});
    final n = StartupPageNotifier();
    await n.load();
    expect(n.state, 'prices');
  });

  test('load 忽略非法值，保持默认', () async {
    SharedPreferences.setMockInitialValues({'startup_page': 'merchants'});
    final n = StartupPageNotifier();
    await n.load();
    expect(n.state, 'home');
  });

  test('setPage 写入 SharedPreferences 并更新 state', () async {
    SharedPreferences.setMockInitialValues({});
    final n = StartupPageNotifier();
    await n.setPage('recipes');
    expect(n.state, 'recipes');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('startup_page'), 'recipes');
  });

  test('displayName 中文映射', () {
    expect(startupPageDisplayName('home'), '推荐');
    expect(startupPageDisplayName('prices'), '计价');
    expect(startupPageDisplayName('recipes'), '菜谱');
    expect(startupPageDisplayName('bogus'), '推荐'); // 兜底
  });
}
