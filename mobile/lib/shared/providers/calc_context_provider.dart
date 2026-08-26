import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/merchants/repositories/merchant_repository.dart';

/// 会话级临时覆盖（导航栏切换）：币种/地区/计算范围，仅当前会话有效，不修改用户配置。
class CalcContextState {
  /// 用户选择的地区（展示/编辑用）
  final int? regionId;

  /// 计算范围：'' 全部地区 / country / province / city / county / null 跟随配置
  final String? scope;

  /// 会话币种覆盖：null = 跟随用户配置
  final String? currency;

  /// 已解析的生效地区节点（发给后端 X-Region）
  final int? effectiveRegionId;

  const CalcContextState({
    this.regionId,
    this.scope,
    this.currency,
    this.effectiveRegionId,
  });

  const CalcContextState.empty()
      : regionId = null,
        scope = null,
        currency = null,
        effectiveRegionId = null;

  bool get isEmpty =>
      regionId == null && scope == null && currency == null && effectiveRegionId == null;
}

/// 模块级持有，供 Dio 拦截器读取（避免 riverpod 与 dio 的循环依赖）。
CalcContextState _calcContext = const CalcContextState.empty();
CalcContextState get currentCalcContext => _calcContext;

const _scopeLevel = {
  '': -1,
  'country': 0,
  'province': 1,
  'city': 2,
  'county': 3,
};

class CalcContextNotifier extends StateNotifier<CalcContextState> {
  CalcContextNotifier() : super(const CalcContextState.empty());

  /// 应用会话覆盖：解析 地区 + 计算范围 -> 生效地区节点后更新状态与请求头持有者。
  Future<void> apply({
    required int? regionId,
    required String? scope,
    required String? currency,
  }) async {
    final effective = await _resolveEffectiveRegion(regionId, scope);
    state = CalcContextState(
      regionId: regionId,
      scope: scope,
      currency: (currency == null || currency.isEmpty) ? null : currency,
      effectiveRegionId: effective,
    );
    _calcContext = state;
  }

  void clear() {
    state = const CalcContextState.empty();
    _calcContext = state;
  }

  Future<int?> _resolveEffectiveRegion(int? regionId, String? scope) async {
    if (regionId == null) return null;
    final target = _scopeLevel[scope ?? 'country'] ?? 0;
    if (target < 0) return null; // 全部地区
    Map<String, dynamic> detail;
    try {
      detail = await MerchantRepository().getRegion(regionId);
    } catch (_) {
      return null;
    }
    final rawAncestors = (detail['ancestors'] as List?) ?? const [];
    final chain = <Map<String, dynamic>>[
      for (final a in rawAncestors)
        if (a is Map)
          {
            'id': (a['id'] as num?)?.toInt(),
            'level': (a['level'] as num?)?.toInt() ?? 0,
          },
      {'id': regionId, 'level': (detail['level'] as num?)?.toInt() ?? 0},
    ];
    final selfLevel = chain
        .where((n) => n['id'] == regionId)
        .map((n) => n['level'] as int)
        .firstOrNull;
    final level = (selfLevel == null || selfLevel > target) ? target : selfLevel;
    final node = chain.where((n) => n['level'] == level).firstOrNull;
    return (node?['id'] as int?) ?? regionId;
  }
}

final calcContextProvider =
    StateNotifierProvider<CalcContextNotifier, CalcContextState>(
        (ref) => CalcContextNotifier());

/// 展示币种：会话覆盖优先，否则用户配置（后端价格已按 X-Currency 折算）。
final displayCurrencyProvider = Provider<String>((ref) {
  final ctx = ref.watch(calcContextProvider);
  final c = ctx.currency;
  if (c != null && c.isNotEmpty) return c;
  return ref.watch(authProvider).user?.currency ?? 'CNY';
});