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
    this.rating = 0,
    this.ratingCount = 0,
    this.showRating = false,
    this.showBadge = true,
    this.showStock = true,
    this.cardStyle = 'standard',
    this.category,
    this.showCategory = false,
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
  final double rating;
  final int ratingCount;
  final bool showRating;
  final bool showBadge;
  final bool showStock;
  final String cardStyle;
  final String? category;
  final bool showCategory;

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
            color: cardStyle == 'outlined'
                ? colorScheme.outline
                : colorScheme.outlineVariant,
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
                  showBadge: showBadge,
                  showStock: showStock,
                ),
              ),
              _ProductInformation(
                name: name,
                price: price,
                regularPrice: regularPrice,
                currencySymbol: currencySymbol,
                inStock: inStock,
                compact: compact,
                rating: rating,
                ratingCount: ratingCount,
                showRating: showRating,
                category: category,
                showCategory: showCategory,
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
    required this.showStock,
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
  final bool showStock;

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
          if (!inStock && showStock)
            ColoredBox(color: colorScheme.surface.withValues(alpha: 0.68)),
          PositionedDirectional(
            top: 10,
            start: 10,
            child: _ProductStatusBadge(
              inStock: inStock,
              badgeLabel: badgeLabel,
              badgeType: badgeType,
              showBadge: showBadge,
              showStock: showStock,
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
    required this.showBadge,
    required this.showStock,
  });

  final bool inStock;
  final String? badgeLabel;
  final ProductBadgeType badgeType;
  final bool showBadge;
  final bool showStock;

  @override
  Widget build(BuildContext context) {
    if (!inStock && showStock) {
      return const ProductBadge(
        label: 'نفد المخزون',
        type: ProductBadgeType.outOfStock,
      );
    }

    if (!showBadge) {
      return const SizedBox.shrink();
    }

    final String? normalizedLabel = badgeLabel?.trim();

    if (normalizedLabel == null || normalizedLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    return ProductBadge(label: normalizedLabel, type: badgeType);
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onPressed});

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
        color: colorScheme.surface.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
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
    required this.rating,
    required this.ratingCount,
    required this.showRating,
    required this.category,
    required this.showCategory,
  });

  final String name;
  final String price;
  final String? regularPrice;
  final String currencySymbol;
  final bool inStock;
  final bool compact;
  final double rating;
  final int ratingCount;
  final bool showRating;
  final String? category;
  final bool showCategory;

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
          if (showCategory && category != null) ...[
            Text(
              category!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
          ],
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
          if (showRating && rating > 0) ...[
            SizedBox(height: compact ? 4 : 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: compact ? 15 : 17,
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 3),
                Text(
                  rating.toStringAsFixed(1),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (ratingCount > 0)
                  Text(
                    ' ($ratingCount)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
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
