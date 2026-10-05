import 'package:flutter/material.dart';
// formatDate 来自本模块；formatMoney 与 currency_fmt 重名，隐藏后者（金额格式化沿用 currency_fmt）
import '../../core/i18n/app_formatters.dart' hide formatMoney;
import '../../l10n/app_localizations.dart';
import '../models/merchant_price.dart';
import '../utils/currency_fmt.dart';
import 'sparkline.dart';

/// 各商家最新价格横排卡片（对应 Web 详情页 merchant-price-list）。
class MerchantPriceList extends StatelessWidget {
  final List<MerchantPrice> prices;
  final String unit;
  final bool loading;
  final String userCurrency;

  const MerchantPriceList({
    super.key,
    required this.prices,
    this.unit = '',
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
    if (prices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.merchantPricesTitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 8),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: prices.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) => _MerchantPriceCard(
              price: prices[i],
              unit: unit,
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

class _MerchantPriceCard extends StatelessWidget {
  final MerchantPrice price;
  final String unit;
  final ThemeData theme;
  final String userCurrency;
  final AppLocalizations l10n;
  const _MerchantPriceCard({
    required this.price,
    required this.unit,
    required this.theme,
    required this.userCurrency,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    // 陈旧记录（>30 天）不参与最低价比较：后端不会对陈旧记录标 isLowest，
    // 这里再防御一次，避免陈旧卡片误用最低价高亮。
    final showLowest = price.isLowest && !price.isStale;
    final containerColor = showLowest
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.onSurface.withValues(alpha: 0.04);
    final contentOpacity = price.isStale ? 0.5 : 1.0;
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
          if (price.sparklineData != null && price.sparklineData!.length >= 2)
            Positioned(
              right: 0,
              bottom: 0,
              child: Sparkline(
                data: price.sparklineData!,
                color: price.isStale
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
                  '${formatMoney(price.price, price.currency ?? userCurrency)}'
                  '${unit.isEmpty ? '' : ' / $unit'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: showLowest
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                if (price.recordedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _fmtRecordedDate(price.recordedAt!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                if (price.currency != null &&
                    price.exchangeRate != null &&
                    price.currency != userCurrency)
                  Text(
                    '≈ ${formatMoney(convertAmount(price.price, price.exchangeRate!), userCurrency)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                if (showLowest)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(l10n.merchantLowest,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onPrimary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 记录时间（本地时区日期）；解析失败时原样展示，与详情页 _fmtDate 口径一致。
  String _fmtRecordedDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return formatDate(dt.toLocal());
  }
}
