// 临时预览入口（不提交）：跳过登录，用真实壳层 + 真实布局组件渲染
// 代表性页面，供在 iPhone Duo 模拟器上截图查看适配效果。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:com_a4ding_livecalc/core/layout/shell_chrome.dart';
import 'package:com_a4ding_livecalc/core/router/app_router.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/widgets/detail_two_column.dart';
import 'package:com_a4ding_livecalc/shared/widgets/save_action_button.dart';
import 'package:com_a4ding_livecalc/features/profile/providers/save_button_position_provider.dart';

void main() => runApp(ProviderScope(child: _PreviewApp()));

/// 与正式 App 相同：壳层写入、builder 里套给整棵导航树（浮层全宽 / 避让摄像头）。
final _overlayInsets = ShellOverlayInsets();

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router(),
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF558B2F)),
      ),
      builder: (context, child) =>
          ShellOverlayInsetsScope(insets: _overlayInsets, child: child!),
    );
  }
}

const _initialRoute =
    String.fromEnvironment('PREVIEW_ROUTE', defaultValue: '/prices');

GoRouter _router() => GoRouter(
      initialLocation: _initialRoute,
      routes: [
        ShellRoute(
          builder: (_, __, child) => ScaffoldWithNavBar(
            child: child,
            overlayInsets: _overlayInsets,
          ),
          routes: [
            for (final r in const [
              '/home',
              '/prices',
              '/recipes',
              '/products',
              '/ingredients',
              '/merchants',
              '/compare',
              '/favorites',
              '/plans',
              '/profile',
            ])
              GoRoute(path: r, builder: (_, __) => _pageFor(r)),
            GoRoute(
                path: '/prices/record',
                builder: (_, __) => const _PreviewFormPage()),
            GoRoute(path: '/plans/1', builder: (_, __) => _pageFor('/plans')),
            GoRoute(
                path: '/recipes/1',
                builder: (_, __) => const _RecipePreviewPage()),
          ],
        ),
      ],
    );

Widget _pageFor(String route) => switch (route) {
      '/prices' => const _ListPage(title: '计价', columns: true),
      '/ingredients' => const _GridPage(title: '原料'),
      '/recipes' => const _GridPage(title: '菜谱'),
      '/merchants' => const _MerchantPage(),
      '/plans' => const _DetailPage(),
      _ => _SimplePage(title: route),
    };

// ─── 计价：两列列表 ───
class _ListPage extends StatelessWidget {
  const _ListPage({required this.title, required this.columns});
  final String title;
  final bool columns;

