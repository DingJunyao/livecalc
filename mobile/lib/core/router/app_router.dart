import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../layout/device_form.dart';
import '../layout/shell_chrome.dart';
import '../layout/orientation_policy.dart';
import '../layout/vertical_bar_edge.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/ingredients/models/ingredient.dart';
import '../../features/prices/screens/price_list_screen.dart';
import '../../features/prices/screens/paste_import_screen.dart';
import '../../features/prices/screens/price_record_form_screen.dart';
import '../../features/prices/screens/quick_fill_screen.dart';
import '../../features/recipes/screens/recipe_list_screen.dart';
import '../../features/recipes/screens/recipe_detail_screen.dart';
import '../../features/recipes/screens/recipe_form_screen.dart';
import '../../features/recipes/screens/recipe_analysis_screen.dart';
import '../../features/recipes/models/recipe_detail.dart';
import '../../features/legal/legal_document.dart';
import '../../features/legal/screens/legal_document_screen.dart';
import '../../features/legal/screens/about_screen.dart';
import '../../features/ingredients/screens/ingredient_list_screen.dart';
import '../../features/ingredients/screens/ingredient_detail_screen.dart';
import '../../features/ingredients/screens/ingredient_hierarchy_screen.dart';
import '../../features/ingredients/screens/ingredient_form_screen.dart';
import '../../features/products/screens/product_list_screen.dart';
import '../../features/products/screens/product_detail_screen.dart';
import '../../features/products/screens/product_form_screen.dart';
import '../../features/products/models/product.dart';
import '../../features/comparison/screens/compare_screen.dart';
import '../../features/favorites/screens/favorites_screen.dart';
import '../../features/planner/screens/planner_screens.dart';
import '../../features/planner/screens/plan_detail_screen.dart';
import '../../features/merchants/screens/merchant_list_screen.dart';
import '../../features/merchants/screens/merchant_detail_screen.dart';
import '../../features/merchants/screens/merchant_form_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/my_proposals_screen.dart';
import '../../features/profile/screens/my_places_screen.dart';
import '../../features/calc_scope/screens/calc_scope_list_screen.dart';
import '../../features/calc_scope/screens/calc_scope_form_screen.dart';
import '../../features/profile/screens/blacklist_screen.dart';
import '../../features/profile/screens/user_place_form_screen.dart';
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
import '../../l10n/app_localizations.dart';
import '../../shared/screens/nutrition_edit_screen.dart';
import '../../shared/screens/price_record_edit_screen.dart';
import 'route_names.dart';
import 'shell_transition.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// 上次 shell 路由位置，用于计算 tab 切换动画的滑动方向。
String? _lastShellLocation;

