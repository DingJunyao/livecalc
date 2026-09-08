import 'package:flutter/material.dart';
import '../../../shared/providers/calc_context_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_formatters.dart' hide formatMoney;
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/latest_price.dart';
import '../../../shared/models/merchant_price.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/directional_icons.dart';
import '../../../shared/widgets/entity_units_card.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/merchant_price_list.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../../shared/widgets/nutrition_card.dart';
import '../../../shared/widgets/pending_change_banner.dart';
import '../../../shared/screens/price_record_edit_screen.dart';
import '../../merchants/providers/merchant_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../prices/models/price_record.dart';
import '../../prices/screens/price_record_form_screen.dart';
import '../../recipes/widgets/cost_trend_chart.dart';
import '../models/product.dart';
import '../screens/product_form_screen.dart' show ProductFormResult;
import '../providers/product_provider.dart';
import '../repositories/product_repository.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const ProductDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(productDetailPageProvider(widget.id).notifier)
          .load(initialDays: 30);
      final merchants = ref.read(merchantListProvider);
      if (merchants.items.isEmpty && !merchants.loading) {
        ref.read(merchantListProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(productDetailPageProvider(widget.id));
    final product = state.product?.mergedWithPending();

    if (state.error != null && product == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.productDetailTitle)),
        body: ErrorDisplay(
          message: state.error!,
          onRetry: () =>
              ref.read(productDetailPageProvider(widget.id).notifier).load(),
        ),
      );
    }
    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.productDetailTitle)),
        body: LoadingIndicator(message: l10n.commonLoading),
      );
    }

    final notifier = ref.read(productDetailPageProvider(widget.id).notifier);
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.isAdmin ?? false;
    final userCurrency = ref.read(displayCurrencyProvider);
    final modifications = <String>{
      for (final field
          in product.pendingProposal?.updateData.keys ?? const <String>[])
        switch (field) {
          'name' => l10n.productPendingName,
          'brand' => l10n.productPendingBrand,
          'barcode' => l10n.productPendingBarcode,
          'ingredient_id' => l10n.productPendingLinkedIngredient,
          'aliases' => l10n.productPendingAliases,
          'tags' => l10n.productPendingTags,
          _ => field,
        },
      if (state.nutrition?.pendingProposal != null)
        l10n.journeyPendingNutrition,
      if (state.units.any((unit) => unit.isPending))
        l10n.journeyPendingCustomUnits,
      if (state.densities.any((density) => density.isPending))
        l10n.journeyPendingDensity,
    };
    final deletions = <String>{
      if (product.pendingProposal?.action == 'delete')
        l10n.journeyBasicInformation,
      if (state.deletedUnitIds.isNotEmpty) l10n.journeyPendingCustomUnits,
      if (state.deletedDensityIds.isNotEmpty) l10n.journeyPendingDensity,
    };
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(product.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(l10n.productChip,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments_outlined),
            tooltip: l10n.journeyRecordPrice,
            onPressed: () => _openAddRecord(notifier),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') {
                _openEditBasicPage(notifier, product);
              } else if (v == 'delete') {
                _confirmDelete(notifier, product);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(l10n.productEditBasicInfo),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(l10n.journeyDeleteProductTitle),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.journeyRefresh,
            onPressed:
                state.loading ? null : () => notifier.load(initialDays: 30),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.load(initialDays: 30),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (modifications.isNotEmpty || deletions.isNotEmpty) ...[
              PendingChangeBanner(
                modifications: modifications,
                deletions: deletions,
              ),
              const SizedBox(height: 16),
            ],
            _ProductBasicInfoCard(
              product: product,
              onEdit: () => _openEditBasicPage(notifier, product),
              onIngredientTap: product.ingredientId == null
                  ? null
                  : () => context.push('/ingredients/${product.ingredientId}'),
            ),
            const SizedBox(height: 16),
            _ProductLatestPriceCard(
              latest: state.latestPrice,
              merchantPrices: state.merchantPrices,
              loadingLatest: state.loadingLatest,
              loadingMerchants: state.loadingMerchants,
              currency: userCurrency,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CostTrendChart(
                  points: state.chartPoints,
                  loading: state.loadingChart,
                  userCurrency: userCurrency,
                  onRangeChange: (days) => notifier.reloadChart(days),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ProductPriceRecordsCard(
              records: state.records,
              loading: state.loadingRecords,
              hasMore: state.recordsHasMore,
              currency: userCurrency,
              onLoadMore: notifier.loadMoreRecords,
              onAdd: () => _openAddRecord(notifier),
              onEdit: (r) => _openEditRecord(notifier, r),
              onDelete: (r) => _confirmDeleteRecord(notifier, r),
            ),
            const SizedBox(height: 16),
            NutritionCard(
              entityType: 'product',
              entityId: widget.id,
              entityName: product.name,
              nutrition: state.nutrition,
              loading: state.loadingNutrition,
              saving: state.savingNutrition,
              allowClear: true,
              onRefresh: notifier.refreshNutrition,
              onSave: notifier.saveNutrition,
              onClear: notifier.clearNutrition,
            ),
            const SizedBox(height: 16),
            EntityUnitsCard(
              entityType: 'product',
              entityId: widget.id,
              entityName: product.name,
              units: state.units,
              unmappedUnits: state.unmappedUnits,
              densities: state.densities,
              loading: state.loadingUnits,
              isAdmin: isAdmin,
              onAddUnit: (input) => notifier.addUnit(
                unitName: input.unitName,
                conversionFactor: input.conversionFactor,
                weightPerUnit: input.weightPerUnit,
                isDefault: input.isDefault,
                isAdmin: isAdmin,
              ),
              onEditUnit: (unitId, input) => notifier.updateUnit(
                unitId,
                unitName: input.unitName,
                conversionFactor: input.conversionFactor,
                weightPerUnit: input.weightPerUnit,
                isDefault: input.isDefault,
                isAdmin: isAdmin,
              ),
              onDeleteUnit: notifier.deleteUnit,
              onQuickAddUnmapped: (unit) =>
                  notifier.quickAddUnmappedUnit(unit, isAdmin: isAdmin),
              onAddDensity: (input) => notifier.addDensity(
                density: input.density,
                condition: input.condition,
                isAdmin: isAdmin,
              ),
              onDeleteDensity: notifier.deleteDensity,
            ),
          ],
        ),
      ),
    );
  }

  // ---- 记录价格 ----
  Future<void> _openAddRecord(ProductDetailPageNotifier notifier) async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    final product = ref.read(productDetailPageProvider(widget.id)).product;
    if (product == null) return;
    final saved = await context.push<bool>(
      '/prices/record',
      extra: PriceRecordFormPrefill(
        product: product,
        lockProduct: true,
      ),
    );
    if (saved == true && mounted) {
      await notifier.load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.productPriceRecorded)),
        );
      }
    }
  }

  Future<void> _openEditRecord(
    ProductDetailPageNotifier notifier,
    PriceRecord record,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    final merchants = ref.read(merchantListProvider).items;
    final result = await context.push<PriceRecordFormResult>(
      '/prices/record/edit',
      extra: PriceRecordFormArguments(
        merchants: merchants,
        fixedProductId: widget.id,
        fixedProductName:
            ref.read(productDetailPageProvider(widget.id)).product?.name,
        initialPrice: record.price,
        initialQuantity: record.quantity,
        initialUnit: record.unit,
        initialMerchantId: record.merchantId,
        initialRecordType: record.recordType,
        initialRecordedAt: DateTime.tryParse(record.recordedAt),
        initialNotes: record.notes,
        initialCurrency: record.currency,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await notifier.updateRecord(
        record.id,
        price: result.price,
        quantity: result.quantity,
        unit: result.unit,
        merchantId: result.merchantId,
        recordType: result.recordType,
        recordedAt: result.recordedAt,
        notes: result.notes,
        currency: result.currency,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.journeyUpdated)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.journeyUpdateFailed)),
        );
      }
    }
  }

  Future<void> _confirmDeleteRecord(
    ProductDetailPageNotifier notifier,
    PriceRecord record,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.journeyDeleteRecordTitle),
        content: Text(l10n.journeyDeleteThisRecordMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await notifier.deleteRecord(record.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.journeyDeleted)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.journeyDeleteFailed)),
        );
      }
    }
  }

  // ---- 编辑基本信息 ----
  Future<void> _openEditBasicPage(
    ProductDetailPageNotifier notifier,
    Product product,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await context.push<ProductFormResult>(
      '/products/${product.id}/edit',
      extra: product,
    );
    if (result?.saved == true && mounted) {
      await notifier.load(initialDays: 30);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result!.pending
                  ? (result.message.isEmpty
                      ? l10n.journeyEditSubmitted
                      : result.message)
                  : l10n.journeyBasicInfoSaved,
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    ProductDetailPageNotifier notifier,
    Product product,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.journeyDeleteProductTitle),
        content: Text(l10n.journeyDeleteProductMessage(product.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final review = await ProductRepository().deleteProduct(widget.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            review.pending
                ? (review.message.isEmpty
                    ? l10n.journeyDeleteProposalSubmitted
                    : review.message)
                : l10n.journeyProductDeleted,
          ),
        ),
      );
      if (review.applied) context.go('/products');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.journeyDeleteFailed)),
        );
      }
    }
  }
}

