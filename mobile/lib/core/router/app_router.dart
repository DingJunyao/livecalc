import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/prices/screens/price_list_screen.dart';
import '../../features/prices/screens/price_record_form_screen.dart';
import '../../features/prices/screens/quick_fill_screen.dart';
import '../../features/recipes/screens/recipe_list_screen.dart';
import '../../features/recipes/screens/recipe_detail_screen.dart';
import '../../features/recipes/screens/recipe_analysis_screen.dart';
import '../../features/ingredients/screens/ingredient_list_screen.dart';
import '../../features/ingredients/screens/ingredient_detail_screen.dart';
import '../../features/products/screens/product_list_screen.dart';
import '../../features/products/screens/product_detail_screen.dart';
import '../../features/merchants/screens/merchant_list_screen.dart';
import '../../features/merchants/screens/merchant_detail_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/my_proposals_screen.dart';
import '../../features/profile/screens/my_places_screen.dart';
import '../../features/profile/screens/unit_preferences_screen.dart';
import '../../features/profile/screens/nutrition_goals_screen.dart';
import '../../features/profile/providers/startup_page_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/server_provider.dart';
import '../../features/auth/screens/server_config_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/edit_account_screen.dart';
import '../../features/prices/providers/price_provider.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter(WidgetRef ref, Listenable refreshListenable) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      // Read fresh values on every redirect evaluation so auth/server state
      // changes are reflected immediately (driven by refreshListenable).
      final authState = ref.read(authProvider);
      final serverUrl = ref.read(serverConfigProvider);
      final status = authState.status;
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' ||
          location == '/register' ||
          location == '/server-config';
      final isSplash = location == '/splash';

      // While the session is being restored (incl. the startup connectivity
      // check), hold on the splash screen so we never flash the server-config
      // or login pages before we know where to land.
      if (status == AuthStatus.initial || status == AuthStatus.loading) {
        return isSplash ? null : '/splash';
      }

      if (status == AuthStatus.authenticated) {
        return (isAuthRoute || isSplash)
            ? '/${ref.read(startupPageProvider)}'
            : null;
      }

      // The server was unreachable: send the user back to server setup to
      // start over, keeping the saved address pre-filled for an easy retry.
      if (authState.serverUnreachable) {
        return location == '/server-config' ? null : '/server-config';
      }

      // unauthenticated / error
      final hasServer = serverUrl != null && serverUrl.isNotEmpty;
      if (!hasServer) {
        return location == '/server-config' ? null : '/server-config';
      }
      return isAuthRoute ? null : '/login';
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/server-config',
        name: RouteNames.serverConfig,
        builder: (_, __) => const ServerConfigScreen(),
      ),
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: RouteNames.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: RouteNames.home,
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/prices',
            name: RouteNames.prices,
            builder: (_, __) => const PriceListScreen(),
          ),
          GoRoute(
            path: '/prices/quick-fill',
            name: 'quick-fill',
            builder: (_, __) => const QuickFillScreen(),
          ),
          GoRoute(
            path: '/prices/record',
            name: RouteNames.priceRecord,
            builder: (_, __) => const PriceRecordFormScreen(),
          ),
          GoRoute(
            path: '/recipes',
            name: RouteNames.recipes,
            builder: (_, __) => const RecipeListScreen(),
          ),
          GoRoute(
            path: '/recipes/:id',
            name: 'recipe-detail',
            builder: (_, state) => RecipeDetailScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/recipes/:id/analysis',
            name: 'recipe-analysis',
            builder: (_, state) => RecipeAnalysisScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/ingredients',
            name: RouteNames.ingredients,
            builder: (_, __) => const IngredientListScreen(),
          ),
          GoRoute(
            path: '/ingredients/:id',
            name: 'ingredient-detail',
            builder: (_, state) => IngredientDetailScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/products',
            name: RouteNames.products,
            builder: (_, __) => const ProductListScreen(),
          ),
          GoRoute(
            path: '/products/:id',
            name: 'product-detail',
            builder: (_, state) => ProductDetailScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/merchants',
            name: RouteNames.merchants,
            builder: (_, __) => const MerchantListScreen(),
          ),
          GoRoute(
            path: '/merchants/map',
            name: 'merchant-map',
            builder: (_, __) =>
                const MerchantListScreen(initialShowMap: true),
          ),
          GoRoute(
            path: '/merchants/:id',
            name: 'merchant-detail',
            builder: (_, state) => MerchantDetailScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/profile',
            name: RouteNames.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/profile/account',
            name: RouteNames.editAccount,
            builder: (_, __) => const EditAccountScreen(),
          ),
          GoRoute(
            path: '/profile/proposals',
            name: RouteNames.myProposals,
            builder: (_, __) => const MyProposalsScreen(),
          ),
          GoRoute(
            path: '/profile/places',
            name: RouteNames.myPlaces,
            builder: (_, __) => const MyPlacesScreen(),
          ),
          GoRoute(
            path: '/profile/settings/unit-preferences',
            name: 'unit-preferences',
            builder: (_, __) => const UnitPreferencesScreen(),
          ),
          GoRoute(
            path: '/profile/settings/nutrition-goals',
            name: 'nutrition-goals',
            builder: (_, __) => const NutritionGoalsScreen(),
          ),
        ],
      ),
    ],
  );
}

