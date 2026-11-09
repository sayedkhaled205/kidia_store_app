import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/core/network/public_catalog_cache.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('publish during cold read forces a fresh post-publish request', () async {
    final oldResponse = Completer<StoreApiResponse>();
    final reader = Reader(() => oldResponse.future);
    final cache = PublicCatalogCache(reader, store: 'https://example.test');
    const path = '/wp-json/wc/store/v1/products';
    final oldRead = cache.get(path);
    await Future<void>.delayed(Duration.zero);
    expect(reader.calls, 1);
    cache.invalidate();
    reader.read = () async => const StoreApiResponse(
      data: [
        {'id': 2},
      ],
      statusCode: 200,
    );
    final publishedRead = cache.get(path);
    await Future<void>.delayed(Duration.zero);
    oldResponse.complete(
      const StoreApiResponse(
        data: [
          {'id': 1},
        ],
        statusCode: 200,
      ),
    );
    await oldRead;
    expect(
      (await publishedRead).data,
      [
        {'id': 2},
      ],
      reason:
          'A new consumer after publish must not join a stale pre-publish request.',
    );
    expect(reader.calls, 2);
  });
}
