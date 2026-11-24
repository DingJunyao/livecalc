import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/layout/shell_chrome.dart';

/// 竖条动作按「发布者路由」隔离：转场中上一页的重建不能污染新页面。
/// 对应真机报障：个人中心残留「新增」、单位偏好返回后残留「保存」对勾、
/// 菜谱分析页残留菜谱详情的收藏/分析/⋮。
void main() {
  // publish 走帧末 notify，需要 binding。
  TestWidgetsFlutterBinding.ensureInitialized();

  ShellAction add() =>
      ShellAction(icon: Icons.add, label: '新增', onPressed: () {});
  ShellAction check() =>
      ShellAction(icon: Icons.check, label: '保存', onPressed: () {});

  test('只渲染当前路由的那一份', () {
    final chrome = ShellChrome();
    chrome.bindLocation('/ingredients');
    chrome.publish(location: '/ingredients', primary: add());
    expect(chrome.primary?.label, '新增');

    // 进入没有发布任何动作的页面：不残留
    chrome.bindLocation('/profile');
    expect(chrome.primary, isNull);
    expect(chrome.actions, isEmpty);
  });

  test('旧页在转场中重建后重新发布，也不会出现在新页面', () {
    final chrome = ShellChrome();
    chrome.bindLocation('/recipes/1');
    chrome.publish(location: '/recipes/1', actions: [check()]);

    // 进入分析页（不发布）；随后旧页（详情）因转场重建再次 publish
    chrome.bindLocation('/recipes/1/analysis');
    expect(chrome.actions, isEmpty);
    chrome.publish(location: '/recipes/1', actions: [check()]);
    expect(chrome.actions, isEmpty, reason: '旧路由的发布不影响当前页面');

    // 分析页自己发布后只显示自己的
    chrome.publish(location: '/recipes/1/analysis', actions: [add()]);
    expect(chrome.actions.map((a) => a.label), ['新增']);
  });

  test('返回上一页时，它之前发布的动作仍在（不必等重建）', () {
    final chrome = ShellChrome();
    chrome.bindLocation('/profile/calc-scopes');
    chrome.publish(location: '/profile/calc-scopes', primary: add());
    chrome.bindLocation('/profile');
    expect(chrome.primary, isNull);
    chrome.bindLocation('/profile/calc-scopes');
    expect(chrome.primary?.label, '新增');
  });

  test('clear 清空全部路由', () {
    final chrome = ShellChrome();
    chrome.bindLocation('/a');
    chrome.publish(location: '/a', primary: add());
    chrome.clear();
    expect(chrome.primary, isNull);
    expect(chrome.actions, isEmpty);
  });

  test('条目数有上限（不会无限增长）', () {
    final chrome = ShellChrome();
    for (var i = 0; i < ShellChrome.maxEntries + 5; i++) {
      chrome.bindLocation('/r$i');
      chrome.publish(location: '/r$i', primary: add());
    }
    chrome.bindLocation('/r0');
    expect(chrome.primary, isNull, reason: '最旧的条目应被裁掉');
    chrome.bindLocation('/r${ShellChrome.maxEntries + 4}');
    expect(chrome.primary, isNotNull);
  });
}
