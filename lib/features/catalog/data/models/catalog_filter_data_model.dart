import 'package:kidia_store_app/features/catalog/data/models/catalog_json.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_filter_data.dart';

class CatalogFilterDataModel extends CatalogFilterData {
  const CatalogFilterDataModel({
    super.minimumPriceMinor,
    super.maximumPriceMinor,
    super.attributeCounts,
    super.ratingCounts,
    super.stockCounts,
  });

  factory CatalogFilterDataModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> priceRange =
        CatalogJson.object(json['price_range']) ?? const <String, dynamic>{};

    return CatalogFilterDataModel(
      minimumPriceMinor: CatalogJson.minorAmount(priceRange['min_price']),
      maximumPriceMinor: CatalogJson.minorAmount(priceRange['max_price']),
      attributeCounts: _attributeCounts(json['attribute_counts']),
      ratingCounts: _ratingCounts(json['rating_counts']),
      stockCounts: _stockCounts(json['stock_status_counts']),
    );
  }

  CatalogFilterData toEntity() {
    return CatalogFilterData(
      minimumPriceMinor: minimumPriceMinor,
      maximumPriceMinor: maximumPriceMinor,
      attributeCounts: attributeCounts,
      ratingCounts: ratingCounts,
      stockCounts: stockCounts,
    );
  }

  static List<CatalogAttributeCount> _attributeCounts(dynamic value) {
    final List<CatalogAttributeCount> result = <CatalogAttributeCount>[];
    for (final dynamic rawItem in CatalogJson.list(value)) {
      final Map<String, dynamic>? item = CatalogJson.object(rawItem);
      final int termId = CatalogJson.integer(item?['term']);
      if (termId <= 0) {
        continue;
      }
      result.add(
        CatalogAttributeCount(
          termId: termId,
          count: _nonNegative(item?['count']),
        ),
      );
    }
    return List<CatalogAttributeCount>.unmodifiable(result);
  }

  static List<CatalogRatingCount> _ratingCounts(dynamic value) {
    final List<CatalogRatingCount> result = <CatalogRatingCount>[];
    for (final dynamic rawItem in CatalogJson.list(value)) {
      final Map<String, dynamic>? item = CatalogJson.object(rawItem);
      final int rating = CatalogJson.integer(item?['rating']);
      if (rating < 1 || rating > 5) {
        continue;
      }
      result.add(
        CatalogRatingCount(rating: rating, count: _nonNegative(item?['count'])),
      );
    }
    return List<CatalogRatingCount>.unmodifiable(result);
  }

  static List<CatalogStockCount> _stockCounts(dynamic value) {
    final List<CatalogStockCount> result = <CatalogStockCount>[];
    for (final dynamic rawItem in CatalogJson.list(value)) {
      final Map<String, dynamic>? item = CatalogJson.object(rawItem);
      final String status = CatalogJson.string(item?['status']);
      if (status.isEmpty) {
        continue;
      }
      result.add(
        CatalogStockCount(status: status, count: _nonNegative(item?['count'])),
      );
    }
    return List<CatalogStockCount>.unmodifiable(result);
  }

  static int _nonNegative(dynamic value) {
    final int parsed = CatalogJson.integer(value);
    return parsed < 0 ? 0 : parsed;
  }
}
