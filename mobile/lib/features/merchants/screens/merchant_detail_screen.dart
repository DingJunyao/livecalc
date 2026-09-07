import 'dart:io' show Platform;
import '../../../shared/providers/calc_context_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_formatters.dart' hide formatMoney;
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/pending_change_banner.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../auth/providers/auth_provider.dart';
import '../screens/merchant_form_screen.dart';
import '../models/merchant.dart';
import '../models/merchant_product_price.dart';
import '../providers/map_config_provider.dart';
import '../providers/merchant_provider.dart';
import '../widgets/merchant_map_view.dart';

class MerchantDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const MerchantDetailScreen({super.key, required this.id});

  @override
  ConsumerState<MerchantDetailScreen> createState() =>
      _MerchantDetailScreenState();
}

class _MerchantDetailScreenState extends ConsumerState<MerchantDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(merchantDetailPageProvider(widget.id).notifier).load();
      if (!Platform.isIOS) ref.read(mapConfigProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(merchantDetailPageProvider(widget.id));
    final mapConfig = ref.watch(mapConfigProvider);
    final mapReady = Platform.isIOS || mapConfig.loaded;
    final merchant = state.merchant?.mergedWithPending();
    final modifications = <String>{
      ...?merchant?.pendingModificationLabels,
    };
    final deletions = <String>{
      if (merchant?.pendingProposal?.action == 'delete')
        l10n.journeyBasicInformation,
    };

    if (state.error != null && merchant == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.merchantDetailTitle)),
        body: ErrorDisplay(
          message: state.error!,
          onRetry: () =>
              ref.read(merchantDetailPageProvider(widget.id).notifier).load(),
        ),
      );
    }
    if (merchant == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.merchantDetailTitle)),
        body: const LoadingIndicator(),
      );
    }

    final notifier = ref.read(merchantDetailPageProvider(widget.id).notifier);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                merchant.name.trim().isEmpty
                    ? l10n.merchantUnnamed
                    : merchant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(l10n.merchantChip,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.merchantEditTitle,
            onPressed: () => _editMerchant(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.journeyRefresh,
            onPressed: state.loading ? null : () => notifier.load(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.load(),
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
            _BasicInfoCard(
              merchant: merchant,
              onEdit: _editMerchant,
            ),
            if (merchant.latitude != null && merchant.longitude != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.map,
                              color: theme.colorScheme.secondary, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.merchantLocation,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 12),
                      SizedBox(
                        height: 260,
                        child: mapReady
                            ? MerchantMapView(
                                merchants: [merchant],
                                selectedId: merchant.id,
                                mapConfig: mapConfig,
                              )
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _ProductPricesCard(
              prices: state.productPrices,
              loading: state.loadingPrices,
              hasMore: state.pricesHasMore,
              onLoadMore: notifier.loadMorePrices,
              userCurrency: ref.read(displayCurrencyProvider),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMerchant() async {
    final l10n = AppLocalizations.of(context);
    final state = ref.read(merchantDetailPageProvider(widget.id));
    final merchant = state.merchant?.mergedWithPending();
    if (merchant == null) return;
    final result = await context.push<MerchantFormResult>(
      '/merchants/${widget.id}/edit',
      extra: MerchantFormArguments(
        merchant: merchant,
        isAdmin: ref.read(authProvider).user?.isAdmin == true,
      ),
    );
    if (result?.saved != true || !mounted) return;
    final message = result!.pending
        ? (result.message.isEmpty
            ? l10n.commonSubmittedPendingReview
            : result.message)
        : (result.message.isEmpty ? l10n.merchantSaved : result.message);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    await ref.read(merchantDetailPageProvider(widget.id).notifier).load();
  }
}

// ---- 基本信息 ----

class _BasicInfoCard extends StatelessWidget {
  final Merchant merchant;
  final VoidCallback onEdit;
  const _BasicInfoCard({required this.merchant, required this.onEdit});

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
            _row(
              theme,
              l10n,
              Icons.store_outlined,
              l10n.merchantName,
              merchant.name.trim().isEmpty
                  ? l10n.merchantUnnamed
                  : merchant.name,
            ),
            if (merchant.address != null)
              _row(
                theme,
                l10n,
                Icons.map_outlined,
                l10n.merchantAddress,
                merchant.address!,
              ),
            if (merchant.createdAt != null)
              _row(
                theme,
                l10n,
                Icons.calendar_today_outlined,
                l10n.journeyCreatedAt,
                _fmtDateTime(merchant.createdAt!),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    merchant.isOpen
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    size: 16,
                    color: merchant.isOpen
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.merchantStatus,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(width: 4),
                  Text(':',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (merchant.isOpen
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        merchant.isOpen
                            ? l10n.merchantOpen
                            : l10n.merchantClosed,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: merchant.isOpen
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    ThemeData theme,
    AppLocalizations l10n,
    IconData icon,
    String label,
    String value,
  ) {
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

// ---- 商品价格 ----

class _ProductPricesCard extends StatelessWidget {
  final List<MerchantProductPrice> prices;
  final bool loading;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final String userCurrency;

  const _ProductPricesCard({
    required this.prices,
    required this.loading,
    required this.hasMore,
    required this.onLoadMore,
    this.userCurrency = 'CNY',
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
                Icon(Icons.shopping_cart_outlined,
                    color: theme.colorScheme.tertiary, size: 20),
                const SizedBox(width: 8),
                Text(l10n.merchantProductPrices,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (prices.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${prices.length}+'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
            const Divider(height: 8),
            if (loading && prices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (prices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 40, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 8),
                      Text(l10n.merchantNoProductPrices,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              )
            else ...[
              for (final p in prices) ...[
                InkWell(
                  onTap: () => context.push('/products/${p.productId}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.tertiaryContainer,
                          foregroundColor:
                              theme.colorScheme.onTertiaryContainer,
                          radius: 18,
                          child:
                              const Icon(Icons.inventory_2_outlined, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(_fmtDateTime(p.recordedAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${formatMoney(p.displayPrice, p.currency)}${p.displayUnit}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.tertiary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (p.exchangeRate != null &&
                                p.currency != userCurrency)
                              Text(
                                '≈ ${formatMoney(convertAmount(p.displayPrice, p.exchangeRate), userCurrency)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline),
                              ),
                          ],
                        ),
                        const Icon(Icons.chevron_right,
                            size: 20, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],
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

String _fmtDateTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return formatDateTime(dt.toLocal());
}
