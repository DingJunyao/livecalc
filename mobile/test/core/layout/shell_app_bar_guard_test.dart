import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 源码守卫：保证「显示侧边栏时，所有页面的标题栏上没有任何按钮」。
///
/// 1. 应用内不直接构造 `AppBar(` / `SliverAppBar(`，一律走 `ShellAppBar` /
///    `ShellSliverAppBar`（竖条模式下去掉 leading 与 actions）。
/// 2. 带 `actions` 的 `ShellAppBar` 所在文件必须把动作发布到竖条
///    （`publishShellActions` 或 `saveAppBarActions`），否则按钮进了竖条模式就丢了。
void main() {
  final libDir = Directory('lib');

  Iterable<File> dartFiles() => libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  void _collect(Map<String, String> out, String raw) {
    // 去掉参数前导的整行注释（扫描时跳过了注释，但文本还留在片段开头）
    var chunk = raw.trimLeft();
    while (chunk.startsWith('//')) {
      final nl = chunk.indexOf('\n');
      if (nl < 0) return;
      chunk = chunk.substring(nl + 1).trimLeft();
    }
    final m = RegExp(r'^\s*(?:required\s+)?([a-zA-Z_]\w*)\s*:\s*([\s\S]*)$')
        .firstMatch(chunk.trimRight());
    if (m != null) out[m.group(1)!] = m.group(2)!.trim();
  }

  /// 从 `(` 开始扫到与之匹配的 `)`，返回「顶层命名参数名 → 参数表达式」。
  ///
  /// 只认括号 / 方括号 / 花括号深度为 0 处的 `名字:`，字符串与注释里的内容跳过。
  Map<String, String> namedArgs(String src, int open) {
    final out = <String, String>{};
    var depth = 0;
    var i = open + 1;
    var start = open + 1;
    String? quote;
    var lineComment = false;
    var blockComment = false;
    for (; i < src.length; i++) {
      final c = src[i];
      final next = i + 1 < src.length ? src[i + 1] : '';
      if (lineComment) {
        if (c == '\n') {
          lineComment = false;
        }
        continue;
      }
      if (blockComment) {
        if (c == '*' && next == '/') {
          blockComment = false;
          i++;
        }
        continue;
      }
      if (quote != null) {
        if (c == r'\') {
          i++;
        } else if (c == quote) {
          quote = null;
        }
        continue;
      }
      if (c == '/' && next == '/') {
        lineComment = true;
        continue;
      }
      if (c == '/' && next == '*') {
        blockComment = true;
        i++;
        continue;
      }
      if (c == "'" || c == '"') {
        quote = c;
        continue;
      }
      if (c == '(' || c == '[' || c == '{') {
        depth++;
        continue;
      }
      if (c == ')' || c == ']' || c == '}') {
        depth--;
        if (depth < 0) {
          _collect(out, src.substring(start, i));
          break;
        }
        continue;
      }
      if (depth == 0 && c == ',') {
        _collect(out, src.substring(start, i));
        start = i + 1;
      }
    }
    return out;
  }

  bool effectivelyEmpty(String expr) =>
      RegExp(r'^(null|(const\s+)?(\[\s*\]|List<Widget>\.empty\(\)))$')
          .hasMatch(expr);

  test('应用内不直接构造 AppBar / SliverAppBar（一律走 ShellAppBar）', () {
    final raw = RegExp(r'(?<![A-Za-z_.])(Sliver)?AppBar\(');
    final offenders = <String>[];
    for (final file in dartFiles()) {
      if (file.path.endsWith('core/layout/shell_app_bar.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (raw.hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '竖条模式下标题栏不能出现按钮：请改用 ShellAppBar / '
            'ShellSliverAppBar（core/layout/shell_app_bar.dart）。\n'
            '${offenders.join('\n')}');
  });

  test('带 actions 的 ShellAppBar 所在文件必须把动作发布到竖条', () {
    final call = RegExp(r'\bShell(Sliver)?AppBar\(');
    final offenders = <String>[];
    for (final file in dartFiles()) {
      final src = file.readAsStringSync();
      final publishes = src.contains('publishShellActions(') ||
          src.contains('saveAppBarActions(');
      for (final m in call.allMatches(src)) {
        final args = namedArgs(src, m.end - 1);
        final actions = args['actions'];
        if (actions == null || effectivelyEmpty(actions)) continue;
        if (!publishes) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          offenders.add('${file.path}:$line  ${m.group(0)} … actions:');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '竖条模式下标题栏不渲染 actions：这些页面的动作会丢失，'
            '请在 build 里按 context.shellRailMode 调用 '
            'context.publishShellActions(...)（或改用 saveAppBarActions）。\n'
            '${offenders.join('\n')}');
  });

  test('守卫自身的解析：能识别嵌套与字符串里的括号', () {
    const src = 'ShellAppBar(\n'
        '  title: Text("a),b"), // actions: [\n'
        '  actions: rail\n'
        '      ? const []\n'
        '      : [IconButton(icon: Icon(Icons.add), onPressed: () {})],\n'
        '  bottom: TabBar(tabs: [Tab(text: \',\')]),\n'
        ');';
    final open = src.indexOf('(');
    final args = namedArgs(src, open);
    expect(args.keys, ['title', 'actions', 'bottom']);
    expect(effectivelyEmpty(args['title']!), isFalse);
    expect(effectivelyEmpty(args['actions']!), isFalse, reason: '三元表达式整体不是空列表');
    expect(effectivelyEmpty('const []'), isTrue);
    expect(effectivelyEmpty('null'), isTrue);
  });
}
