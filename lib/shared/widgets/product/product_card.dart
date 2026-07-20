import 'package:flutter/material.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';
import 'package:kidia_store_app/shared/widgets/product/product_badge.dart';
import 'package:kidia_store_app/shared/widgets/product/product_price.dart';
import 'package:kidia_store_app/features/product/presentation/widgets/product_quick_add.dart';

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
    this.cardRadius = 20,
    this.showBorder = true,
    this.elevation = 0,
    this.showName = true,
    this.showPrice = true,
    this.showRegularPrice = true,
    this.showBadge = true,
    this.showRating = false,
    this.rating = 0,
    this.reviewCount = 0,
    this.quickAddProductId,
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
  final double cardRadius;
  final bool showBorder;
  final double elevation;
  final bool showName;
  final bool showPrice;
  final bool showRegularPrice;
  final bool showBadge;
  final bool showRating;
  final double rating;
  final int reviewCount;
  final int? quickAddProductId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Semantics(
      button: onTap != null,
      label: semanticLabel ?? name,
      child: Material(
        color: colorScheme.surfaceContainerLowest,
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: showBorder
              ? BorderSide(color: colorScheme.outlineVariant)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductImageSection(
                imageUrl: imageUrl,
                productName: name,
                inStock: inStock,
                badgeLabel: badgeLabel,
                badgeType: badgeType,
                isFavorite: isFavorite,
                onFavoritePressed: onFavoritePressed,
                imageAspectRatio: imageAspectRatio,
                showBadge: showBadge,
                quickAddProductId: quickAddProductId,
              ),
              _ProductInformation(
                name: name,
                price: price,
                regularPrice: regularPrice,
                currencySymbol: currencySymbol,
                inStock: inStock,
                compact: compact,
                showName: showName,
                showPrice: showPrice,
                showRegularPrice: showRegularPrice,
                showRating: showRating,
                rating: rating,
                reviewCount: reviewCount,
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
    required this.showBadge,
    required this.quickAddProductId,
  });

  final String imageUrl;
  final String productName;
  final bool inStock;
  final String? badgeLabel;
  final ProductBadgeType badgeType;
  final bool isFavorite;
  final VoidCallback? onFavoritePressed;
  final double imageAspectRatio;
  final bool showBadge;
  final int? quickAddProductId;

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
          if (showBadge)
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
          if (quickAddProductId != null && inStock)
            PositionedDirectional(
              end: 8,
              bottom: 8,
              child: ProductQuickAddButton(productId: quickAddProductId!),
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
    required this.showName,
    required this.showPrice,
    required this.showRegularPrice,
    required this.showRating,
    required this.rating,
    required this.reviewCount,
  });

  final String name;
  final String price;
  final String? regularPrice;
  final String currencySymbol;
  final bool inStock;
  final bool compact;
  final bool showName;
  final bool showPrice;
  final bool showRegularPrice;
  final bool showRating;
  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    if (!showName && !showPrice && !showRating) {
      return const SizedBox.shrink();
    }

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
          if (showName)
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
          if (showRating && rating > 0) ...<Widget>[
            SizedBox(height: compact ? 4 : 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: Color(0xFFFFB300),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    rating.toStringAsFixed(1),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (reviewCount > 0)
                    Text(
                      ' ($reviewCount)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (showPrice) ...<Widget>[
            SizedBox(height: compact ? 6 : 8),
            ProductPrice(
              price: price,
              regularPrice: showRegularPrice ? regularPrice : null,
              currencySymbol: currencySymbol,
              compact: compact,
            ),
          ],
        ],
      ),
    );
  }
}
