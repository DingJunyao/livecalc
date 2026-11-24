// region_price_card_list.dart — 各地区最新价格横排卡片。
// 与 shared/widgets/merchant_price_list 同布局（116px 卡片横向滚动）：
// 地区名 + 加权价/单位 + 30 天迷你图 + 最低徽标 + 超期置灰。

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../../shared/widgets/sparkline.dart';
import '../repositories/comparison_repository.dart' show RegionCardData;

class RegionPriceCardList extends StatelessWidget {
  final List<RegionCardData> cards;
  final bool loading;
  final String userCurrency;

  const RegionPriceCardList({
    super.key,
    required this.cards,
    this.loading = false,
    this.userCurrency = 'CNY',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.compareRegionPrices,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 8),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) => _RegionPriceCard(
              card: cards[i],
              theme: theme,
              userCurrency: userCurrency,
              l10n: l10n,
            ),
          ),
        ),
      ],
    );
  }
}

class _RegionPriceCard extends StatelessWidget {
  final RegionCardData card;
  final ThemeData theme;
  final String userCurrency;
  final AppLocalizations l10n;

  const _RegionPriceCard({
    required this.card,
    required this.theme,
    required this.userCurrency,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final showLowest = card.isLowest && !card.isStale;
    final containerColor = showLowest
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.onSurface.withValues(alpha: 0.04);
    final contentOpacity = card.isStale ? 0.5 : 1.0;
    return Container(
      width: 116,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(10),
        border: showLowest
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.35))
            : null,
      ),
      child: Stack(
        children: [
          if (card.trend.length >= 2)
            Positioned(
              right: 0,
              bottom: 0,
              child: Sparkline(
                data: card.trend,
                color: card.isStale
                    ? theme.colorScheme.outline
                    : theme.colorScheme.tertiary,
                width: 56,
                height: 20,
              ),
            ),
          Opacity(
            opacity: contentOpacity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
                const Spacer(),
                Text(
                  '${formatMoney(card.price, userCurrency)}'
                  '${card.unit == null ? '' : ' / ${card.unit}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: showLowest ? theme.colorScheme.primary : null,
                  ),
                ),
                if (card.isStale)
                  Text(
                    card.daysSinceRecord != null
                        ? l10n.compareStaleRecord(card.daysSinceRecord!)
                        : l10n.compareStaleRecord(30),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ),
          if (showLowest)
            Positioned(
              right: 0,
              top: 0,
              child: Icon(Icons.emoji_events_outlined,
                  size: 14, color: theme.colorScheme.primary),
            ),
        ],
      ),
    );
  }
}