  static const _rows = [
    ('尖椒', '湖滨区永辉超市 · 今天 09:12', '¥6.98 /斤'),
    ('五花肉', '涧南农贸市场 · 昨天 18:40', '¥15.80 /斤'),
    ('鸡蛋', '明发商业广场店 · 昨天 07:32', '¥5.20 /斤'),
    ('茉莉香米', '大润发 · 11-18', '¥39.90 /5kg袋'),
    ('老姜', '涧南农贸市场 · 11-20', '¥12.50 /斤'),
    ('西红柿', '湖滨区永辉超市 · 11-21', '¥4.30 /斤'),
    ('黄瓜', '涧南农贸市场 · 11-21', '¥3.10 /斤'),
    ('土豆', '大润发 · 11-19', '¥2.60 /斤'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 620 ? 2 : 1);
        Widget row(int i) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Text(_rows[i].$1.characters.first),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_rows[i].$1,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(_rows[i].$2,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                    Text(_rows[i].$3,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
        if (cols == 1) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [for (var i = 0; i < _rows.length; i++) row(i)],
          );
        }
        final rows = (_rows.length + cols - 1) ~/ cols;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows,
          itemBuilder: (ctx, r) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c2 = 0; c2 < cols; c2++) ...[
                if (c2 > 0) const SizedBox(width: 8),
                Expanded(
                  child: r * cols + c2 < _rows.length
                      ? row(r * cols + c2)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

// ─── 原料/菜谱：网格 ───
class _GridPage extends StatelessWidget {
  const _GridPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 620 ? 2 : 1);
        final items = List.generate(8, (i) => i);
        final width = (c.maxWidth - 24 - 8 * (cols - 1)) / cols;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in items)
                  SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text('${i + 1}'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${title}条目 ${i + 1}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                  Text('分类 · ¥${(i + 3) * 1.5} /斤',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color:
                                                  theme.colorScheme.tertiary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

// ─── 商家：左 1/3 列表 + 右 2/3 地图 ───
class _MerchantPage extends StatelessWidget {
  const _MerchantPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('商家')),
      body: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 620) {
          return ListView(
            children: [for (var i = 0; i < 6; i++) _tile(theme, i)],
          );
        }
        return Row(
          children: [
            SizedBox(
              width: c.maxWidth / 3,
              child: ListView(
                children: [for (var i = 0; i < 6; i++) _tile(theme, i)],
              ),
            ),
            VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),
            Expanded(
              child: Container(
                color: const Color(0xFFE9EEDA),
                child: Stack(
                  children: [
                    for (final p in const [
                      Offset(0.25, 0.3),
                      Offset(0.6, 0.25),
                      Offset(0.45, 0.65),
                      Offset(0.75, 0.55),
                    ])
                      Align(
                        alignment: Alignment(p.dx * 2 - 1, p.dy * 2 - 1),
                        child: Icon(Icons.location_on,
                            size: 34, color: theme.colorScheme.primary),
                      ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Chip(label: Text('地图占 2/3 宽')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _tile(ThemeData theme, int i) => ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: const Icon(Icons.store, size: 18),
        ),
        title: Text('商家 ${i + 1}'),
        subtitle: Text('湖滨区某路 ${i + 8} 号'),
        trailing: const Icon(Icons.gps_fixed, size: 18),
      );
}

// ─── 试算详情：按 web 栅格分栏 ───
class _DetailPage extends StatelessWidget {
  const _DetailPage();

  Widget _card(ThemeData theme, String title, List<String> lines) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(l, style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('黄焖鸡一餐')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          DetailTwoColumn.rows(
            rows: [
              [
                _card(theme, '基本信息', ['2 人份 · 一顿', '简单难度']),
                _card(theme, '合计', ['成本 ¥45.46', '热量 1240 kcal']),
              ],
              [
                _card(theme, '单位与密度', ['1 份 ≈ 350 g']),
                _card(theme, '成本走势', ['30 天 · ¥43–47']),
              ],
              [
                _card(theme, '营养成分', ['蛋白质 86 g', '脂肪 45 g']),
                _card(theme, '价格记录', ['11-22 湖滨区 ¥6.98', '11-19 涧南 ¥7.20']),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SimplePage extends StatelessWidget {
  const _SimplePage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(title)),
      );
}

// ─── 记价表单：竖条里有后退 + 保存 ───
class _PreviewFormPage extends StatelessWidget {
  const _PreviewFormPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const position = SaveButtonPosition.topRight;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !context.shellRailMode,
        leading: context.shellRailMode ? const SizedBox.shrink() : null,
        title: const Text('新增价格记录'),
        actions: saveAppBarActions(
          context: context,
          position: position,
          onSave: () {},
          label: l10n.commonSave,
        ),
      ),
      bottomNavigationBar: saveBottomBar(
        context: context,
        position: position,
        onSave: () {},
        label: l10n.commonSave,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _FieldRow(label: '商品', value: '五花肉'),
          _FieldRow(label: '商家', value: '涧南农贸市场'),
          _FieldRow(label: '价格', value: '15.80'),
          _FieldRow(label: '数量', value: '1 斤'),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 56,
              child: Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline))),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── 菜谱详情：图片+基本信息 ｜ 成本（对齐 web recipe-top-grid） ───
class _RecipePreviewPage extends StatelessWidget {
  const _RecipePreviewPage();

  Widget _card(ThemeData theme, String title, List<String> lines) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(l, style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gallery = Container(
      height: 220,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image, size: 56),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('麻婆豆腐')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DetailTwoColumn.rows(
            rows: [
              [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    gallery,
                    const SizedBox(height: 16),
                    _card(theme, '基本信息', ['荤菜 · 中等 · 1 人份', '参考麻婆豆腐创作']),
                  ],
                ),
                _card(theme, '成本估算', ['¥4.28 / 份', '30 天趋势 · ¥4.0–4.6']),
              ],
              [
                _card(theme, '原料清单', ['豆腐 400g', '肉末 100g']),
                _card(theme, '做法步骤', ['1. 豆腐切块焯水', '2. 炒肉末下豆瓣']),
              ],
              [
                _card(theme, '营养成分', ['能量 719 kcal', '蛋白质 38 g']),
                _card(theme, '小贴士', ['勾芡分两次更挂汁']),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
