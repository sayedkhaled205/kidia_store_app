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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final TextStyle? currentPriceStyle = compact
        ? theme.textTheme.titleSmall?.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.w800,
    )
        : theme.textTheme.titleMedium?.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.w800,
    );

    final TextStyle? regularPriceStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      decoration: TextDecoration.lineThrough,
      decorationColor: colorScheme.onSurfaceVariant,
    );

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
