import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/mouse_wheel_horizontal_scroll.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../repositories/recipe_repository.dart';

/// 按商家预估成本：横向滚动卡片（对齐 web MerchantCostCards）。
/// 桌面端支持鼠标滚轮水平滚动（见 MouseWheelHorizontalScroll）。
class MerchantCostCards extends StatefulWidget {
  final List<MerchantCostItem> merchants;
  final bool loading;
  final String userCurrency;
  const MerchantCostCards(
      {super.key,
      required this.merchants,
      this.loading = false,
      this.userCurrency = 'CNY'});

  @override
  State<MerchantCostCards> createState() => _MerchantCostCardsState();
}

class _MerchantCostCardsState extends State<MerchantCostCards> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.store_outlined,
              color: theme.colorScheme.tertiary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.recipeMerchantCostEstimate,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (widget.loading && widget.merchants.isEmpty)
          const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (widget.merchants.isEmpty)
          SizedBox(
            height: 140,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store_outlined,
                      size: 40, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  Text(l10n.recipeNoMerchantPriceData,
                      style: TextStyle(color: theme.colorScheme.outline)),
                ],
              ),
            ),
          )
        else
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: MouseWheelHorizontalScroll(
              controller: _controller,
              child: SizedBox(
                height: 168,
                child: ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.merchants.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) =>
                      _buildCard(context, theme, widget.merchants[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, ThemeData theme, MerchantCostItem m) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: m.isRecommended
              ? const Color(0xFFFF9800)
              : theme.colorScheme.outlineVariant,
          width: m.isRecommended ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: m.isRecommended
            ? (theme.brightness == Brightness.dark
                ? theme.colorScheme.surface
                : const Color(0xFFFFF8E1))
            : theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                  m.merchantName.isEmpty
                      ? l10n.recipeMerchantFallbackName(m.merchantId)
                      : m.merchantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            if (m.isRecommended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(l10n.recipeBestValue,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Text(
                l10n.recipeCoveredCount(m.coveredCount, m.totalIngredients),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
            if (m.fallbackChains.isNotEmpty) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 20,
                height: 20,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  icon: Icon(Icons.info_outline,
                      color: theme.colorScheme.primary),
                  onPressed: () => _showFallbackDialog(context, m),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          Text(formatMoney(m.totalCost, widget.userCurrency),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: l10n.recipeInStore(
                    formatMoney(m.coveredCost, widget.userCurrency)),
                style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600)),
            if (m.externalCost > 0)
              TextSpan(
                text:
                    '  ${l10n.recipeExternal(formatMoney(m.externalCost, widget.userCurrency))}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: const Color(0xFFEF6C00)),
              ),
          ])),
          if (m.missingIngredients.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(l10n.recipeMissingIngredients(m.missingIngredients.join(', ')),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: const Color(0xFFF9A825)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  void _showFallbackDialog(BuildContext context, MerchantCostItem m) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.recipeCalculatedFromIngredientsPrice),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final chain in m.fallbackChains)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(chain,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.recipeGotIt),
          ),
        ],
      ),
    );
  }
}
