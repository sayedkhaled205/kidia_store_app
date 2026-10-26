class CatalogImage {
  const CatalogImage({
    required this.source,
    this.thumbnail,
    this.name = '',
    this.alt = '',
  });

  final Uri source;
  final Uri? thumbnail;
  // Store thumbnails can be only 150–300px, below a two-column phone card's
  // physical resolution. Keep the supplied full image URL (including CDN args).
  Uri get cardSource => source;
  final String name;
  final String alt;
}
