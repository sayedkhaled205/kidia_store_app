import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/features/brands/data/models/store_brand_model.dart';
import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';

abstract interface class BrandsRemoteDataSource {
  Future<StoreBrandPage> fetchBrands({
    required int page,
    required int perPage,
    required String search,
  });
}

class StoreApiBrandsRemoteDataSource implements BrandsRemoteDataSource {
  const StoreApiBrandsRemoteDataSource(this._client);

  static const String endpoint = '/wp-json/wc/store/v1/products/brands';

  final StoreApiClient _client;

  @override
  Future<StoreBrandPage> fetchBrands({
    required int page,
    required int perPage,
    required String search,
  }) async {
    final int safePage = page < 1 ? 1 : page;
    final int safePerPage = perPage.clamp(1, 100);
    final String query = search.trim();
    final StoreApiResponse response = await _client.get(
      endpoint,
      queryParameters: <String, dynamic>{
        'page': safePage,
        'per_page': safePerPage,
        'hide_empty': true,
        'orderby': 'name',
        'order': 'asc',
        if (query.isNotEmpty) 'search': query,
      },
    );

    if (response.data is! List) {
      throw const FormatException('The brands response must be an array.');
    }

    final List<StoreBrand> brands = <StoreBrand>[];
    int discarded = 0;
    for (final dynamic rawBrand in response.data as List<dynamic>) {
      if (rawBrand is! Map) {
        discarded++;
        continue;
      }
      try {
        brands.add(
          StoreBrandModel.fromJson(
            Map<String, dynamic>.from(rawBrand),
          ).toEntity(),
        );
      } on FormatException {
        discarded++;
      }
    }

    final int totalItems =
        _headerInt(response, 'x-wp-total') ?? brands.length + discarded;
    final int fallbackPages = totalItems == 0
        ? 0
        : (totalItems + safePerPage - 1) ~/ safePerPage;
    final int totalPages =
        _headerInt(response, 'x-wp-totalpages') ?? fallbackPages;

    return StoreBrandPage(
      items: List<StoreBrand>.unmodifiable(brands),
      page: safePage,
      perPage: safePerPage,
      totalItems: totalItems < 0 ? 0 : totalItems,
      totalPages: totalPages < 0 ? 0 : totalPages,
      discardedItems: discarded,
    );
  }

  int? _headerInt(StoreApiResponse response, String name) {
    final int? parsed = int.tryParse(response.header(name) ?? '');
    return parsed == null || parsed < 0 ? null : parsed;
  }
}
