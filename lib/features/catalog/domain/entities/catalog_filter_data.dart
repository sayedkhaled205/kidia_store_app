import 'catalog_filter_options.dart';

class CatalogFilterData {
  const CatalogFilterData({
    this.minimumPriceMinor = '',
    this.maximumPriceMinor = '',
    this.attributeCounts = const <CatalogAttributeCount>[],
    this.ratingCounts = const <CatalogRatingCount>[],
    this.stockCounts = const <CatalogStockCount>[],
    this.availableSizes,
  });

  final String minimumPriceMinor;
  final String maximumPriceMinor;
  final List<CatalogAttributeCount> attributeCounts;
  final List<CatalogRatingCount> ratingCounts;
  final List<CatalogStockCount> stockCounts;

  /// Null means the store does not support stock-aware size facets.
  /// An empty list is authoritative and must not be filled from parent terms.
  final List<CatalogSizeOption>? availableSizes;
}

class CatalogAttributeCount {
  const CatalogAttributeCount({required this.termId, required this.count});

  final int termId;
  final int count;
}

class CatalogRatingCount {
  const CatalogRatingCount({required this.rating, required this.count});

  final int rating;
  final int count;
}

class CatalogStockCount {
  const CatalogStockCount({required this.status, required this.count});

  final String status;
  final int count;
}
