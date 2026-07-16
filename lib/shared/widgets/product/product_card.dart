import 'package:flutter/material.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';
import 'package:kidia_store_app/shared/widgets/product/product_badge.dart';
import 'package:kidia_store_app/shared/widgets/product/product_price.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.currencySymbol,
    required this.inStock,
    super.key,
    this.regularPrice,
    this.badgeLabel,
    this.badgeType = ProductBadgeType.custom,
    this.semanticLabel,
    this.isFavorite = false,
    this.onTap,
    this.onFavoritePressed,
    this.imageAspectRatio = 1,
    this.compact = false,
  });

  final String name;
  final String imageUrl;
  final String price;
  final String? regularPrice;
  final String currencySymbol;
  final bool inStock;

  final String? badgeLabel;
  final ProductBadgeType badgeType;
  final String? semanticLabel;

  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoritePressed;

  final double imageAspectRatio;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Semantics(
      button: onTap != null,
      label: semanticLabel ?? name,
      child: Material(
        color: colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ProductImageSection(
                  imageUrl: imageUrl,
                  productName: name,
                  inStock: inStock,
                  badgeLabel: badgeLabel,
                  badgeType: badgeType,
                  isFavorite: isFavorite,
                  onFavoritePressed: onFavoritePressed,
                  imageAspectRatio: imageAspectRatio,
                ),
              ),
              _ProductInformation(
                name: name,
                price: price,
                regularPrice: regularPrice,
                currencySymbol: currencySymbol,
                inStock: inStock,
                compact: compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImageSection extends StatelessWidget {
  const _ProductImageSection({
    required this.imageUrl,
    required this.productName,
    required this.inStock,
    required this.badgeLabel,
    required this.badgeType,
    required this.isFavorite,
    required this.onFavoritePressed,
    required this.imageAspectRatio,
  });

  final String imageUrl;
  final String productName;
  final bool inStock;
  final String? badgeLabel;
  final ProductBadgeType badgeType;
  final bool isFavorite;
  final VoidCallback? onFavoritePressed;
  final double imageAspectRatio;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: imageAspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            semanticLabel: productName,
          ),
          if (!inStock)
            ColoredBox(
              color: colorScheme.surface.withValues(
                alpha: 0.68,
              ),
            ),
          PositionedDirectional(
            top: 10,
            start: 10,
            child: _ProductStatusBadge(
              inStock: inStock,
              badgeLabel: badgeLabel,
              badgeType: badgeType,
            ),
          ),
          if (onFavoritePressed != null)
            PositionedDirectional(
              top: 8,
              end: 8,
              child: _FavoriteButton(
                isFavorite: isFavorite,
                onPressed: onFavoritePressed!,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductStatusBadge extends StatelessWidget {
  const _ProductStatusBadge({
    required this.inStock,
    required this.badgeLabel,
    required this.badgeType,
  });

  final bool inStock;
  final String? badgeLabel;
  final ProductBadgeType badgeType;

  @override
  Widget build(BuildContext context) {
    if (!inStock) {
      return const ProductBadge(
        label: 'نفد المخزون',
        type: ProductBadgeType.outOfStock,
      );
    }

    final String? normalizedLabel = badgeLabel?.trim();

    if (normalizedLabel == null || normalizedLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    return ProductBadge(
      label: normalizedLabel,
      type: badgeType,
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: isFavorite,
      label: isFavorite
          ? 'إزالة المنتج من المفضلة'
          : 'إضافة المنتج إلى المفضلة',
      child: Material(
        color: colorScheme.surface.withValues(
          alpha: 0.92,
        ),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: isFavorite
              ? 'إزالة من المفضلة'
              : 'إضافة إلى المفضلة',
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (
                Widget child,
                Animation<double> animation,
                ) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              key: ValueKey<bool>(isFavorite),
              color: isFavorite
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductInformation extends StatelessWidget {
  const _ProductInformation({
    required this.name,
    required this.price,
    required this.regularPrice,
    required this.currencySymbol,
    required this.inStock,
    required this.compact,
  });

  final String name;
  final String price;
  final String? regularPrice;
  final String currencySymbol;
  final bool inStock;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 8 : 10,
        compact ? 10 : 12,
        compact ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: inStock
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          ProductPrice(
            price: price,
            regularPrice: regularPrice,
            currencySymbol: currencySymbol,
            compact: compact,
          ),
        ],
      ),
    );
  }
}