///
/// [overlayInsets]：与 `MaterialApp.router` 的 `builder` 里 [ShellOverlayInsetsScope]
/// 共用的浮层安全区信号（不传则壳层自用一个，浮层不做接管——测试桩用）。
GoRouter createAppRouter(
  WidgetRef ref,
  Listenable refreshListenable, {
  ShellOverlayInsets? overlayInsets,
}) {
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
      // 隐私政策/用户协议要能在注册前打开（注册页的同意勾选），
      // 但已登录用户也不应被强制弹回首页，故单独判定。
      final isLegalRoute = location.startsWith('/legal');
      final isPublicRoute = isAuthRoute || isLegalRoute;

      // Startup/session restoration holds on splash. Login and registration
      // also use loading state; keep those forms in place so a failed submit
      // does not bounce the user to another auth page and lose context.
      if (status == AuthStatus.initial || status == AuthStatus.loading) {
        return (isSplash || isPublicRoute) ? null : '/splash';
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
      return isPublicRoute ? null : '/login';
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
      GoRoute(
        path: '/legal/:doc',
        name: RouteNames.legal,
        builder: (_, state) => LegalDocumentScreen(
          document: LegalDocumentX.fromSlug(state.pathParameters['doc']) ??
              LegalDocument.privacy,
        ),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) =>
            ScaffoldWithNavBar(child: child, overlayInsets: overlayInsets),
        routes: [
          GoRoute(
            path: '/entities/:entityType/:entityId/nutrition',
            name: 'entity-nutrition-edit',
            builder: (_, state) {
              final args = state.extra;
              if (args is NutritionEditArguments) {
                return NutritionEditScreen(
                  entityType: args.entityType,
                  entityId: args.entityId,
                  entityName: args.entityName,
                  nutrition: args.nutrition,
                  allowClear: args.allowClear,
                  onSave: args.onSave,
                  onClear: args.onClear,
                );
              }
              return NutritionEditScreen(
                entityType: state.pathParameters['entityType'] ?? 'ingredient',
                entityId:
                    int.tryParse(state.pathParameters['entityId'] ?? '') ?? 0,
              );
            },
          ),
          GoRoute(
            path: '/home',
            name: RouteNames.home,
            pageBuilder: (context, state) => _shellTransitionPage(
              child: const HomeScreen(),
              key: state.pageKey,
              location: state.matchedLocation,
            ),
          ),
          GoRoute(
            path: '/prices',
            name: RouteNames.prices,
            pageBuilder: (context, state) => _shellTransitionPage(
              child: const PriceListScreen(),
              key: state.pageKey,
              location: state.matchedLocation,
            ),
          ),
          GoRoute(
            path: '/prices/quick-fill',
            name: 'quick-fill',
            builder: (_, __) => const QuickFillScreen(),
          ),
          GoRoute(
            path: '/prices/paste-import',
            name: RouteNames.pasteImport,
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return PasteImportScreen(
                merchantId: extra?['merchantId'] as int?,
                historyProductNames:
                    (extra?['historyProductNames'] as List<dynamic>?)
                            ?.cast<String>() ??
                        const <String>[],
              );
            },
          ),
          GoRoute(
            path: '/prices/record',
            name: RouteNames.priceRecord,
            builder: (_, state) => state.extra is PriceRecordFormPrefill
                ? PriceRecordFormScreen(
                    prefill: state.extra as PriceRecordFormPrefill,
                  )
                : const PriceRecordFormScreen(),
          ),
          GoRoute(
            path: '/prices/record/edit',
            name: 'price-record-edit',
            builder: (_, state) => state.extra is PriceRecordFormArguments
                ? PriceRecordEditScreen(
                    arguments: state.extra as PriceRecordFormArguments,
                  )
                : const PriceRecordEditScreen(
                    arguments: PriceRecordFormArguments(merchants: []),
                  ),
          ),
          GoRoute(
            path: '/recipes',
            name: RouteNames.recipes,
            pageBuilder: (context, state) => _shellTransitionPage(
              child: const RecipeListScreen(),
              key: state.pageKey,
              location: state.matchedLocation,
            ),
          ),
          GoRoute(
            path: '/recipes/new',
            name: 'recipe-form',
            builder: (_, __) => const RecipeFormScreen(),
          ),
          GoRoute(
            path: '/recipes/:id',
            name: 'recipe-detail',
            builder: (_, state) => RecipeDetailScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/recipes/:id/edit',
            name: 'recipe-edit',
            builder: (_, state) => RecipeFormScreen(
              recipe: state.extra is RecipeDetail
                  ? state.extra as RecipeDetail
                  : null,
              recipeId: int.tryParse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/recipes/:id/edit/:section',
            name: 'recipe-section-edit',
            builder: (_, state) => RecipeFormScreen(
              recipe: state.extra is RecipeDetail
                  ? state.extra as RecipeDetail
                  : null,
              recipeId: int.tryParse(state.pathParameters['id']!),
              section: RecipeFormSection.fromName(
                state.pathParameters['section'],
              ),
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
            pageBuilder: (context, state) => _shellTransitionPage(
              child: const IngredientListScreen(),
              key: state.pageKey,
              location: state.matchedLocation,
            ),
          ),
          GoRoute(
            path: '/ingredients/new',
            name: RouteNames.ingredientForm,
            builder: (_, __) => const IngredientFormScreen(),
          ),
          GoRoute(
            path: '/ingredients/:id/hierarchy',
            name: 'ingredient-hierarchy',
            builder: (_, state) {
              final args = state.extra;
              if (args is IngredientHierarchyArguments) {
                return IngredientHierarchyScreen(
                  ingredientId: args.ingredientId,
                  ingredientName: args.ingredientName,
                  hierarchyData: args.hierarchyData,
                  loading: args.loading,
                  isAdmin: args.isAdmin,
                  onAdd: args.onAdd,
                  onUpdateStrength: args.onUpdateStrength,
                  onDelete: args.onDelete,
                );
              }
              return IngredientHierarchyScreen(
                ingredientId:
                    int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                ingredientName: '',
                hierarchyData: null,
                isAdmin: true,
                onAdd: (_) async => null,
                onUpdateStrength: (_) async => null,
                onDelete: (_) async => null,
              );
            },
          ),
          GoRoute(
            path: '/ingredients/:id',
            name: 'ingredient-detail',
            builder: (_, state) => IngredientDetailScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/ingredients/:id/edit',
            name: 'ingredient-edit',
            builder: (_, state) => IngredientFormScreen(
              ingredient:
                  state.extra is Ingredient ? state.extra as Ingredient : null,
              ingredientId: int.tryParse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/products',
            name: RouteNames.products,
            pageBuilder: (context, state) => _shellTransitionPage(
              child: const ProductListScreen(),
              key: state.pageKey,
              location: state.matchedLocation,
            ),
          ),
          GoRoute(
            path: '/products/new',
            name: RouteNames.productForm,
            builder: (context, state) => ProductFormScreen(
              fixedIngredient:
                  state.extra is Ingredient ? state.extra as Ingredient : null,
              prefill: state.extra is ProductFormPrefill
                  ? state.extra as ProductFormPrefill
                  : null,
              isAdmin: ref.read(authProvider).user?.isAdmin == true,
            ),
          ),
          GoRoute(
            path: '/products/:id',
            name: 'product-detail',
            builder: (_, state) => ProductDetailScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/products/:id/edit',
            name: 'product-edit',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id']!);
              final extra = state.extra;
              return ProductFormScreen(
                product: extra is Product
                    ? extra
                    : (id == null ? null : Product(id: id, name: '')),
                isAdmin: ref.read(authProvider).user?.isAdmin == true,
              );
            },
          ),
          GoRoute(
            path: '/merchants',
            name: RouteNames.merchants,
            pageBuilder: (context, state) => _shellTransitionPage(
              child: const MerchantListScreen(),
              key: state.pageKey,
              location: state.matchedLocation,
            ),
          ),
          GoRoute(
            path: '/favorites',
            name: 'favorites',
            pageBuilder: (context, state) => _shellTransitionPage(
              child: const FavoritesScreen(),
              key: state.pageKey,
              location: state.matchedLocation,
            ),
          ),
          GoRoute(
            path: '/plans',
            name: 'plans',
            pageBuilder: (context, state) => _shellTransitionPage(
              child: const PlannerListScreen(),
              key: state.pageKey,
              location: state.matchedLocation,
            ),
          ),
          GoRoute(
            path: '/compare',
            name: 'compare',
            pageBuilder: (context, state) => _shellTransitionPage(
              child: const CompareScreen(),
              key: state.pageKey,
              location: state.matchedLocation,
            ),
          ),
          GoRoute(
            path: '/plans/edit',
            name: 'plan-edit',
            builder: (context, state) {
              final extra = state.extra;
              final plan =
                  extra is Map ? extra['plan'] as Map<String, dynamic>? : null;
              return PlannerEditScreen(plan: plan);
            },
          ),
          GoRoute(
            path: '/plans/:id',
            name: 'plan-detail',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return id == null
                  ? const PlannerListScreen()
                  : PlanDetailScreen(planId: id);
            },
          ),
          GoRoute(
            path: '/merchants/map',
            name: 'merchant-map',
            builder: (_, __) => const MerchantListScreen(initialShowMap: true),
          ),
          GoRoute(
            path: '/merchants/new',
            name: 'merchant-form',
            builder: (context, state) {
              final args = state.extra;
              return MerchantFormScreen(
                isAdmin: args is MerchantFormArguments
                    ? args.isAdmin
                    : ref.read(authProvider).user?.isAdmin == true,
                repository:
                    args is MerchantFormArguments ? args.repository : null,
                mapTileProvider:
                    args is MerchantFormArguments ? args.mapTileProvider : null,
              );
            },
          ),
          GoRoute(
            path: '/merchants/:id',
            name: 'merchant-detail',
            builder: (_, state) => MerchantDetailScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/merchants/:id/edit',
            name: 'merchant-edit',
            builder: (context, state) {
              final args = state.extra;
              return MerchantFormScreen(
                merchant: args is MerchantFormArguments ? args.merchant : null,
                isAdmin: args is MerchantFormArguments
                    ? args.isAdmin
                    : ref.read(authProvider).user?.isAdmin == true,
                repository:
                    args is MerchantFormArguments ? args.repository : null,
                mapTileProvider:
                    args is MerchantFormArguments ? args.mapTileProvider : null,
              );
            },
          ),
          GoRoute(
            path: '/profile',
            name: RouteNames.profile,
            pageBuilder: (context, state) => _shellTransitionPage(
              child: const ProfileScreen(),
              key: state.pageKey,
              location: state.matchedLocation,
            ),
          ),
          GoRoute(
            path: '/profile/account',
            name: RouteNames.editAccount,
            builder: (_, __) => const EditAccountScreen(),
          ),
          GoRoute(
            path: '/profile/about',
            name: RouteNames.about,
            builder: (_, __) => const AboutScreen(),
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
            path: '/profile/blacklist',
            name: RouteNames.blacklist,
            builder: (_, __) => const BlacklistScreen(),
          ),
          GoRoute(
            path: '/profile/places/new',
            name: 'user-place-form',
            builder: (_, state) {
              final args = state.extra;
              return UserPlaceFormScreen(
                place: args is UserPlaceFormArguments ? args.place : null,
                mapTileProvider: args is UserPlaceFormArguments
                    ? args.mapTileProvider
                    : null,
              );
            },
          ),
          GoRoute(
            path: '/profile/places/:id/edit',
            name: 'user-place-edit',
            builder: (_, state) {
              final args = state.extra;
              return UserPlaceFormScreen(
                place: args is UserPlaceFormArguments ? args.place : null,
                mapTileProvider: args is UserPlaceFormArguments
                    ? args.mapTileProvider
                    : null,
              );
            },
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
          GoRoute(
            path: '/profile/calc-scopes',
            name: 'calc-scopes',
            builder: (_, __) => const CalcScopeListScreen(),
          ),
          GoRoute(
            path: '/profile/calc-scopes/new',
            name: 'calc-scope-form',
            builder: (_, state) {
              final args = state.extra;
              return CalcScopeFormScreen(
                scope: args is CalcScopeFormArguments ? args.scope : null,
              );
            },
          ),
          GoRoute(
            path: '/profile/calc-scopes/:id/edit',
            name: 'calc-scope-edit',
            builder: (_, state) {
              final args = state.extra;
              return CalcScopeFormScreen(
                scope: args is CalcScopeFormArguments ? args.scope : null,
              );
            },
          ),
        ],
      ),
    ],
  );
}

