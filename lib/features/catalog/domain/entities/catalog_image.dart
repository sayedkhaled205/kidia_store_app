class CatalogImage {
  const CatalogImage({
    required this.source,
    this.thumbnail,
    this.name = '',
    this.alt = '',
  });

  final Uri source;
  final Uri? thumbnail;
  Uri get cardSource => thumbnail ?? source;
  final String name;
  final String alt;
}
