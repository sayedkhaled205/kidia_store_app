import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/core/network/public_catalog_cache.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';

class Reader implements StoreApiClient {
  int calls = 0;
  Future<StoreApiResponse> Function() read;
  Reader(this.read);
  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    calls++;
    return read();
  }
}

const path = '/wp-json/wc/store/v1/products';
const oldData = StoreApiResponse(
  data: [
    {'id': 1},
  ],
  statusCode: 200,
);
const newData = StoreApiResponse(
  data: [
    {'id': 2},
  ],
  statusCode: 200,
);
const gone = StoreApiException(
  kind: StoreApiFailureKind.notFound,
  message: 'fixture',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'publish before first disk load cannot return persisted pre-publish data',
    () async {
      final reader = Reader(() async => oldData);
      await PublicCatalogCache(reader, store: 'fixture').get(path);
      final fresh = Completer<StoreApiResponse>();
      reader.read = () => fresh.future;
      final restarted = PublicCatalogCache(reader, store: 'fixture');
      restarted.invalidate();
      final read = restarted.get(path);
      var completed = false;
      read.then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      final returnedBeforeFresh = completed;
      fresh.complete(newData);
      final result = await read;
      expect(
        returnedBeforeFresh,
        false,
        reason:
            'Known Publish must force fresh read even when disk cache was not loaded yet.',
      );
      expect(result.data, newData.data);
    },
  );
  for (final staleFailure in [false, true]) {
    test(
      'old completion $staleFailure preserves newer pending operation and cache',
      () async {
        final old = Completer<StoreApiResponse>();
        final current = Completer<StoreApiResponse>();
        final reader = Reader(() => old.future);
        final cache = PublicCatalogCache(reader, store: 'fixture');
        final oldRead = cache.get(path);
        final handledOld = oldRead.then((_) {}, onError: (Object _) {});
        await Future<void>.delayed(Duration.zero);
        cache.invalidate();
        reader.read = () => current.future;
        final newRead = cache.get(path);
        await Future<void>.delayed(Duration.zero);
        if (staleFailure) {
          old.completeError(gone);
        } else {
          old.complete(oldData);
        }
        await handledOld;
        final joined = cache.get(path);
        await Future<void>.delayed(Duration.zero);
        expect(reader.calls, 2);
        current.complete(newData);
        expect((await newRead).data, newData.data);
        expect((await joined).data, newData.data);
        expect((await cache.get(path)).data, newData.data);
      },
    );
  }
}
