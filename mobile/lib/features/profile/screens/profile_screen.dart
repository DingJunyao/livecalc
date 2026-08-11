import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/startup_page_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info card：点击进入编辑页，显示昵称与头像
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/profile/account'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  CircleAvatar(
                    radius: 32,
                    foregroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    onForegroundImageError:
                        user?.avatarUrl == null ? null : (_, __) {},
                    child: Text(user?.displayName.isNotEmpty == true ? user!.displayName[0] : '?',
                        style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user?.displayName ?? '用户', style: theme.textTheme.titleLarge),
                    Text(user?.email ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                  ])),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Settings section
          Text('设置', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          Card(child: Column(children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('启动时起始页'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(startupPageDisplayName(ref.watch(startupPageProvider))),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ]),
              onTap: () => _showStartupPageDialog(context, ref),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.scale),
              title: const Text('单位偏好'),
              onTap: () => context.push('/profile/settings/unit-preferences'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text('营养目标'),
              onTap: () => context.push('/profile/settings/nutrition-goals'),
            ),
          ])),
          const SizedBox(height: 24),

          // My data section
          Text('我的数据', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.rate_review_outlined), title: const Text('我的提议'), onTap: () => context.push('/profile/proposals')),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.place_outlined), title: const Text('我的地点'), onTap: () => context.push('/profile/places')),
          ])),
          const SizedBox(height: 32),

          // Logout
          SafeArea(
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('退出登录'),
              style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// 启动时起始页单选对话框：点选即生效并关闭。
Future<void> _showStartupPageDialog(BuildContext context, WidgetRef ref) async {
  final current = ref.read(startupPageProvider);
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('启动时起始页'),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final page in kStartupPages)
                RadioListTile<String>(
                  value: page,
                  title: Text(startupPageDisplayName(page)),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (selected != null && selected != current) {
    await ref.read(startupPageProvider.notifier).setPage(selected);
  }
}


