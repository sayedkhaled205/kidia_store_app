class CatalogImage {
  const CatalogImage({
    required this.source,
    this.thumbnail,
    this.cardVariant,
    this.name = '',
    this.alt = '',
  });

  final Uri source;
  final Uri? thumbnail;
  final Uri? cardVariant;
  // Only use an explicitly supplied high-resolution variant for cards.
  // Product details keep the original; small thumbnails are never promoted.
  Uri get cardSource => cardVariant ?? source;
  final String name;
  final String alt;
}