// ---- 基本信息卡 ----

class _ProductBasicInfoCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback? onIngredientTap;

  const _ProductBasicInfoCard({
    required this.product,
    required this.onEdit,
    this.onIngredientTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(l10n.journeyBasicInformation,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: l10n.commonEdit,
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
              ],
            ),
            const Divider(height: 8),
            if (product.brand != null && product.brand!.isNotEmpty)
              _ProductInfoRow(
                icon: Icons.tag_outlined,
                label: l10n.productBrand,
                value: product.brand!,
              ),
            if (product.barcode != null && product.barcode!.isNotEmpty)
              _ProductInfoRow(
                icon: Icons.barcode_reader,
                label: l10n.productBarcode,
                value: product.barcode!,
              ),
            if (product.ingredientName != null)
              InkWell(
                onTap: onIngredientTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined,
                          size: 16, color: theme.colorScheme.outline),
                      const SizedBox(width: 12),
                      Text(l10n.productLinkedIngredient,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                      const SizedBox(width: 4),
                      Text(':',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          product.ingredientName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Icon(DirectionalIcons.forwardArrow(context),
                          size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            if (product.aliases.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.file_copy_outlined,
                        size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final alias in product.aliases)
                            Chip(
                              label: Text(alias),
                              labelStyle: theme.textTheme.bodySmall,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (product.tags.isNotEmpty)
              _ProductInfoRow(
                icon: Icons.sell_outlined,
                label: l10n.productTags,
                value: product.tags.join(l10n.commonListSeparator),
              ),
            if (product.createdAt != null)
              _ProductInfoRow(
                icon: Icons.calendar_today_outlined,
                label: l10n.journeyCreatedAt,
                value: _fmtDateTime(product.createdAt!),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProductInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(width: 4),
          Text(':',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ---- 最新价格卡 ----

class _ProductLatestPriceCard extends StatelessWidget {
  final LatestPriceInfo? latest;
  final List<MerchantPrice> merchantPrices;
  final bool loadingLatest;
  final bool loadingMerchants;
  final String currency;

  const _ProductLatestPriceCard({
    required this.latest,
    required this.merchantPrices,
    required this.loadingLatest,
    required this.loadingMerchants,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined,
                    color: theme.colorScheme.tertiary, size: 20),
                const SizedBox(width: 8),
                Text(l10n.journeyLatestPrice,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 16),
            if (loadingLatest && latest == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (latest?.price == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l10n.journeyNoPriceData,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
              )
            else ...[
              Text(
                '${formatMoney(latest!.price!, currency)}'
                '${latest!.unit == null ? '' : ' / ${latest!.unit}'}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.tertiary,
                ),
              ),
              if (latest!.date != null)
                Text(
                  _fmtDate(latest!.date!),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
            ],
            const SizedBox(height: 8),
            MerchantPriceList(
              prices: merchantPrices,
              loading: loadingMerchants,
              userCurrency: currency,
            ),
          ],
        ),
      ),
    );
  }
}

// ---- 价格记录卡 ----

class _ProductPriceRecordsCard extends StatelessWidget {
  final List<PriceRecord> records;
  final bool loading;
  final bool hasMore;
  final String currency;
  final VoidCallback onLoadMore;
  final VoidCallback onAdd;
  final ValueChanged<PriceRecord> onEdit;
  final ValueChanged<PriceRecord> onDelete;

  const _ProductPriceRecordsCard({
    required this.records,
    required this.loading,
    required this.hasMore,
    required this.currency,
    required this.onLoadMore,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(l10n.journeyPriceRecords,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.journeyAddRecord),
                ),
              ],
            ),
            const Divider(height: 8),
            if (loading && records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(l10n.journeyNoPriceRecords,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                ),
              )
            else ...[
              for (final r in records)
                _ProductRecordRow(
                  record: r,
                  currency: currency,
                  onEdit: () => onEdit(r),
                  onDelete: () => onDelete(r),
                ),
              if (hasMore)
                Center(
                  child: TextButton(
                    onPressed: loading ? null : onLoadMore,
                    child: Text(
                      loading ? l10n.commonLoading : l10n.journeyLoadMore,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductRecordRow extends StatelessWidget {
  final PriceRecord record;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductRecordRow({
    required this.record,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final r = record;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.tertiaryContainer,
            foregroundColor: theme.colorScheme.onTertiaryContainer,
            radius: 18,
            child: const Icon(Icons.receipt_long, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatMoney(r.price, currency)} / ${_fmtQty(r.quantity)}'
                  '${r.unit.isEmpty ? '' : ' ${r.unit}'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.merchantName ?? l10n.journeyUnknownMerchant}'
                  ' · ${_fmtDateTime(r.recordedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
              PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- 工具函数 ----

String _fmtQty(double q) => formatQuantity(q);

String _fmtDateTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return formatDateTime(dt.toLocal());
}

String _fmtDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return formatDate(dt.toLocal());
}
