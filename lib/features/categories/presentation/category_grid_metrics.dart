import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';

int compactCategoryColumns(
  CatalogCategory settings,
  Iterable<CatalogCategory> categories,
  double availableWidth,
  double textScale,
) {
  // Keep the image, label and expand action usable instead of squeezing four
  // horizontal tiles into a phone. Wider screens retain the saved column count.
  final minimumWidth = categories.fold<double>(0, (width, category) {
    final required =
        15 +
        category.imageSize.clamp(32, 54) +
        category.imageTextGap +
        (category.showArrow ? 48 : 0) +
        (category.nameHighlightEnabled ? 16 : 0) +
        category.fontSize * 2 * textScale;
    return required > width ? required : width;
  });
  final cellWidth =
      minimumWidth / (settings.cardWidthPercent / 100).clamp(.1, 1);
  return ((availableWidth + settings.cardGap) / (cellWidth + settings.cardGap))
      .floor()
      .clamp(1, settings.gridColumns.clamp(2, 4));
}

double categoryGridExtent(CatalogCategory settings, String layout) {
  if (settings.cardHeight > 0) return settings.cardHeight;
  final compact = layout == 'compact_grid';
  final imageLimit = compact
      ? 54.0
      : layout == 'circular_grid'
      ? 82.0
      : 118.0;
  final imageHeight = settings.imageSize.clamp(32.0, imageLimit);
  final textHeight =
      settings.fontSize * settings.lineHeight * settings.textMaxLines +
      (settings.nameHighlightEnabled ? 12 : 0);
  // Compact cards place the image beside the text; other grids stack them.
  final contentHeight = compact
      ? (imageHeight > textHeight ? imageHeight : textHeight) + 14
      : imageHeight + settings.imageTextGap + textHeight + 24;
  return contentHeight.clamp(82.0, double.infinity).toDouble();
}
