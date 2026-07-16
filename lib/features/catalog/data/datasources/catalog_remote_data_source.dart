import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_category_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_filter_data_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_json.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_product_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_variation_model.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';

abstract interface class CatalogRemoteDataSource {
  Future<CatalogPage<CatalogProductModel>> fetchProducts(
    CatalogProductQuery query,
  );

  Future<CatalogProductModel> fetchProduct(int productId);

  Future<List<CatalogVariationModel>> fetchVariations(int productId);

  Future<CatalogPage<CatalogCategoryModel>> fetchCategories(
    CatalogCategoryQuery query,
  );

  Future<CatalogFilterDataModel> fetchFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  });
}

class StoreApiCatalogRemoteDataSource implements CatalogRemoteDataSource {
  const StoreApiCatalogRemoteDataSource(this._client);

  static const String _productsPath = '/wp-json/wc/store/v1/products';
  static const String _categoriesPath =
      '/wp-json/wc/store/v1/products/categories';
  static const String _collectionDataPath =
      '/wp-json/wc/store/v1/products/collection-data';

  final StoreApiClient _client;

  @override
  Future<CatalogPage<CatalogProductModel>> fetchProducts(
    CatalogProductQuery query,
  ) async {
    final StoreApiResponse response = await _client.get(
      _productsPath,
      queryParameters: query.toStoreApiQuery(),
    );

    return _parsePage<CatalogProductModel>(
      response: response,
      requestedPage: query.page,
      requestedPerPage: query.perPage,
      parser: CatalogProductModel.fromJson,
      resourceName: 'products',
    );
  }

  @override
  Future<CatalogProductModel> fetchProduct(int productId) async {
    if (productId <= 0) {
      throw const FormatException('A product id must be positive.');
    }

    final StoreApiResponse response = await _client.get(
      '$_productsPath/$productId',
    );
    final Map<String, dynamic>? json = CatalogJson.object(response.data);
    if (json == null) {
      throw const FormatException(
        'The Store API product response must be an object.',
      );
    }
    return CatalogProductModel.fromJson(json);
  }

  @override
  Future<List<CatalogVariationModel>> fetchVariations(int productId) async {
    final CatalogProductModel parent = await fetchProduct(productId);
    if (parent.variations.isEmpty) {
      return const <CatalogVariationModel>[];
    }

    final Map<int, CatalogProductModel> details = <int, CatalogProductModel>{};
    final List<int> variationIds = parent.variations
        .map((variation) => variation.id)
        .toList(growable: false);

    for (int start = 0; start < variationIds.length; start += 100) {
      final int end = start + 100 < variationIds.length
          ? start + 100
          : variationIds.length;
      final List<int> batch = variationIds.sublist(start, end);
      final CatalogPage<CatalogProductModel> page = await fetchProducts(
        CatalogProductQuery(
          perPage: batch.length,
          includeIds: batch,
          parentIds: <int>[productId],
          productType: CatalogProductType.variation,
          sort: CatalogSort.includeOrder,
        ),
      );
      for (final CatalogProductModel detail in page.items) {
        details[detail.id] = detail;
      }
    }

    return List<CatalogVariationModel>.unmodifiable(
      parent.variations.map((variation) {
        final CatalogProductModel? detail = details[variation.id];
        return CatalogVariationModel(
          id: variation.id,
          attributes: variation.attributes,
          isPurchasable: detail?.isPurchasable ?? variation.isPurchasable,
          isInStock: detail?.isInStock ?? variation.isInStock,
          prices: detail?.prices ?? variation.prices,
          image: detail?.primaryImage ?? variation.image,
        );
      }),
    );
  }

  @override
  Future<CatalogPage<CatalogCategoryModel>> fetchCategories(
    CatalogCategoryQuery query,
  ) async {
    final StoreApiResponse response = await _client.get(
      _categoriesPath,
      queryParameters: query.toStoreApiQuery(),
    );

    return _parsePage<CatalogCategoryModel>(
      response: response,
      requestedPage: query.page,
      requestedPerPage: query.perPage,
      parser: CatalogCategoryModel.fromJson,
      resourceName: 'categories',
    );
  }

  @override
  Future<CatalogFilterDataModel> fetchFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  }) async {
    final List<String> requestedTaxonomies = attributeTaxonomies
        .map((String taxonomy) => taxonomy.trim())
        .where((String taxonomy) => taxonomy.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final Map<String, dynamic> parameters = query.toStoreApiQuery()
      ..remove('page')
      ..remove('per_page')
      ..remove('orderby')
      ..remove('order')
      ..addAll(const <String, dynamic>{
        'calculate_price_range': true,
        'calculate_rating_counts': true,
        'calculate_stock_status_counts': true,
      });
    for (int index = 0; index < requestedTaxonomies.length; index++) {
      parameters['calculate_attribute_counts[$index][taxonomy]'] =
          requestedTaxonomies[index];
      parameters['calculate_attribute_counts[$index][query_type]'] = 'or';
    }

    final StoreApiResponse response = await _client.get(
      _collectionDataPath,
      queryParameters: parameters,
    );
    final Map<String, dynamic>? json = CatalogJson.object(response.data);
    if (json == null) {
      throw const FormatException(
        'The Store API collection response must be an object.',
      );
    }
    return CatalogFilterDataModel.fromJson(json);
  }

  CatalogPage<T> _parsePage<T>({
    required StoreApiResponse response,
    required int requestedPage,
    required int requestedPerPage,
    required T Function(Map<String, dynamic> json) parser,
    required String resourceName,
  }) {
    if (response.data is! List) {
      throw FormatException(
        'The Store API $resourceName response must be an array.',
      );
    }

    final List<T> items = <T>[];
    int discardedItems = 0;
    for (final dynamic rawItem in response.data as List<dynamic>) {
      final Map<String, dynamic>? item = CatalogJson.object(rawItem);
      if (item == null) {
        discardedItems++;
        continue;
      }

      try {
        items.add(parser(item));
      } on FormatException {
        discardedItems++;
      }
    }

    final int totalItems =
        _headerInt(response, 'x-wp-total') ?? items.length + discardedItems;
    final int fallbackPages = totalItems == 0
        ? 0
        : ((totalItems + requestedPerPage - 1) ~/ requestedPerPage);
    final int totalPages =
        _headerInt(response, 'x-wp-totalpages') ?? fallbackPages;

    return CatalogPage<T>(
      items: List<T>.unmodifiable(items),
      page: requestedPage,
      perPage: requestedPerPage,
      totalItems: totalItems < 0 ? 0 : totalItems,
      totalPages: totalPages < 0 ? 0 : totalPages,
      discardedItems: discardedItems,
    );
  }

  int? _headerInt(StoreApiResponse response, String name) {
    final int? value = int.tryParse(response.header(name) ?? '');
    return value == null || value < 0 ? null : value;
  }
}
