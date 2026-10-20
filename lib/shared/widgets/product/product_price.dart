import 'package:flutter/material.dart';

class ProductPrice extends StatelessWidget {
  const ProductPrice({
    required this.price,
    required this.currencySymbol,
    super.key,
    this.regularPrice,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.compact = false,
  });

  final String price;
  final String? regularPrice;
  final String currencySymbol;
  final MainAxisAlignment mainAxisAlignment;
  final bool compact;

  bool get _hasDiscount {
    final String? originalPrice = regularPrice?.trim();

    return originalPrice != null &&
        originalPrice.isNotEmpty &&
        originalPrice != price.trim();
  }

  TextStyle? _currentPriceStyle(ThemeData theme) =>
      (compact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
          ?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          );

  TextStyle? _regularPriceStyle(ThemeData theme) =>
      theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        decoration: TextDecoration.lineThrough,
        decorationColor: theme.colorScheme.onSurfaceVariant,
      );

  /// The price row is one line even when its text is ellipsized. Measure that
  /// line with the same styles and accessibility scaling used by [build].
  double measureHeight(BuildContext context) {
    final theme = Theme.of(context);
    double measure(String value, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final current = measure(
      '$price $currencySymbol',
      _currentPriceStyle(theme),
    );
    if (!_hasDiscount) return current;
    final regular = measure(
      '$regularPrice $currencySymbol',
      _regularPriceStyle(theme),
    );
    return current > regular ? current : regular;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? currentPriceStyle = _currentPriceStyle(theme);
    final TextStyle? regularPriceStyle = _regularPriceStyle(theme);

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            '$price $currencySymbol',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: currentPriceStyle,
          ),
        ),
        if (_hasDiscount) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$regularPrice $currencySymbol',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: regularPriceStyle,
            ),
          ),
        ],
      ],
    );
  }
}