/// 底栏/侧栏 tab 定义：prefixes 决定选中态归属（含子路由前缀匹配）。
class _Tab {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.prefixes,
    this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final List<String> prefixes;
  final String? route;
}

const _homeTab = _Tab(
    label: '推荐',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    prefixes: ['/home'],
    route: '/home');
const _pricesTab = _Tab(
    label: '计价',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    prefixes: ['/prices'],
    route: '/prices');
const _recipesTab = _Tab(
    label: '菜谱',
    icon: Icons.restaurant_outlined,
    selectedIcon: Icons.restaurant,
    prefixes: ['/recipes'],
    route: '/recipes');
const _ingredientsTab = _Tab(
    label: '原料',
    icon: Icons.spa_outlined,
    selectedIcon: Icons.spa,
    prefixes: ['/ingredients'],
    route: '/ingredients');
const _productsTab = _Tab(
    label: '商品',
    icon: Icons.shopping_bag_outlined,
    selectedIcon: Icons.shopping_bag,
    prefixes: ['/products'],
    route: '/products');
const _merchantsTab = _Tab(
    label: '商家',
    icon: Icons.store_outlined,
    selectedIcon: Icons.store,
    prefixes: ['/merchants'],
    route: '/merchants');
const _profileTab = _Tab(
    label: '我的',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    prefixes: ['/profile'],
    route: '/profile');
const _moreTab = _Tab(
    label: '更多',
    icon: Icons.menu,
    selectedIcon: Icons.menu,
    prefixes: ['/ingredients', '/products', '/merchants', '/profile']);

const _desktopTabs = [
  _homeTab,
  _pricesTab,
  _recipesTab,
  _ingredientsTab,
  _productsTab,
  _merchantsTab,
  _profileTab,
];
const _mobileTabs = [_homeTab, _pricesTab, _recipesTab, _moreTab];
const _moreMenuTabs = [
  _ingredientsTab,
  _productsTab,
  _merchantsTab,
  _profileTab,
];

/// 当前路由在哪个 tab 下：前缀精确相等或「前缀/」开头。
int _tabIndexFor(List<_Tab> tabs, String location) {
  for (var i = 0; i < tabs.length; i++) {
    if (tabs[i].prefixes
        .any((p) => location == p || location.startsWith('$p/'))) {
      return i;
    }
  }
  return -1;
}

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  final Widget child;
  const ScaffoldWithNavBar({super.key, required this.child});

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar> {
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final wide = MediaQuery.of(context).size.width >= 600;
    final tabs = wide ? _desktopTabs : _mobileTabs;
    final selectedIndex = _tabIndexFor(tabs, location);

    return Scaffold(
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (i) =>
                  _onTabSelected(context, _desktopTabs[i]),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final t in _desktopTabs)
                  NavigationRailDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: Text(t.label),
                  ),
              ],
            ),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: wide ? null : _buildBottomNav(context, selectedIndex),
    );
  }

  Widget _buildBottomNav(BuildContext context, int selectedIndex) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _mobileTabs.length; i++)
                Expanded(
                  child: _NavItem(
                    // key 用 label（如 tab-计价），避免 route 带 '/' 前缀与测试长按断言不一致
                    itemKey: ValueKey('tab-${_mobileTabs[i].label}'),
                    label: _mobileTabs[i].label,
                    icon: _mobileTabs[i].icon,
                    selectedIcon: _mobileTabs[i].selectedIcon,
                    selected: i == selectedIndex,
                    onTap: () => _onTabSelected(context, _mobileTabs[i]),
                    onLongPress: _mobileTabs[i] == _pricesTab
                        ? _onLongPressPrices
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTabSelected(BuildContext context, _Tab tab) {
    if (tab.route == null) {
      _showMoreMenu(context);
      return;
    }
    context.go(tab.route!);
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in _moreMenuTabs)
              ListTile(
                leading: Icon(t.selectedIcon),
                title: Text(t.label),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go(t.route!);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 长按「计价」：切到计价 tab 并打开新增价格记录页，
  /// 保存成功（pop true）后刷新计价列表。
  Future<void> _onLongPressPrices() async {
    context.go('/prices');
    final saved = await context.push<bool>('/prices/record');
    if (saved == true && mounted) {
      ref.read(priceListProvider.notifier).loadRecords();
    }
  }
}

/// 自绘底栏项：外观对齐 M3 NavigationBar（选中胶囊 + 填充图标 + 加粗标签）。
class _NavItem extends StatelessWidget {
  final Key? itemKey;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _NavItem({
    this.itemKey,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return InkWell(
      key: itemKey,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Semantics(
        // 对齐 M3 NavigationBar 自带语义：选中态 + 按钮角色 + 标签；
        // excludeSemantics 丢弃子 Text 语义，避免标签与文本合并成「推荐\n推荐」被读两遍
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: selected
                    ? BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      )
                    : null,
                child: Icon(
                  selected ? selectedIcon : icon,
                  color: selected ? scheme.onSecondaryContainer : color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
