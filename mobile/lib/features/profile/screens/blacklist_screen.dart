import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/error_display.dart';
import '../../ingredients/models/ingredient.dart';
import '../../ingredients/repositories/ingredient_repository.dart';
import '../repositories/blacklist_repository.dart';

/// 个人黑名单（过敏原屏蔽）：分组订阅 + 手动增删，对齐 web 端 BlacklistDialog。
class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  final BlacklistRepository _repository = BlacklistRepository();
  final IngredientRepository _ingredientRepository = IngredientRepository();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int _searchSeq = 0;

  bool _loading = true;
  String? _error;
  List<BlacklistGroup> _groups = const [];
  List<SubscribedBlacklistGroup> _subscribedGroups = const [];
  List<BlacklistItem> _manualItems = const [];
  Set<int> _subscribedIds = <int>{};
  bool _togglingGroup = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _repository.getManualItems(),
        _repository.getGroups(),
        _repository.getSubscribedGroups(),
      ]);
      if (!mounted) return;
      setState(() {
        _manualItems = results[0] as List<BlacklistItem>;
        _groups = results[1] as List<BlacklistGroup>;
        _subscribedGroups = results[2] as List<SubscribedBlacklistGroup>;
        _subscribedIds = _subscribedGroups.map((g) => g.id).toSet();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'load_failed';
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 优先展示后端返回的 detail 文案，便于用户理解失败原因。
  String _errMsg(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
      return e.message ?? '';
    }
    return e.toString();
  }

  Future<List<Ingredient>> _searchIngredients(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const <Ingredient>[];
    final seq = ++_searchSeq;
    try {
      final page = await _ingredientRepository.search(search: q, limit: 20);
      if (seq != _searchSeq) return const <Ingredient>[];
      return page.items;
    } catch (_) {
      return const <Ingredient>[];
    }
  }

  Future<void> _toggleGroup(BlacklistGroup group) async {
    final l10n = AppLocalizations.of(context);
    if (_togglingGroup) return;
    setState(() => _togglingGroup = true);
    final wasSubscribed = _subscribedIds.contains(group.id);
    try {
      if (wasSubscribed) {
        await _repository.unsubscribeGroup(group.id);
      } else {
        await _repository.subscribeGroup(group.id);
      }
      // 重新拉取订阅明细（含原料列表与数量）
      final subscribed = await _repository.getSubscribedGroups();
      if (!mounted) return;
      setState(() {
        _subscribedGroups = subscribed;
        _subscribedIds = subscribed.map((g) => g.id).toSet();
        _togglingGroup = false;
      });
      _toast(wasSubscribed
          ? l10n.blacklistUnsubscribed
          : l10n.blacklistSubscribed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _togglingGroup = false);
      _toast(l10n.blacklistActionFailed(_errMsg(e)));
    }
  }

  Future<void> _addIngredient(Ingredient ingredient) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _repository.addManual(ingredientId: ingredient.id);
      final items = await _repository.getManualItems();
      if (!mounted) return;
      setState(() => _manualItems = items);
    } catch (e) {
      if (!mounted) return;
      _toast(l10n.blacklistAddFailed(_errMsg(e)));
    }
  }

  Future<void> _removeItem(BlacklistItem item) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _repository.removeManual(ingredientId: item.ingredientId);
      if (!mounted) return;
      setState(() {
        _manualItems =
            _manualItems.where((i) => i.id != item.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      _toast(l10n.blacklistRemoveFailed(_errMsg(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.blacklistTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorDisplay(
                  message: l10n.commonLoadFailedRetry,
                  onRetry: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 快速选择：分组订阅
                      if (_groups.isNotEmpty) ...[
                        Text(l10n.blacklistQuickSelect,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final group in _groups)
                              FilterChip(
                                label: Text(group.name),
                                selected: _subscribedIds.contains(group.id),
                                onSelected: _togglingGroup
                                    ? null
                                    : (_) => _toggleGroup(group),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      // 已订阅分组明细
                      if (_subscribedGroups.isNotEmpty) ...[
                        Text(l10n.blacklistSubscribedGroups,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                        const SizedBox(height: 8),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (var i = 0; i < _subscribedGroups.length; i++)
                                if (i == 0)
                                  _GroupExpansionTile(
                                    group: _subscribedGroups[i],
                                  )
                                else ...[
                                  const Divider(height: 1),
                                  _GroupExpansionTile(
                                    group: _subscribedGroups[i],
                                  ),
                                ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // 手动添加
                      Text(l10n.blacklistManualAdd,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                      const SizedBox(height: 8),
                      Autocomplete<Ingredient>(
                        textEditingController: _searchController,
                        focusNode: _searchFocusNode,
                        displayStringForOption: (ingredient) => ingredient.name,
                        optionsBuilder: (value) =>
                            _searchIngredients(value.text),
                        onSelected: (ingredient) {
                          _searchController.clear();
                          _addIngredient(ingredient);
                        },
                        fieldViewBuilder: (
                          ctx,
                          controller,
                          focusNode,
                          onFieldSubmitted,
                        ) =>
                            TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: l10n.blacklistSearchLabel,
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => onFieldSubmitted(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_manualItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            l10n.blacklistManualEmpty,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in _manualItems)
                              InputChip(
                                label: Text(
                                  item.ingredientName ?? '#${item.ingredientId}',
                                ),
                                tooltip: item.reason,
                                onDeleted: () => _removeItem(item),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _GroupExpansionTile extends StatelessWidget {
  final SubscribedBlacklistGroup group;

  const _GroupExpansionTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ExpansionTile(
      title: Text(
        l10n.blacklistGroupTitle(group.name, group.ingredients.isEmpty
                ? group.ingredientCount
                : group.ingredients.length),
      ),
      subtitle: null,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (group.ingredients.isEmpty)
          Text(
            l10n.commonLoading,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ingredient in group.ingredients)
                Chip(
                  label: Text(ingredient.name),
                  labelStyle: theme.textTheme.bodySmall,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
      ],
    );
  }
}
