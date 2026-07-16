import 'package:flutter/material.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/presentation/catalog_copy.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';

class CatalogProductCard extends StatelessWidget {
  const CatalogProductCard({
    required this.product,
    required this.onTap,
    super.key,
  });

  final CatalogProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final CatalogCopy copy = CatalogCopy.of(context);
    final String? imageUrl =
        product.primaryImage?.thumbnail?.toString() ??
        product.primaryImage?.source.toString();
    final String currentPrice = product.prices.displayAmount(
      product.prices.priceMinor,
    );
    final String regularPrice = product.prices.displayAmount(
      product.prices.regularPriceMinor,
    );

    return Semantics(
      button: true,
      label: '${product.name}, $currentPrice',
      child: Material(
        color: colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.outlineVariant),
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (imageUrl == null || imageUrl.isEmpty)
                        const AppNetworkImageError()
                      else
                        Padding(
                          padding: EdgeInsets.zero,
                          child: AppNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            semanticLabel:
                                product.primaryImage?.alt.isNotEmpty == true
                                ? product.primaryImage!.alt
                                : product.name,
                          ),
                        ),
                    if (!product.isInStock)
                      ColoredBox(color: colors.surface.withValues(alpha: 0.68)),
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
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(9, 5, 9, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (product.averageRating > 0)
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
                        if (product.prices.isDiscounted &&
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
