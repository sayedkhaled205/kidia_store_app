import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/core/network/public_catalog_cache.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';

class Reader implements StoreApiClient {
  int calls = 0;
  Future<StoreApiResponse> Function() read = () async => const StoreApiResponse(
    data: [
      {'id': 7},
    ],
    statusCode: 200,
  );
  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    calls++;
    return read();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const path = '/wp-json/wc/store/v1/products';
  const offline = StoreApiException(
    kind: StoreApiFailureKind.connection,
    message: 'offline',
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'published catalog invalidation fetches fresh data and cache-busters do not duplicate entries',
    () async {
      final reader = Reader();
      final cache = PublicCatalogCache(reader, store: 'store');
      await cache.get(path, queryParameters: {'_mobile_cache_bust': 1});
      reader.read = () async => const StoreApiResponse(
        data: [
          {'id': 9},
        ],
        statusCode: 200,
      );
      cache.invalidate();
      expect(
        (await cache.get(
          path,
          queryParameters: {'_mobile_cache_bust': 2},
        )).data,
        [
          {'id': 9},
        ],
      );
      expect(reader.calls, 2);
      reader.read = () async => throw offline;
      cache.invalidate();
      expect((await cache.get(path)).data, [
        {'id': 9},
      ]);
      const gone = StoreApiException(
        kind: StoreApiFailureKind.notFound,
        message: 'gone',
      );
      reader.read = () async => throw gone;
      cache.invalidate();
      await expectLater(cache.get(path), throwsA(same(gone)));
    },
  );

  test(
    'cold read coalesces and persisted catalog opens immediately after restart offline',
    () async {
      final reader = Reader();
      final first = PublicCatalogCache(reader, store: 'https://one.example');
      await Future.wait([first.get(path), first.get(path)]);
      expect(reader.calls, 1);
      final wait = Completer<StoreApiResponse>();
      reader.read = () => wait.future;
      final restarted = PublicCatalogCache(
        reader,
        store: 'https://one.example',
      );
      final response = await restarted
          .get(path)
          .timeout(const Duration(seconds: 1));
      expect(response.data, [
        {'id': 7},
      ]);
      expect(reader.calls, 2);
      wait.completeError(offline);
      await Future<void>.delayed(Duration.zero);
      expect((await restarted.get(path)).data, response.data);
      expect(reader.calls, 2);
    },
  );

  test(
    'store, search, filters and locale stay isolated; recovery updates cached data',
    () async {
      final reader = Reader();
      var now = DateTime(2026);
      final cache = PublicCatalogCache(
        reader,
        store: 'https://one.example',
        now: () => now,
      );
      await cache.get(path, queryParameters: {'search': 'bath'});
      reader.read = () async => throw offline;
      await expectLater(
        cache.get(path, queryParameters: {'search': 'toy'}),
        throwsA(same(offline)),
      );
      await expectLater(
        PublicCatalogCache(
          reader,
          store: 'https://two.example',
        ).get(path, queryParameters: {'search': 'bath'}),
        throwsA(same(offline)),
      );
      now = now.add(const Duration(minutes: 2));
      reader.read = () async => const StoreApiResponse(
        data: [
          {'id': 8},
        ],
        statusCode: 200,
      );
      expect(
        (await cache.get(path, queryParameters: {'search': 'bath'})).data,
        [
          {'id': 7},
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        (await cache.get(path, queryParameters: {'search': 'bath'})).data,
        [
          {'id': 8},
        ],
      );
    },
  );

  test(
    'private operations are never cached; expired browsing data is not reused',
    () async {
      final reader = Reader();
      var now = DateTime(2026);
      final cache = PublicCatalogCache(
        reader,
        store: 'https://one.example',
        now: () => now,
      );
      for (final private in [
        '/wp-json/wc/store/v1/cart',
        '/wp-json/wc/store/v1/checkout',
        '/wp-json/mobishop/v1/customer',
      ]) {
        await cache.get(private);
        await cache.get(private);
      }
      expect(reader.calls, 6);
      await cache.get(path);
      now = now.add(const Duration(days: 8));
      reader.read = () async => throw offline;
      await expectLater(cache.get(path), throwsA(same(offline)));
    },
  );

  test(
    'background authorization or removed resource evicts its cached copy',
    () async {
      final reader = Reader();
      await PublicCatalogCache(reader, store: 'store').get(path);
      const gone = StoreApiException(
        kind: StoreApiFailureKind.notFound,
        message: 'gone',
      );
      reader.read = () async => throw gone;
      final cache = PublicCatalogCache(reader, store: 'store');
      await cache.get(path);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await expectLater(cache.get(path), throwsA(same(gone)));
    },
  );
}
