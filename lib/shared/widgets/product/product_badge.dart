import 'package:flutter/material.dart';

enum ProductBadgeType {
  offer,
  newArrival,
  outOfStock,
  custom,
}

class ProductBadge extends StatelessWidget {
  const ProductBadge({
    required this.label,
    super.key,
    this.type = ProductBadgeType.custom,
  });

  final String label;
  final ProductBadgeType type;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final _ProductBadgeColors colors = _resolveColors(colorScheme);

    return Semantics(
      label: label,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  _ProductBadgeColors _resolveColors(
      ColorScheme colorScheme,
      ) {
    return switch (type) {
      ProductBadgeType.offer => _ProductBadgeColors(
        background: colorScheme.primary,
        foreground: colorScheme.onPrimary,
        border: colorScheme.primary,
      ),
      ProductBadgeType.newArrival => _ProductBadgeColors(
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
        border: colorScheme.secondary,
      ),
      ProductBadgeType.outOfStock => _ProductBadgeColors(
        background: colorScheme.error,
        foreground: colorScheme.onError,
        border: colorScheme.error,
      ),
      ProductBadgeType.custom => _ProductBadgeColors(
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurface,
        border: colorScheme.outlineVariant,
      ),
    };
  }
}

class ProductDiscountBadge extends StatelessWidget {
  const ProductDiscountBadge({
    required this.price,
    required this.regularPrice,
    super.key,
  });

  final String price;
  final String regularPrice;

  @override
  Widget build(BuildContext context) {
    final int? discountPercentage = _calculateDiscountPercentage();

    if (discountPercentage == null || discountPercentage <= 0) {
      return const SizedBox.shrink();
    }

    return ProductBadge(
      label: '-$discountPercentage%',
      type: ProductBadgeType.offer,
    );
  }

  int? _calculateDiscountPercentage() {
    final double? currentPrice = _parsePrice(price);
    final double? originalPrice = _parsePrice(regularPrice);

    if (currentPrice == null ||
        originalPrice == null ||
        originalPrice <= 0 ||
        currentPrice >= originalPrice) {
      return null;
    }

    final double discount =
        ((originalPrice - currentPrice) / originalPrice) * 100;

    return discount.round();
  }

  double? _parsePrice(String value) {
    final String normalized = value
        .trim()
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAll('٫', '.');

    return double.tryParse(normalized);
  }
}

class _ProductBadgeColors {
  const _ProductBadgeColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}