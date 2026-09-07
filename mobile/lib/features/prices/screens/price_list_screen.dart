import 'package:flutter/material.dart';
import '../../../shared/providers/calc_context_provider.dart';
import '../../../shared/widgets/calc_context_menu_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/i18n/app_formatters.dart' hide formatMoney;
import '../models/price_record.dart';
import '../providers/price_provider.dart';
import '../../merchants/models/merchant.dart';
import '../../merchants/providers/merchant_provider.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/screens/price_record_edit_screen.dart';
import '../../../l10n/app_localizations.dart';

class PriceListScreen extends ConsumerStatefulWidget {
  const PriceListScreen({super.key});

  @override
  ConsumerState<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends ConsumerState<PriceListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _merchantsLoaded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(priceListProvider.notifier).loadRecords();
      if (!_merchantsLoaded) {
        ref.read(merchantListProvider.notifier).load();
        _merchantsLoaded = true;
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final notifier = ref.read(priceListProvider.notifier);
      if (notifier.canLoadMore) {
        notifier.loadRecords(loadMore: true);
      }
    }
  }

  /// 打开新增价格记录页；保存成功（pop true）后刷新列表。
  Future<void> _openRecordForm() async {
    final saved = await context.push<bool>('/prices/record');
    if (saved == true && mounted) {
      ref.read(priceListProvider.notifier).loadRecords();
    }
  }

  /// 打开编辑页，保存后局部更新对应记录。
  /// 不调 loadRecords 以保留滚动位置。
  Future<void> _openEditRecord(PriceRecord r) async {
    final result = await context.push<PriceRecordFormResult>(
      '/prices/record/edit',
      extra: PriceRecordFormArguments(
        merchants: ref.read(merchantListProvider).items,
        fixedProductId: r.productId,
        fixedProductName: r.productName,
        initialPrice: r.price,
        initialQuantity: r.quantity,
        initialUnit: r.unit,
        initialMerchantId: r.merchantId,
        initialRecordType: r.recordType,
        initialRecordedAt: DateTime.tryParse(r.recordedAt),
        initialNotes: r.notes,
        initialCurrency: r.currency,
      ),
    );
    if (result != null && mounted) {
      // notifier 不持有 merchant 列表，由屏幕层反查商家名传入；
      // 反查不到（如商家未加载）则 merchantName 为 null，卡片暂显「未知商家」。
      String? merchantName;
      if (result.merchantId != null) {
        final m = ref
            .read(merchantListProvider)
            .items
            .where((m) => m.id == result.merchantId)
            .firstOrNull;
        merchantName = m?.name;
      }
      final ok = await ref.read(priceListProvider.notifier).updateRecord(
            r.id,
            price: result.price,
            quantity: result.quantity,
            unit: result.unit,
            merchantId: result.merchantId,
            merchantName: merchantName,
            recordType: result.recordType,
            recordedAt: result.recordedAt,
            notes: result.notes,
            currency: result.currency,
          );
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? l10n.journeyUpdated : l10n.journeyUpdateFailed),
          ),
        );
      }
    }
  }

  /// 二次确认后删除记录。
  Future<void> _confirmDelete(PriceRecord r) async {
    final theme = Theme.of(context);
    final userCurrency = ref.read(displayCurrencyProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.journeyDeleteRecordTitle),
          content: Text(
            l10n.priceDeleteRecordMessage(
              r.productName,
              formatMoney(r.price, userCurrency),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await _deleteRecord(r);
    }
  }

  Future<void> _deleteRecord(PriceRecord r) async {
    final ok = await ref.read(priceListProvider.notifier).deleteRecord(r.id);
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ok ? l10n.journeyDeleted : l10n.journeyDeleteFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 会话级临时覆盖（地区/范围/币种）变化后刷新当前页数据
    ref.listen(calcContextProvider, (_, __) {
      ref.read(priceListProvider.notifier).loadRecords();
    });
    final theme = Theme.of(context);
    final state = ref.watch(priceListProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.journeyPriceRecords),
        actions: [
          const CalcContextMenuButton(),
          IconButton(
            icon: const Icon(Icons.bolt),
            tooltip: l10n.quickFillTitle,
            onPressed: () => context.push('/prices/quick-fill'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.loading
                ? null
                : () => ref.read(priceListProvider.notifier).loadRecords(),
            tooltip: l10n.journeyRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(theme, state, l10n),
          Expanded(child: _buildBody(theme, state, l10n)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openRecordForm,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ---- Search + filter button ----

  Widget _buildSearchBar(
    ThemeData theme,
    PriceListState state,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.priceSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(priceListProvider.notifier).setSearch('');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) {
                ref.read(priceListProvider.notifier).setSearch(v);
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          _buildFilterButton(theme, state),
        ],
      ),
    );
  }

  Widget _buildFilterButton(ThemeData theme, PriceListState state) {
    final l10n = AppLocalizations.of(context);
    final activeCount = ref.read(priceListProvider.notifier).activeFilterCount;
    final hasActive = activeCount > 0;
    return SizedBox(
      height: 48,
      child: Badge(
        isLabelVisible: hasActive,
        label: Text('$activeCount'),
        child: IconButton.filledTonal(
          icon: const Icon(Icons.tune),
          onPressed: () => _showFilterDialog(theme, state),
          tooltip: l10n.journeyFilters,
          style: hasActive
              ? IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                )
              : null,
        ),
      ),
    );
  }

  void _showFilterDialog(ThemeData theme, PriceListState state) {
    final merchantState = ref.read(merchantListProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterSheet(
        theme: theme,
        state: state,
        merchants: merchantState.items,
        onApply: ({
          required int? merchantId,
          required String? recordType,
          required String? startDate,
          required String? endDate,
        }) =>
            ref.read(priceListProvider.notifier).applyFilters(
                  merchantId: merchantId,
                  recordType: recordType,
                  startDate: startDate,
                  endDate: endDate,
                ),
      ),
    );
  }

  // ---- List body ----

  Widget _buildBody(
    ThemeData theme,
    PriceListState state,
    AppLocalizations l10n,
  ) {
    if (state.loading && state.records.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.error != null && state.records.isEmpty) {
      return ErrorDisplay(
        message: state.error!,
        onRetry: () => ref.read(priceListProvider.notifier).loadRecords(),
      );
    }
    if (state.records.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long,
        title: l10n.journeyNoPriceRecords,
        subtitle: l10n.priceListEmptySubtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(priceListProvider.notifier).loadRecords(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: state.records.length + (state.hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= state.records.length) {
            return _buildLoadMoreIndicator(state);
          }
          return _buildRecordCard(theme, state.records[i]);
        },
      ),
    );
  }

  Widget _buildLoadMoreIndicator(PriceListState state) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: state.loadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: () => ref
                    .read(priceListProvider.notifier)
                    .loadRecords(loadMore: true),
                child: Text(l10n.journeyLoadMore),
              ),
      ),
    );
  }

  Widget _buildRecordCard(ThemeData theme, PriceRecord r) {
    final userCurrency = ref.read(displayCurrencyProvider);
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: r.productId > 0
            ? () => context.push('/products/${r.productId}')
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                radius: 20,
                child: Text(
                  r.productName.isNotEmpty
                      ? r.productName.characters.first
                      : '?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.productName,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatMoney(r.price, r.currency)}'
                      ' / ${_fmtQty(r.quantity)}'
                      '${r.unit.isEmpty ? '' : ' ${r.unit}'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (r.exchangeRate != null && r.currency != userCurrency)
                      Text(
                        '≈ ${formatMoney(convertAmount(r.price, r.exchangeRate), userCurrency)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 13,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            r.merchantName ?? l10n.journeyUnknownMerchant,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.schedule,
                          size: 13,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            _formatTime(r.recordedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: l10n.priceMoreActions,
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Text(l10n.commonEdit),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(l10n.commonDelete),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'edit') {
                    _openEditRecord(r);
                  } else if (v == 'delete') {
                    _confirmDelete(r);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 整数不带小数，否则最多两位并去掉尾随 0。
  String _fmtQty(double q) => formatQuantity(q);

  /// ISO 时间字符串 → 本地化日期时间。
  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return formatDateTime(dt.toLocal());
  }
}

// ---- Filter bottom sheet ----

class _FilterSheet extends StatefulWidget {
  final ThemeData theme;
  final PriceListState state;
  final List<Merchant> merchants;
  final void Function({
    required int? merchantId,
    required String? recordType,
    required String? startDate,
    required String? endDate,
  }) onApply;

  const _FilterSheet({
    required this.theme,
    required this.state,
    required this.merchants,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late int? _merchantId;
  late String? _recordType;
  late String? _startDate;
  late String? _endDate;

  @override
  void initState() {
    super.initState();
    _merchantId = widget.state.filterMerchantId;
    _recordType = widget.state.filterRecordType;
    _startDate = widget.state.filterStartDate;
    _endDate = widget.state.filterEndDate;
  }

  bool get _hasActive =>
      _merchantId != null ||
      _recordType != null ||
      _startDate != null ||
      _endDate != null;

  void _apply() {
    widget.onApply(
      merchantId: _merchantId,
      recordType: _recordType,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final initial =
        DateTime.tryParse(isStart ? (_startDate ?? '') : (_endDate ?? '')) ??
            DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        final s = DateFormat('yyyy-MM-dd').format(picked);
        if (isStart) {
          _startDate = s;
        } else {
          _endDate = s;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Text(l10n.priceFilterTitle,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_hasActive)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _merchantId = null;
                          _recordType = null;
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: Text(l10n.journeyClear),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Merchant dropdown
                  Text(l10n.priceMerchantLabel,
                      style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _merchantId,
                        isExpanded: true,
                        hint: Text(l10n.priceFilterAllMerchants),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(l10n.priceFilterAllMerchants),
                          ),
                          ...widget.merchants.map(
                            (m) => DropdownMenuItem<int?>(
                              value: m.id,
                              child: Text(
                                m.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _merchantId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Record type chips
                  Text(l10n.priceFilterRecordType,
                      style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: Text(l10n.priceRecordTypePurchase),
                        selected: _recordType == 'purchase',
                        onSelected: (_) => setState(() => _recordType =
                            _recordType == 'purchase' ? null : 'purchase'),
                      ),
                      FilterChip(
                        label: Text(l10n.priceRecordTypePrice),
                        selected: _recordType == 'price',
                        onSelected: (_) => setState(() => _recordType =
                            _recordType == 'price' ? null : 'price'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Date range
                  Text(l10n.priceFilterDateRange,
                      style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(
                          theme,
                          label: l10n.priceFilterStart,
                          value: _startDate,
                          onTap: () => _pickDate(true),
                          onClear: () => setState(() => _startDate = null),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('~', style: theme.textTheme.bodyMedium),
                      ),
                      Expanded(
                        child: _buildDateField(
                          theme,
                          label: l10n.priceFilterEnd,
                          value: _endDate,
                          onTap: () => _pickDate(false),
                          onClear: () => setState(() => _endDate = null),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    _apply();
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.journeyConfirm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(
    ThemeData theme, {
    required String label,
    required String? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          isDense: true,
        ),
        child: Text(value ?? ''),
      ),
    );
  }
}
