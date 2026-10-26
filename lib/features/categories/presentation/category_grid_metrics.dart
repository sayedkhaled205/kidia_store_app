import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';

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