/// 底栏/侧栏 tab 定义：prefixes 决定选中态归属（含子路由前缀匹配）。
enum _TabLabel {
  home,
  prices,
  recipes,
  ingredients,
  products,
  merchants,
  compare,
  favorites,
  plans,
  profile,
  more
}

class _Tab {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.prefixes,
    this.route,
  });

  final _TabLabel label;
  final IconData icon;
  final IconData selectedIcon;
  final List<String> prefixes;
  final String? route;
}

const _homeTab = _Tab(
    label: _TabLabel.home,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    prefixes: ['/home'],
    route: '/home');
const _pricesTab = _Tab(
    label: _TabLabel.prices,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    prefixes: ['/prices'],
    route: '/prices');
const _recipesTab = _Tab(
    label: _TabLabel.recipes,
    icon: Icons.restaurant_outlined,
    selectedIcon: Icons.restaurant,
    prefixes: ['/recipes'],
    route: '/recipes');
const _ingredientsTab = _Tab(
    label: _TabLabel.ingredients,
    icon: Icons.spa_outlined,
    selectedIcon: Icons.spa,
    prefixes: ['/ingredients'],
    route: '/ingredients');
const _productsTab = _Tab(
    label: _TabLabel.products,
    icon: Icons.shopping_bag_outlined,
    selectedIcon: Icons.shopping_bag,
    prefixes: ['/products'],
    route: '/products');
const _merchantsTab = _Tab(
    label: _TabLabel.merchants,
    icon: Icons.store_outlined,
    selectedIcon: Icons.store,
    prefixes: ['/merchants'],
    route: '/merchants');
const _plansTab = _Tab(
    label: _TabLabel.plans,
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment,
    prefixes: ['/plans'],
    route: '/plans');
const _compareTab = _Tab(
    label: _TabLabel.compare,
    icon: Icons.compare_arrows,
    selectedIcon: Icons.compare_arrows,
    prefixes: ['/compare'],
    route: '/compare');
const _favoritesTab = _Tab(
    label: _TabLabel.favorites,
    icon: Icons.favorite_outline,
    selectedIcon: Icons.favorite,
    prefixes: ['/favorites'],
    route: '/favorites');
const _profileTab = _Tab(
    label: _TabLabel.profile,
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    prefixes: ['/profile'],
    route: '/profile');
const _moreTab = _Tab(
    label: _TabLabel.more,
    icon: Icons.menu,
    selectedIcon: Icons.menu,
    prefixes: [
      '/ingredients',
      '/products',
      '/merchants',
      '/compare',
      '/favorites',
      '/plans',
      '/profile',
    ]);

/// 顺序对齐 web 侧栏（AppLayout.vue）：商品在原料前。
const _desktopTabs = [
  _homeTab,
  _pricesTab,
  _recipesTab,
  _productsTab,
  _ingredientsTab,
  _merchantsTab,
  _compareTab,
  _favoritesTab,
  _plansTab,
  _profileTab,
];
const _mobileTabs = [_homeTab, _pricesTab, _recipesTab, _moreTab];
const _moreMenuTabs = [
  _productsTab,
  _ingredientsTab,
  _merchantsTab,
  _compareTab,
  _favoritesTab,
  _plansTab,
  _profileTab,
];

String _tabLabel(_TabLabel label, AppLocalizations l10n) {
  return switch (label) {
    _TabLabel.home => l10n.navHome,
    _TabLabel.prices => l10n.navPrices,
    _TabLabel.recipes => l10n.navRecipes,
    _TabLabel.ingredients => l10n.navIngredients,
    _TabLabel.products => l10n.navProducts,
    _TabLabel.merchants => l10n.navMerchants,
    _TabLabel.compare => l10n.navCompare,
    _TabLabel.favorites => l10n.navFavorites,
    _TabLabel.plans => l10n.navPlans,
    _TabLabel.profile => l10n.navProfile,
    _TabLabel.more => l10n.navMore,
  };
}

/// 当前路由在哪个 tab 下：前缀精确相等或「前缀/」开头。
int _tabIndexFor(List<_Tab> tabs, String location) {
  for (var i = 0; i < tabs.length; i++) {
    if (tabs[i]
        .prefixes
        .any((p) => location == p || location.startsWith('$p/'))) {
      return i;
    }
  }
  return -1;
}

/// 编辑态表单路径：/<实体>/<id>/edit（菜谱另有 /edit/<section>）。
final _editFormPathPattern = RegExp(
  r'^/(ingredients|products|recipes|merchants|plans)/\d+/edit(/.*)?$',
);

/// 自定义计算范围编辑页（/profile 前缀，不在实体正则内）。
final _calcScopeEditFormPathPattern =
    RegExp(r'^/profile/calc-scopes/\d+/edit$');

/// 全屏表单路由：新增/编辑原料、商品、菜谱、商家、方案时隐藏底栏/侧栏 tab。
///
/// 这些页面里误触 tab 会直接切走并丢掉未保存内容（返回键另有 FormExitGuard
/// 二次确认），因此整页不再显示 tab；返回后自动恢复。
bool _isFullScreenFormRoute(String location) {
  const exact = <String>{
    '/ingredients/new',
    '/products/new',
    '/recipes/new',
    '/merchants/new',
    '/plans/edit',
    '/profile/calc-scopes/new',
  };
  if (exact.contains(location)) return true;
  return _editFormPathPattern.hasMatch(location) ||
      _calcScopeEditFormPathPattern.hasMatch(location);
}

