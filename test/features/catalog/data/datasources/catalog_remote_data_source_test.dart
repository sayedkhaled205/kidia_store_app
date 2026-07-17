import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';

void main() {
  group('StoreApiCatalogRemoteDataSource', () {
    test(
      'parses product pagination headers and discards only invalid records',
      () async {
        final _FakeStoreApiClient client = _FakeStoreApiClient(
          response: const StoreApiResponse(
            data: <dynamic>[
              <String, dynamic>{
                'id': 1,
                'name': 'Valid product',
                'prices': <String, dynamic>{'price': '1000'},
              },
              <String, dynamic>{'id': 0},
              'not-an-object',
            ],
            headers: <String, List<String>>{
              'x-wp-total': <String>['23'],
              'x-wp-totalpages': <String>['3'],
            },
          ),
        );
        final StoreApiCatalogRemoteDataSource source =
            StoreApiCatalogRemoteDataSource(client);

        final page = await source.fetchProducts(
          CatalogProductQuery(page: 2, perPage: 10),
        );

        expect(page.items.single.id, 1);
        expect(page.page, 2);
        expect(page.perPage, 10);
        expect(page.totalItems, 23);
        expect(page.totalPages, 3);
        expect(page.discardedItems, 2);
        expect(page.hasNextPage, isTrue);
        expect(client.lastPath, '/wp-json/wc/store/v1/products');
        expect(client.lastQuery?['page'], 2);
      },
    );

    test('parses categories from the CMS category page builder', () async {
      final _FakeStoreApiClient client = _FakeStoreApiClient(
        response: const StoreApiResponse(
          data: <dynamic>[
            <String, dynamic>{
              'id': 4,
              'name': 'Accessories',
              'slug': 'accessories',
            },
          ],
        ),
      );
      final StoreApiCatalogRemoteDataSource source =
          StoreApiCatalogRemoteDataSource(client);

      final page = await source.fetchCategories(CatalogCategoryQuery());

      expect(page.items.single.slug, 'accessories');
      expect(client.lastPath, '/wp-json/woo-mobile/v1/category-page');
      expect(client.lastQuery?['per_page'], 100);
    });

    test('falls back to WooCommerce categories without the plugin', () async {
      final _FallbackCategoryClient client = _FallbackCategoryClient();
      final StoreApiCatalogRemoteDataSource source =
          StoreApiCatalogRemoteDataSource(client);

      final page = await source.fetchCategories(CatalogCategoryQuery());

      expect(page.items.single.id, 8);
      expect(client.paths, <String>[
        '/wp-json/woo-mobile/v1/category-page',
        '/wp-json/wc/store/v1/products/categories',
      ]);
    });

    test(
      'requests collection filter data without pagination parameters',
      () async {
        final _FakeStoreApiClient client = _FakeStoreApiClient(
          response: const StoreApiResponse(
            data: <String, dynamic>{
              'price_range': <String, dynamic>{
                'min_price': '500',
                'max_price': '9000',
              },
              'rating_counts': <dynamic>[
                <String, dynamic>{'rating': 5, 'count': 12},
              ],
            },
          ),
        );
        final StoreApiCatalogRemoteDataSource source =
            StoreApiCatalogRemoteDataSource(client);

        final filters = await source.fetchFilterData(
          CatalogProductQuery(page: 3, perPage: 5, categoryIds: <int>[2]),
          attributeTaxonomies: <String>['pa_size', 'pa_color'],
        );

        expect(filters.minimumPriceMinor, '500');
        expect(filters.maximumPriceMinor, '9000');
        expect(filters.ratingCounts.single.count, 12);
        expect(client.lastQuery?.containsKey('page'), isFalse);
        expect(client.lastQuery?.containsKey('per_page'), isFalse);
        expect(client.lastQuery?['category'], '2');
        expect(client.lastQuery?['calculate_price_range'], isTrue);
        expect(
          client.lastQuery?['calculate_attribute_counts[0][taxonomy]'],
          'pa_size',
        );
        expect(
          client.lastQuery?['calculate_attribute_counts[1][taxonomy]'],
          'pa_color',
        );
      },
    );

    test(
      'hydrates exact purchasable variation data from the mobile bridge',
      () async {
        final _QueueStoreApiClient client = _QueueStoreApiClient(
          <StoreApiResponse>[
            const StoreApiResponse(
              data: <dynamic>[
                <String, dynamic>{
                  'id': 501,
                  'attributes': <dynamic>[
                    <String, dynamic>{
                      'name': 'Size',
                      'taxonomy': 'pa_size',
                      'value': 'm',
                    },
                  ],
                  'is_purchasable': true,
                  'is_in_stock': false,
                  'prices': <String, dynamic>{
                    'currency_code': 'USD',
                    'currency_minor_unit': 2,
                    'price': '1250',
                  },
                },
              ],
            ),
          ],
        );
        final StoreApiCatalogRemoteDataSource source =
            StoreApiCatalogRemoteDataSource(client);

        final variations = await source.fetchVariations(50);

        expect(variations.single.id, 501);
        expect(variations.single.attributes.single.value, 'm');
        expect(variations.single.prices?.priceMinor, '1250');
        expect(variations.single.isPurchasable, isTrue);
        expect(variations.single.isInStock, isFalse);
        expect(
          client.paths.single,
          '/wp-json/woo-mobile/v1/products/50/variations',
        );
      },
    );
  });
}

class _FakeStoreApiClient implements StoreApiClient {
  _FakeStoreApiClient({required this.response});

  final StoreApiResponse response;
  String? lastPath;
  Map<String, dynamic>? lastQuery;

  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    lastPath = path;
    lastQuery = queryParameters == null
        ? null
        : Map<String, dynamic>.from(queryParameters);
    return response;
  }
}

class _QueueStoreApiClient implements StoreApiClient {
  _QueueStoreApiClient(this._responses);

  final List<StoreApiResponse> _responses;
  final List<Map<String, dynamic>> queries = <Map<String, dynamic>>[];
  final List<String> paths = <String>[];
  int _index = 0;

  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    paths.add(path);
    queries.add(Map<String, dynamic>.from(queryParameters ?? const {}));
    if (_index >= _responses.length) {
      throw StateError('No fake Store API response is available.');
    }
    return _responses[_index++];
  }
}

class _FallbackCategoryClient implements StoreApiClient {
  final List<String> paths = <String>[];

  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    paths.add(path);
    if (path == '/wp-json/woo-mobile/v1/category-page') {
      throw StateError('Plugin endpoint is unavailable.');
    }
    return const StoreApiResponse(
      data: <dynamic>[
        <String, dynamic>{'id': 8, 'name': 'Fallback', 'slug': 'fallback'},
      ],
    );
  }
}
