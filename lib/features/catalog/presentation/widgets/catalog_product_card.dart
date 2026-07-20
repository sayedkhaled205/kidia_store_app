import 'package:flutter/material.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/presentation/catalog_copy.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/product/presentation/widgets/product_quick_add.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';

class CatalogProductCard extends StatelessWidget {
  const CatalogProductCard({
    required this.product,
    required this.onTap,
    this.settings,
    super.key,
  });

  final CatalogProduct product;
  final VoidCallback onTap;
  final CmsPageComponent? settings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final CatalogCopy copy = CatalogCopy.of(context);
    final String? imageUrl =
        product.primaryImage?.source.toString() ??
        product.primaryImage?.thumbnail?.toString();
    final String currentPrice = product.prices.displayAmount(
      product.prices.priceMinor,
    );
    final String regularPrice = product.prices.displayAmount(
      product.prices.regularPriceMinor,
    );
    final String cardStyle =
        settings?.string('card_style', 'outlined') ?? 'outlined';
    final double cardRadius = settings == null
        ? 14
        : settings!.number('card_radius', 14).clamp(0, 40).toDouble();
    final double imageRatio = settings == null
        ? 1
        : settings!.number('image_ratio', 1).clamp(0.6, 1.8).toDouble();
    final bool showName = settings?.boolean('show_name', true) ?? true;
    final bool showPrice = settings?.boolean('show_price', true) ?? true;
    final bool showRegularPrice =
        settings?.boolean('show_regular_price', true) ?? true;
    final bool showRating = settings?.boolean('show_rating', true) ?? true;
    final bool showBadge = settings?.boolean('show_badge', true) ?? true;

    return Semantics(
      button: true,
      label: '${product.name}, $currentPrice',
      child: Material(
        color: colors.surfaceContainerLowest,
        elevation: cardStyle == 'elevated' ? 3 : 0,
        shadowColor: cardStyle == 'elevated'
            ? colors.shadow
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: cardStyle == 'outlined'
              ? BorderSide(color: colors.outlineVariant)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ColoredBox(
                  color: colors.surface,
                  child: AspectRatio(
                    aspectRatio: imageRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (imageUrl == null || imageUrl.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(5),
                            child: AppNetworkImageError(),
                          )
                        else
                          Center(
                            child: FractionallySizedBox(
                              widthFactor: 0.95,
                              heightFactor: 0.95,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AppNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  semanticLabel:
                                      product.primaryImage?.alt.isNotEmpty ==
                                          true
                                      ? product.primaryImage!.alt
                                      : product.name,
                                ),
                              ),
                            ),
                          ),
                        if (!product.isInStock)
                          ColoredBox(
                            color: colors.surface.withValues(alpha: 0.68),
                          ),
                        if (showBadge)
                          PositionedDirectional(
                            start: 8,
                            top: 8,
                            child: _ProductBadge(
                              label: !product.isInStock
                                  ? copy.outOfStock
                                  : product.isOnSale
                                  ? copy.sale
                                  : '',
                              isError: !product.isInStock,
                            ),
                          ),
                        if (product.isInStock)
                          PositionedDirectional(
                            end: 8,
                            bottom: 8,
                            child: ProductQuickAddButton(
                              productId: product.id,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(9, 5, 9, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (showName)
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    if (showName) const SizedBox(height: 5),
                    if (showRating && product.averageRating > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: colors.tertiary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              product.averageRating.toStringAsFixed(1),
                              style: theme.textTheme.labelSmall,
                            ),
                            if (product.reviewCount > 0)
                              Text(
                                ' (${product.reviewCount})',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (showPrice)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              currentPrice.isEmpty ? '—' : currentPrice,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (showRegularPrice &&
                              product.prices.isDiscounted &&
                              regularPrice.isNotEmpty)
                            Flexible(
                              child: Text(
                                regularPrice,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductBadge extends StatelessWidget {
  const _ProductBadge({required this.label, required this.isError});

  final String label;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = isError
        ? colors.errorContainer
        : colors.primaryContainer;
    final Color foreground = isError
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