/// 路由位置在桌面版 tab 顺序中的索引（用于计算 tab 间滑动方向）。
int _tabRouteIndex(String location) {
  for (var i = 0; i < _desktopTabs.length; i++) {
    if (_desktopTabs[i]
        .prefixes
        .any((p) => location == p || location.startsWith('$p/'))) {
      return i;
    }
  }
  return -1;
}

/// Shell route 分支过渡页：根据目标 tab 与当前 tab 的索引差决定滑动方向。
/// 切到更靠后的 tab → 从右滑入；切到更早的 tab → 从左滑入（RTL 镜像）。
CustomTransitionPage<void> _shellTransitionPage({
  required Widget child,
  required LocalKey key,
  required String location,
}) {
  final prev = _lastShellLocation;
  _lastShellLocation = location;

  final prevIdx = prev != null ? _tabRouteIndex(prev) : -1;
  final currIdx = _tabRouteIndex(location);
  final toEarlierTab = prevIdx >= 0 && currIdx >= 0 && currIdx < prevIdx;

  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // 导航为竖向（尾缘/左缘竖条）时，页面切换沿竖条方向上下滑动；
      // 横条/底栏/平板左 rail 仍为左右滑动（RTL 镜像）。
      final mode = shellModeFor(
        MediaQuery.sizeOf(context),
        MediaQuery.displayFeaturesOf(context),
      );
      final begin = shellPageSlideBegin(
        mode: mode,
        toEarlierTab: toEarlierTab,
        isRtl: Directionality.of(context) == TextDirection.rtl,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero)
            .animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        )),
        child: child,
      );
    },
  );
}

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  final Widget child;

  /// 浮层（底部弹层 / 对话框）安全区接管信号；应与 `MaterialApp.router` 的
  /// `builder` 里 [ShellOverlayInsetsScope] 共用同一个实例。不传时壳层自用一个。
  final ShellOverlayInsets? overlayInsets;

  const ScaffoldWithNavBar({
    super.key,
    required this.child,
    this.overlayInsets,
  });

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar>
    with WidgetsBindingObserver {
  final _duoLayout = DuoLayoutChannel();

  /// Duo 布局信息（竖条侧别 + 系统遮挡区）；iOS 27.1+ 才有实质值。
  DuoLayoutInfo _duoLayoutInfo = const DuoLayoutInfo();

  /// 本次运行是否见过 Duo（竖条侧别或系统遮挡区）。
  ///
  /// 折叠↔展开切换的瞬间，原生可能返回空信息（reservedRegions 尚未就绪）；若直接
  /// 按「非 Duo」处理，页面会把系统 top padding 加回来，标题栏/导航会掉到状态簇
  /// 下面（用户报障「展开时有概率掉下去」）。记住一次即长期按 Duo 处理。
  bool _seenDuo = false;

  /// 页面发布到竖条工具栏的动作（竖条模式下的 AppBar actions / FAB）。
  final ShellChrome _chrome = ShellChrome();

  /// 上一次的路由位置：变化时清空上一页发布的动作。
  String? _lastChromeLocation;

  /// 当前路由（含 `push` 出来的子页面）。ShellRoute 的 builder 在子页面被 push
  /// 时不会重建，`GoRouterState.of(context)` 会一直停在 tab 根路径——靠 Router
  /// delegate 的监听保持最新，竖条动作/高亮才不会串页。
  String _currentLocation = '';

  /// 已订阅的 Router delegate（`didChangeDependencies` 可能多次调用）。
  GoRouter? _observedRouter;

  /// 浮层安全区信号（外部注入或自用，自用的随壳层销毁）。
  late final ShellOverlayInsets _overlayInsets;
  bool _ownsOverlayInsets = false;

  /// 姿态变化后的延迟重查（旋转瞬间系统布局未稳定）。
  Timer? _layoutRefreshTimer;

  /// 原生返回空遮挡区时的补查（最多 5 次，避免无限轮询）。
  Timer? _layoutRetryTimer;
  int _layoutRetry = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsOverlayInsets = widget.overlayInsets == null;
    _overlayInsets = widget.overlayInsets ?? ShellOverlayInsets();
    _refreshVerticalBarEdge();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _layoutRefreshTimer?.cancel();
    _layoutRetryTimer?.cancel();
    _observedRouter?.routerDelegate.removeListener(_onRouteChanged);
    _chrome.dispose();
    if (_ownsOverlayInsets) _overlayInsets.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // 旋转、进出分屏、拖动分隔条都会触发。系统布局在旋转瞬间尚未稳定，
    // 立即查可能拿到旧的保留区 → 工具栏被状态图标压住；补一帧后再查一次。
    _refreshVerticalBarEdge();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshVerticalBarEdge();
    });
    _layoutRefreshTimer?.cancel();
    _layoutRefreshTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) _refreshVerticalBarEdge();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery（尺寸/内边距）变化同样可能意味着姿态变化。
    _refreshVerticalBarEdge();
    _observeRouter();
  }

  /// 监听 Router delegate：`push` / `pop` 子页面时 ShellRoute 的 builder 不重建，
  /// 这里主动把当前地址（含命令式 push 的页面）同步进来并触发重建。
  void _observeRouter() {
    final router = GoRouter.of(context);
    if (identical(router, _observedRouter)) return;
    _observedRouter?.routerDelegate.removeListener(_onRouteChanged);
    _observedRouter = router;
    router.routerDelegate.addListener(_onRouteChanged);
    _currentLocation = _resolveLocation(router);
  }

  String _resolveLocation(GoRouter router) {
    final matches = router.routerDelegate.currentConfiguration.matches;
    if (matches.isEmpty) return GoRouterState.of(context).matchedLocation;
    // push 出来的页面嵌在 ShellRouteMatch 内部：一路走到最深的那层才是真实地址。
    RouteMatchBase match = matches.last;
    while (match is ShellRouteMatch && match.matches.isNotEmpty) {
      match = match.matches.last;
    }
    return match.matchedLocation;
  }

  void _onRouteChanged() {
    if (!mounted || _observedRouter == null) return;
    final next = _resolveLocation(_observedRouter!);
    if (next == _currentLocation) return;
    _currentLocation = next;
    // 立即告知壳层（竖条动作按路由过滤），补一帧再重建自身（高亮/表单判定）。
    _chrome.bindLocation(next);
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _refreshVerticalBarEdge() async {
    final info = await _duoLayout.layoutInfo();
    if (!mounted) return;
    if (kDebugMode) {
      // 排查普通手机 / 折叠屏误判时，这行日志带齐了判据（用户真机回传即可定位）。
      final size = MediaQuery.sizeOf(context);
      debugPrint('DUO edge=${info.edge} size=${info.width}x${info.height} '
          'occlusions=${info.occlusions} clusters=${info.clusters.length} '
          'mq=$size shape=${isFoldableScreenShape(size)}');
    }
    if (info.edge != VerticalBarEdge.unspecified || info.hasDuoCluster) {
      // 只有屏幕比例像折叠屏才记住「这是 Duo」：普通手机真机的遮挡区形态不可靠。
      if (isFoldableScreenShape(MediaQuery.sizeOf(context))) _seenDuo = true;
    }
    // 切换姿态的瞬间原生可能还拿不到 reservedRegions（返回空遮挡区）：同尺寸下
    // 先沿用上一帧的，否则标题栏会临时变矮、按钮也不再给状态簇让位；同时补查一次。
    var effective = info;
    if (info.occlusions.isEmpty &&
        _duoLayoutInfo.hasDuoCluster &&
        info.width == _duoLayoutInfo.width &&
        info.height == _duoLayoutInfo.height) {
      effective = DuoLayoutInfo(
        edge: info.edge == VerticalBarEdge.unspecified
            ? _duoLayoutInfo.edge
            : info.edge,
        width: info.width,
        height: info.height,
        occlusions: _duoLayoutInfo.occlusions,
        divisions: info.divisions,
      );
    }
    if (info.occlusions.isEmpty && _seenDuo && _layoutRetry < 5) {
      _scheduleLayoutRetry();
    } else if (info.hasDuoCluster) {
      _layoutRetry = 0;
    }
    // 尺寸也要比：rect 坐标只在它自己的坐标空间里有效，尺寸变了要重新推导
    // 顶部/底部簇（否则会按旧高度把顶部簇当底部簇）。
    // 折叠屏一旦上报出系统簇就允许旋转（普通手机始终保持竖屏锁定）。
    if (mounted) {
      OrientationPolicy.apply(size: MediaQuery.sizeOf(context), duo: effective);
    }
    final same = effective.edge == _duoLayoutInfo.edge &&
        effective.width == _duoLayoutInfo.width &&
        effective.height == _duoLayoutInfo.height &&
        listEquals(effective.occlusions, _duoLayoutInfo.occlusions);
    if (same) return;
    setState(() => _duoLayoutInfo = effective);
  }

  void _scheduleLayoutRetry() {
    _layoutRetry++;
    _layoutRetryTimer?.cancel();
    _layoutRetryTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _refreshVerticalBarEdge();
    });
  }

  /// 当前姿态的标题栏让位规格（[DuoBarInsets]）。
  ///
  /// 原生在姿态切换瞬间可能拿不到遮挡区；此时对「展开竖屏」（≥600×800 且已确认
  /// 是 Duo）按实测几何兜底（右上状态簇 144×82、图标光轴 48），保证标题栏内按钮
  /// 仍给状态簇让位，而不是压在它底下。拿到真实数据后自动覆盖。
  DuoBarInsets _barInsets(BuildContext context) {
    if (!isFoldableScreenShape(MediaQuery.sizeOf(context))) {
      return DuoBarInsets.none;
    }
    if (_duoLayoutInfo.hasDuoCluster) {
      return DuoBarInsets.of(_duoLayoutInfo);
    }
    if (!_seenDuo) return DuoBarInsets.none;
    final size = MediaQuery.sizeOf(context);
    if (size.width >= 600 && size.height >= 800) {
      return const DuoBarInsets(
        toolbarHeight: 82,
        trailingInset: 144,
        contentCenterY: 48,
      );
    }
    return DuoBarInsets.none;
  }

  /// Duo 横条模式（展开竖屏 / 折叠横屏）下页面标题栏的规格，全部由系统上报的
  /// 遮挡区推导（[DuoBarInsets]）：
  /// - 高度与顶部系统状态簇底边平齐（不再是一大片空白下的窄条）；
  /// - 系统簇在左 / 右时，按钮排到簇的旁边（不被时间 / 电量盖住）；
  /// - 其余情况按钮靠边，返回键留 64 的呼吸位。
  Widget _wrapDuoPageChrome(
      BuildContext context, ShellMode mode, Widget child) {
    final theme = Theme.of(context);
    var data = theme;
    if (_isDuo(MediaQuery.sizeOf(context)) && mode == ShellMode.bottomBar) {
      final bar = _barInsets(context);
      data = theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          toolbarHeight: bar.toolbarHeight > 56 ? bar.toolbarHeight : null,
          leadingWidth: 64 + bar.leadingInset,
          actionsPadding:
              EdgeInsetsDirectional.only(end: 8 + bar.trailingInset),
        ),
        // 让位规格挂到主题上：ShellAppBar 据此把返回键排到系统簇右边。
        extensions: [...theme.extensions.values, bar],
      );
    }
    // 恒定包一层（不随形态增减节点，页面子树不会被重新挂载）；用 AnimatedTheme：
    // 旋转后系统上报的状态簇形状会先停在上一姿态的形状上再切到稳态（实测 1~10 秒），
    // 标题栏高度 / 让位随之平滑过渡而不是瞬跳。
    return AnimatedTheme(
      data: data,
      duration: kThemeAnimationDuration,
      child: child,
    );
  }

  /// 页面子树的 MediaQuery（恒定包一层，保证壳层换形态时子树结构不变、State 不丢）。
  ///
  /// 系统安全区是**整条**侧边内缩（Duo 摄像头侧 84pt），但系统 UI 只占摄像头
  /// 所在的那个角；照搬会让标题栏被二次内缩、正文与标题栏空出一整条：
  /// - 横条模式：水平内边距清零（标题栏由 [_wrapDuoPageChrome] 按遮挡区局部让位，
  ///   底栏自行让位），标题栏顶到屏幕上沿；无底栏的整页表单把底部抬到底部
  ///   系统簇（摄像头）之上。
  /// - 竖条模式：去掉竖条所在侧的内边距（内容已整体让出竖条宽度，再来一层就是双份）；
  ///   顶部没有系统簇时标题栏顶到屏幕上沿。
  Widget _wrapPageMediaQuery(BuildContext context, ShellMode mode, bool showNav,
      bool railOnLeft, Widget child) {
    final mq = MediaQuery.of(context);
    var padding = mq.padding;
    // 尺寸兜底：底栏模式 + Duo 展开竖屏的尺寸特征（≥600×800）时一律当 Duo，
    // 即使这一帧原生还没上报布局信息——否则顶栏会被系统 top padding 推下去。
    final duoLike = _isDuo(mq.size) ||
        (mode == ShellMode.bottomBar &&
            mq.size.width >= 600 &&
            mq.size.height >= 800);
    if (duoLike) {
      if (mode == ShellMode.bottomBar) {
        // 键盘弹出时系统本来就把 bottom 归零，这里保持同样口径。
        final baseBottom =
            math.max(0.0, mq.viewPadding.bottom - mq.viewInsets.bottom);
        final cluster = showNav ? 0.0 : _barInsets(context).bottomInset;
        padding = EdgeInsets.only(
          bottom: cluster > baseBottom ? cluster : baseBottom,
        );
      } else if (mode == ShellMode.edgeRail) {
        padding = padding.copyWith(
          left: railOnLeft ? 0 : null,
          right: railOnLeft ? null : 0,
          top: _duoLayoutInfo.topClusterInset == 0 ? 0 : null,
        );
      } else if (_duoLayoutInfo.topClusterInset == 0) {
        padding = padding.copyWith(top: 0);
      }
    }
    return MediaQuery(
      data: mq.copyWith(padding: padding),
      child: child,
    );
  }

  /// 当前是否按 Duo 布局处理。
  ///
  /// 除了「见过 Duo 信息」，还要求屏幕比例像折叠屏（[isFoldableScreenShape]）：
  /// 普通 iPhone 真机会上报与模拟器不同形态的遮挡区（iPhone 13 Pro 真机复现
  /// 标题栏顶进刘海），只靠矩形过滤不可靠；比例是最稳的一道闸门。
  bool _isDuo(Size size) {
    if (!isFoldableScreenShape(size)) return false;
    return _seenDuo ||
        _duoLayoutInfo.edge != VerticalBarEdge.unspecified ||
        _duoLayoutInfo.hasDuoCluster;
  }

  @override
  Widget build(BuildContext context) {
    final location = _currentLocation.isEmpty
        ? GoRouterState.of(context).matchedLocation
        : _currentLocation;
    final mode = shellModeFor(
      MediaQuery.sizeOf(context),
      MediaQuery.displayFeaturesOf(context),
      edge: _duoLayoutInfo.edge,
    );
    final fullScreenForm = _isFullScreenFormRoute(location);
    final railLike = mode != ShellMode.bottomBar;
    final tabs = railLike ? _desktopTabs : _mobileTabs;
    final selectedIndex = _tabIndexFor(tabs, location);
    final l10n = AppLocalizations.of(context);
    // 竖条模式下表单页也显示竖条（后退 + 保存都在竖条里，HIG：控件随姿态）；
    // 底栏 / 平板 rail 模式仍按既有行为在表单页隐藏，避免误触丢内容。
    final railNav = mode == ShellMode.edgeRail;
    final showNav = railNav ? true : !fullScreenForm;
    final showTabs = !fullScreenForm;
    final isDuo = _isDuo(MediaQuery.sizeOf(context));
    // 告知壳层当前路由：转场中旧页的迟到 publish 会被丢弃（否则返回/下钻后竖条残留按钮）。
    _chrome.bindLocation(location);
    if (_lastChromeLocation != location) {
      _lastChromeLocation = location;
      _chrome.clear();
    }
    // 竖条不接管工具（非竖条模式 / 竖条太矮）时清空残留，避免工具留在竖条里。
    final railToolbar = showNav &&
        mode == ShellMode.edgeRail &&
        MediaQuery.sizeOf(context).height >= 620;
    if (!railToolbar) _chrome.clear();
    // 尾缘竖条宽度 = 系统保留区宽度（Duo 内屏横屏实测 viewPadding.right = 84pt，
    // 系统状态图标列居中于该条内）。图标必须与系统图标同列同尺寸（20pt），
    // 否则会「移位」到系统图标列的左侧。无系统保留区（如常规 iPhone）兜底 56。
    // 分屏（Split View）时系统保留条只出现在本窗口靠外的一侧：左窗 left=84、
    // 右窗 right=84（HIG：每个 app 把控件放在自己靠外的边缘）。竖条跟随该侧，
    // 双向保证图标与系统状态图标同列。
    final viewPadding = MediaQuery.viewPaddingOf(context);
    // 侧别以 UIKit trait（verticalBarEdge）为准——分屏时 viewPadding 不一定
    // 反映竖条在哪一侧；trait 不可用（非 iOS / 低版本 / 无竖条）时退回
    // padding 比较。
    final stripOnLeft = switch (_duoLayoutInfo.edge) {
      VerticalBarEdge.leading => true,
      // 无竖条信息时按完全展开处理：条在 trailing（不用 padding 猜测，
      // 避免某些姿态被误判成左侧而留下一大片空白）。
      VerticalBarEdge.trailing || VerticalBarEdge.unspecified => false,
    };
    final systemStrip = stripOnLeft ? viewPadding.left : viewPadding.right;
    final edgeRailWidth = systemStrip >= 44 ? systemStrip : 56.0;
    // 系统状态图标列中心距尾缘实测 48pt（Duo 外屏 466×678 像素测量：时间行与
    // 环形电量行中心一致）。84pt 保留条的几何中心是 42pt，若按条居中会偏内 6pt。
    // 竖条内图标按该中心线对齐；无保留条的常规设备退回条中心。
    final iconColumnCenter = systemStrip >= 84 ? 48.0 : edgeRailWidth / 2;
    final railEndPad =
        (2 * iconColumnCenter - edgeRailWidth).clamp(0.0, edgeRailWidth);
    // 平板左 rail 跟随方向（leading，RTL 时视觉翻到右侧）；尾缘竖条物理固定
    // 在系统条所在侧（分屏左窗为左缘、右窗为右缘；RTL 下也不翻转，与硬件对齐）。
    final railOnLeft = Directionality.of(context) != TextDirection.rtl;
    final edgeRailOnLeft = mode == ShellMode.edgeRail && stripOnLeft;
    final EdgeInsets contentPadding;
    if (showNav && mode == ShellMode.sideRail) {
      contentPadding = railOnLeft
          ? const EdgeInsets.only(left: 80)
          : const EdgeInsets.only(right: 80);
    } else if (showNav && mode == ShellMode.edgeRail) {
      contentPadding = edgeRailOnLeft
          ? EdgeInsets.only(left: edgeRailWidth)
          : EdgeInsets.only(right: edgeRailWidth);
    } else {
      contentPadding = EdgeInsets.zero;
    }

    // 浮层（底部弹层 / 对话框）的安全区在 Navigator 之上统一接管，不用逐个弹层改：
    // 竖条模式去掉竖条所在侧的系统条；Duo 横条模式两侧铺满、底部抬到底部系统簇之上。
    final duoBottomBar = isDuo && mode == ShellMode.bottomBar;
    _overlayInsets.schedule(
      stripSide: showNav && mode == ShellMode.edgeRail
          ? (edgeRailOnLeft ? ShellStripSide.leading : ShellStripSide.trailing)
          : ShellStripSide.none,
      dropHorizontal: duoBottomBar,
      bottomFloor: duoBottomBar ? _barInsets(context).bottomInset : 0,
    );

    return Scaffold(
      body: Stack(
        children: [
          // 树形恒定（P0）：内容槽固定在 Stack 首位，壳层模式切换只改 padding
          // 与叠加的导航层——外屏(466) ↔ 内屏(669/951) 切换时子树不重建，
          // 滚动/输入 State 不丢。
          Padding(
            padding: contentPadding,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: DuoLayoutScope(
                layout: _duoLayoutInfo,
                railWidth: mode == ShellMode.edgeRail ? edgeRailWidth : 0,
                child: ShellChromeScope(
                  chrome: _chrome,
                  // Duo 展开竖屏 / 折叠横屏：底栏直接列出全部目的地，列表页就是一级
                  // tab → 页面不显示返回键（用户定调：这时候不应该有）。
                  tabRoot: mode == ShellMode.bottomBar &&
                      MediaQuery.sizeOf(context).width >= 600 &&
                      _desktopTabs.any((t) => t.prefixes.contains(location)),
                  // 竖条接管工具（高 ≥620）：页面标题栏不再放按钮，动作与返回都在竖条里。
                  isRailMode: showNav &&
                      mode == ShellMode.edgeRail &&
                      MediaQuery.sizeOf(context).height >= 620,
                  // Duo 的竖条在侧边、顶部没有系统状态簇时，页面标题栏应顶到
                  // 屏幕最上方（不再被多余的 top padding 推下来）。
                  child: _wrapDuoPageChrome(
                    context,
                    mode,
                    _wrapPageMediaQuery(
                      context,
                      mode,
                      showNav,
                      edgeRailOnLeft,
                      widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showNav && mode == ShellMode.sideRail)
            // 10 个目的地在矮视口（默认测试窗 800×600、桌面小窗）会纵向溢出：
            // 包一层纵向滚动。rail 内部含 Expanded，必须给显式高度才有界；
            // 高度取 max(视口, 660)——视口足够高时 rail 填满且不产生滚动，
            // 矮视口时可上下滚动（660 = 10 个 labelType:all 目的地固有高度 + 余量）。
            Positioned(
              left: railOnLeft ? 0 : null,
              right: railOnLeft ? null : 0,
              top: 0,
              bottom: 0,
              width: 80,
              child: LayoutBuilder(builder: (context, constraints) {
                const minRailHeight = 660.0;
                return SingleChildScrollView(
                  child: SizedBox(
                    height: constraints.maxHeight < minRailHeight
                        ? minRailHeight
                        : constraints.maxHeight,
                    child: NavigationRail(
                      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                      onDestinationSelected: (i) =>
                          _onTabSelected(context, _desktopTabs[i]),
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final t in _desktopTabs)
                          NavigationRailDestination(
                            icon: Icon(t.icon),
                            selectedIcon: Icon(t.selectedIcon),
                            label: Text(_tabLabel(t.label, l10n)),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          if (showNav && mode == ShellMode.edgeRail)
            Positioned(
              left: edgeRailOnLeft ? 0 : null,
              right: edgeRailOnLeft ? null : 0,
              top: 0,
              bottom: 0,
              width: edgeRailWidth,
              child: _EdgeRail(
                onLeft: edgeRailOnLeft,
                showTabs: showTabs,
                chrome: _chrome,
                // tab 恒在底部（HIG：tab bar 在竖条末端），工具在顶部；
                // 底部若有系统簇（摄像头朝下），由 bottomInset 让位。
                bottomInset: _duoLayoutInfo.bottomClusterInset,
                key: const ValueKey('edge-rail'),
                // 竖条与底栏同构：只有 4 个目的地，最后一个是「更多」
                // （点开底部弹层展示其余目的地）。
                selectedIndex: _tabIndexFor(_mobileTabs, location),
                tabs: _mobileTabs,
                labels: [
                  for (final t in _mobileTabs) _tabLabel(t.label, l10n),
                ],
                contentPadding: EdgeInsetsDirectional.only(
                  start: edgeRailOnLeft ? railEndPad : 0,
                  end: edgeRailOnLeft ? 0 : railEndPad,
                  // 系统簇下方多留 12pt：避免按钮贴着摄像头/曲面边界的圆角。
                  // 左侧竖条（分屏左窗）常常没有上报顶部遮挡区（occlusions=[]），
                  // 此时工具会贴在屏幕上沿、被窗口圆角切掉；按「下部分按钮距屏幕的
                  // 距离」（home indicator 内边距）对齐，两侧留白对称。
                  top: _duoLayoutInfo.topClusterInset == 0
                      ? math.max(12.0, viewPadding.bottom)
                      : _duoLayoutInfo.topClusterInset + 12,
                ),
                onSelected: (t) => _onTabSelected(context, t),
              ),
            ),
        ],
      ),
      bottomNavigationBar: mode == ShellMode.bottomBar && !fullScreenForm
          ? _buildBottomNav(
              context,
              _tabIndexFor(
                MediaQuery.sizeOf(context).width >= 600
                    ? _desktopTabs
                    : _mobileTabs,
                location,
              ),
            )
          : null,
    );
  }

  Widget _buildBottomNav(BuildContext context, int selectedIndex) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // 展开竖屏（≥600，如 669×951）空间足够：底栏直接给全部目的地，
    // 不再收进「更多」；窄屏仍是 4 个 + 更多。
    final wideBar = MediaQuery.sizeOf(context).width >= 600;
    final tabs = wideBar ? _desktopTabs : _mobileTabs;
    final duoBar = _isDuo(MediaQuery.sizeOf(context))
        ? _barInsets(context)
        : DuoBarInsets.none;
    // 底栏横跨全宽：去掉系统竖条带来的水平内边距（外屏左/内屏右各一侧）。
    // 底部只让 home indicator：Duo 折叠横屏、摄像头朝下时底部安全区已被抬到系统簇
    // 之上（给弹层用），底栏改为在水平方向让开那个角（见下）。
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        padding: EdgeInsets.only(
          bottom: math.max(0.0, mq.viewPadding.bottom - mq.viewInsets.bottom),
        ),
      ),
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            // Duo 折叠横屏、摄像头在左下 / 右下：那一角是系统簇（摄像头），底栏让开。
            child: AnimatedPadding(
              duration: kThemeAnimationDuration,
              padding: EdgeInsetsDirectional.only(
                start: duoBar.barLeadingInset,
                end: duoBar.barTrailingInset,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: _NavItem(
                        // key 用 label（如 tab-计价），避免 route 带 '/' 前缀与测试长按断言不一致
                        itemKey: ValueKey(
                          'tab-${_tabLabel(tabs[i].label, l10n)}',
                        ),
                        label: _tabLabel(tabs[i].label, l10n),
                        icon: tabs[i].icon,
                        selectedIcon: tabs[i].selectedIcon,
                        selected: i == selectedIndex,
                        compact: wideBar,
                        onTap: () => _onTabSelected(context, tabs[i]),
                        onLongPress:
                            tabs[i] == _pricesTab ? _onLongPressPrices : null,
                      ),
                    ),
                ],
              ),
            ),
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
    // 在 builder 外取当前路由（builder 内 ctx 在 Overlay 下，拿不到 GoRouterState）
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIdx = _tabIndexFor(_moreMenuTabs, location);
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MediaQuery.removePadding(
        context: ctx,
        removeLeft: true,
        removeRight: true,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题行：「更多」+ 右上角关闭按钮
              // right: 4 用于抵消 IconButton 默认水平内边距，使 close 图标视觉右缘
              // 距屏 16，与左侧「更多」Text 的 16 对称；调 IconButton 内边距时注意保持。
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 0),
                child: Row(
                  children: [
                    Text(
                      l10n.navMore,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: l10n.commonClose,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              // 横排胶囊网格：复用 _NavItem，与底栏外观完全一致。
              // 列数按可用宽度自适应——宽屏（Duo 展开）一行排满，右侧不留大片空白。
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    // 窄屏（手机 / 分屏 / 折叠态）固定每行 4 项（用户定调）；
                    // 宽屏（展开）按可用宽度多排，右侧不留空白。
                    final columns = constraints.maxWidth < 600
                        ? 4
                        : (constraints.maxWidth / 72.0)
                            .floor()
                            .clamp(4, _moreMenuTabs.length);
                    final itemWidth = constraints.maxWidth / columns;
                    return Wrap(
                      children: [
                        for (var i = 0; i < _moreMenuTabs.length; i++)
                          SizedBox(
                            width: itemWidth,
                            child: _NavItem(
                              itemKey: ValueKey(
                                'more-${_tabLabel(_moreMenuTabs[i].label, l10n)}',
                              ),
                              label: _tabLabel(_moreMenuTabs[i].label, l10n),
                              icon: _moreMenuTabs[i].icon,
                              selectedIcon: _moreMenuTabs[i].selectedIcon,
                              selected: i == selectedIdx,
                              onTap: () {
                                Navigator.of(ctx).pop();
                                context.go(_moreMenuTabs[i].route!);
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
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

  /// 底栏显示全部目的地时压缩：胶囊变窄、标签单行省略。
  final bool compact;

  const _NavItem({
    this.itemKey,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.compact = false,
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
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 3)
                    : const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: selected
                    ? BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      )
                    : null,
                child: Icon(
                  selected ? selectedIcon : icon,
                  color: selected ? scheme.onSecondaryContainer : color,
                  size: compact ? 20 : 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: compact ? 11 : null,
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

/// 尾缘竖条（HIG「Vertical controls」）：外屏折叠态 / 内屏横屏的壳层导航。
///
/// 竖条自上而下 = 系统状态/摄像头保留区（SafeArea 消化）+ 工具栏区（页面操作，
/// Phase 2 接入）+ tab 目的地（沉底）。图标无文字是 Duo 竖条惯例，语义标签
/// 通过 Semantics 提供给读屏；宽 64、项 44×38、选中 M3 胶囊（primaryContainer）。
class _EdgeRail extends StatelessWidget {
  final ShellChrome chrome;

  /// 是否显示底部 4 个 tab（表单页隐藏，只保留后退 + 保存等工具项）。
  final bool showTabs;
  final int selectedIndex;
  final List<_Tab> tabs;
  final List<String> labels;
  final EdgeInsetsDirectional contentPadding;

  /// 竖条贴在窗口左缘（分屏左窗）还是右缘。
  final bool onLeft;

  /// 竖条底部需要让开的系统簇高度（摄像头朝下时 > 0）。
  final double bottomInset;
  final void Function(_Tab tab) onSelected;

  const _EdgeRail({
    super.key,
    required this.chrome,
    required this.showTabs,
    required this.selectedIndex,
    required this.tabs,
    required this.labels,
    required this.contentPadding,
    required this.onLeft,
    required this.bottomInset,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          // 分隔线放在竖条靠内容的一侧（左缘竖条 → 右边线）。
          border: Border(
            left: onLeft
                ? BorderSide.none
                : BorderSide(color: theme.colorScheme.outlineVariant),
            right: onLeft
                ? BorderSide(color: theme.colorScheme.outlineVariant)
                : BorderSide.none,
          ),
        ),
        child: SafeArea(
          // 关键：竖条本身就位于系统保留条内，绝不能再吃 right inset
          // （viewPadding.right = 84pt 会把 84 宽竖条的内容压成 0 宽 →
          // 图标被挤向左、hit 区塌陷 → 点按无响应）。
          left: false,
          right: false,
          // 顶部消化系统状态/摄像头保留区；底部消化 home indicator。
          top: true,
          bottom: true,
          child: AnimatedPadding(
            duration: kThemeAnimationDuration,
            padding: contentPadding,
            child: AnimatedBuilder(
              animation: chrome,
              builder: (context, _) {
                final tools = _toolbar(context);
                final items = showTabs ? _items() : const <Widget>[];
                return Column(
                  children: [
                    ...tools,
                    const Spacer(),
                    ...items,
                    // 摄像头在底部时给 tab 让位。
                    if (bottomInset > 0) SizedBox(height: bottomInset),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 竖条工具栏：顺序 = 后退（如有）→ 主操作（原 FAB）→ 页面其他动作。
  ///
  /// 所有项与导航项**同样大小与对齐**：44×44 命中区、20pt 图标、与竖条同列；
  /// 系统状态簇占用的顶部区域由 `contentPadding.top` 让开（否则会被挡住）。
  List<Widget> _toolbar(BuildContext context) {
    // 矮竖条不接管工具（工具留在页面标题栏）。
    final showTools = MediaQuery.sizeOf(context).height >= 620;
    final out = <Widget>[];
    // ShellRoute 下 ModalRoute 的 canPop 不可靠，用 GoRouter 判断能否返回。
    if (showTools && GoRouter.of(context).canPop()) {
      out.add(_toolbarIcon(
        context,
        icon: Icons.arrow_back,
        label: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => GoRouter.of(context).pop(),
      ));
    }
    final primary = chrome.primary;
    if (primary != null) {
      // 主操作（原 FAB）：与导航项同尺寸同列，但保留主色底，避免太不显眼。
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Semantics(
          label: primary.label,
          button: true,
          child: InkWell(
            onTap: primary.onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                primary.icon,
                size: 22,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ));
    }
    for (final action in chrome.actions) {
      if (action.child != null) {
        out.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: IconTheme(
            data: const IconThemeData(size: 20),
            child: IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  foregroundColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(child: action.child),
              ),
            ),
          ),
        ));
      } else {
        out.add(_toolbarIcon(
          context,
          icon: action.icon!,
          label: action.label,
          onPressed: action.onPressed,
        ));
      }
    }
    return out;
  }

  Widget _toolbarIcon(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 20,
              color: onPressed == null
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _items() {
    return [
      for (var i = 0; i < tabs.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _EdgeRailItem(
            itemKey: ValueKey('edge-tab-${labels[i]}'),
            icon: tabs[i].icon,
            selectedIcon: tabs[i].selectedIcon,
            label: labels[i],
            selected: i == selectedIndex,
            onTap: () => onSelected(tabs[i]),
          ),
        ),
    ];
  }
}

/// 竖条项：44×44 命中区、图标 20（与系统状态图标同尺寸），居中于系统保留条内
/// 以与系统图标列对齐；选中态 M3 胶囊（primaryContainer）。
class _EdgeRailItem extends StatelessWidget {
  final Key? itemKey;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _EdgeRailItem({
    this.itemKey,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: itemKey,
      label: label,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Icon(
            selected ? selectedIcon : icon,
            size: 20,
            color:
                selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
