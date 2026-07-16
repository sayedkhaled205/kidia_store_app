import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/brands/data/datasources/brands_remote_data_source.dart';
import 'package:kidia_store_app/features/brands/data/repositories/brands_repository_impl.dart';
import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';
import 'package:kidia_store_app/features/brands/domain/repositories/brands_repository.dart';

void main() {
  test(
    'parses brands, pagination headers and skips malformed records',
    () async {
      final _FakeStoreApiClient client = _FakeStoreApiClient(
        response: const StoreApiResponse(
          data: <dynamic>[
            <String, dynamic>{
              'id': 12,
              'name': 'Nike',
              'slug': 'nike',
              'count': 8,
              'image': <String, dynamic>{
                'src': 'https://store.example/nike.png',
              },
            },
            <String, dynamic>{'id': 0, 'name': 'Broken', 'slug': ''},
            'invalid',
          ],
          headers: <String, List<String>>{
            'x-wp-total': <String>['5'],
            'x-wp-totalpages': <String>['2'],
          },
        ),
      );
      final StoreApiBrandsRemoteDataSource source =
          StoreApiBrandsRemoteDataSource(client);

      final StoreBrandPage page = await source.fetchBrands(
        page: 1,
        perPage: 3,
        search: ' ni ',
      );

      expect(page.items.single.name, 'Nike');
      expect(page.items.single.image?.host, 'store.example');
      expect(page.discardedItems, 2);
      expect(page.totalItems, 5);
      expect(page.totalPages, 2);
      expect(page.hasNextPage, isTrue);
      expect(client.lastPath, StoreApiBrandsRemoteDataSource.endpoint);
      expect(client.lastQuery?['search'], 'ni');
    },
  );

  test('maps a missing Store API route to unsupported', () async {
    final _FakeStoreApiClient client = _FakeStoreApiClient(
      error: const StoreApiException(
        kind: StoreApiFailureKind.notFound,
        message: 'Not found',
        statusCode: 404,
      ),
    );
    final BrandsRepository repository = BrandsRepositoryImpl(
      StoreApiBrandsRemoteDataSource(client),
    );

    await expectLater(
      repository.getBrands(page: 1, perPage: 20, search: ''),
      throwsA(isA<BrandsUnsupportedException>()),
    );
  });
}

class _FakeStoreApiClient implements StoreApiClient {
  _FakeStoreApiClient({this.response, this.error});

  final StoreApiResponse? response;
  final Object? error;
  String? lastPath;
  Map<String, dynamic>? lastQuery;

  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    lastPath = path;
    lastQuery = queryParameters;
    if (error != null) {
      throw error!;
    }
    return response!;
  }
}
