import 'package:flutter/material.dart';
import '../models/merchant_price.dart';
import 'sparkline.dart';

/// 各商家最新价格横排卡片（对应 Web 详情页 merchant-price-list）。
class MerchantPriceList extends StatelessWidget {
  final List<MerchantPrice> prices;
  final String unit;
  final bool loading;

  const MerchantPriceList({
    super.key,
    required this.prices,
    this.unit = '',
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
    if (prices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('各商家价格',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 8),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: prices.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) => _MerchantPriceCard(
              price: prices[i],
              unit: unit,
              theme: theme,
            ),
          ),
        ),
      ],
    );
  }
}

class _MerchantPriceCard extends StatelessWidget {
  final MerchantPrice price;
  final String unit;
  final ThemeData theme;
  const _MerchantPriceCard({
    required this.price,
    required this.unit,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final containerColor = price.isLowest
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.onSurface.withValues(alpha: 0.04);
    return Container(
      width: 116,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(10),
        border: price.isLowest
            ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35))
            : null,
      ),
      child: Stack(
        children: [
          if (price.sparklineData != null && price.sparklineData!.length >= 2)
            Positioned(
              right: 0,
              bottom: 0,
              child: Sparkline(
                data: price.sparklineData!,
                color: theme.colorScheme.tertiary,
                width: 56,
                height: 20,
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                price.merchantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 4),
              Text(
                '¥${price.price.toStringAsFixed(2)}'
                '${unit.isEmpty ? '' : ' / $unit'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: price.isLowest
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (price.isLowest)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('最低',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary, fontSize: 9)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
