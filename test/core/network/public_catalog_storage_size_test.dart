import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/core/network/public_catalog_cache.dart';
import 'package:mobishop_store_app/core/network/catalog_snapshot.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';

class _Catalog implements StoreApiClient {
  bool offline = false;
  StoreApiException? failure;
  final data = List.generate(
    60,
    (i) => {
      'id': i,
      'name': 'منتج تجريبي $i 测试商品',
      'description': List.filled(
        18,
        'تفاصيل المقاس والخامة والعناية بالمنتج.',
      ).join(' '),
      'prices': {'price': '${28000 + i}', 'currency_code': 'EGP'},
      'images': List.generate(
        3,
        (j) => {
          'id': i * 3 + j,
          'src': 'https://store.example/uploads/2026/product-$i-$j.jpg',
          'alt': 'صورة المنتج $i',
        },
      ),
    },
  );
  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (failure != null) throw failure!;
    if (offline) {
      throw const StoreApiException(
        kind: StoreApiFailureKind.connection,
        message: 'offline',
      );
    }
    return StoreApiResponse(
      data: data,
      statusCode: 200,
      headers: {
        'x-wp-total': ['600'],
      },
    );
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  const path = '/wp-json/wc/store/v1/products';

  test(
    'large refreshed catalog uses less disk and preserves offline freshness',
    () async {
      SharedPreferences.resetStatic();
      final disk = <String, Object>{};
      var saved = Completer<void>();
      var bytesWritten = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'getAll') return Map<String, Object>.from(disk);
        if (call.method == 'setString') {
          final raw = call.arguments['value'] as String;
          bytesWritten += utf8.encode(raw).length;
          disk[call.arguments['key'] as String] = raw;
          saved.complete();
          return true;
        }
        throw StateError('Unexpected ${call.method}');
      });
      addTearDown(() {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        SharedPreferences.resetStatic();
      });
      var now = DateTime.utc(2026, 11, 25);
      final network = _Catalog();
      final cache = PublicCatalogCache(
        network,
        store: 'synthetic-size-fixture',
        now: () => now,
      );
      await cache.get(path);
      await saved.future;
      final rawSnapshotBytes = utf8
          .encode(
            jsonEncode({
              '$path?{}': {
                'saved': now.millisecondsSinceEpoch,
                'data': network.data,
                'headers': {
                  'x-wp-total': ['600'],
                },
              },
            }),
          )
          .length;
      // Separate successful refreshes must persist their new timestamps, even
      // when the network returns identical products and the disk is already idle.
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(days: 2));
        saved = Completer<void>();
        cache.invalidate();
        expect((await cache.get(path)).data, network.data);
        await saved.future;
      }
      final storedBytes = utf8.encode(disk.values.single as String).length;
      debugPrint(
        'CATALOG_STORAGE raw=$rawSnapshotBytes stored=$storedBytes fourWrites=$bytesWritten',
      );
      SharedPreferences.resetStatic();
      network.offline = true;
      now = now.add(
        const Duration(days: 2),
      ); // Original snapshot is now expired.
      final restarted = PublicCatalogCache(
        network,
        store: 'synthetic-size-fixture',
        now: () => now,
      );
      final response = await restarted.get(path);
      expect(response.data, network.data);
      expect(response.headers, {
        'x-wp-total': ['600'],
      });
      now = now.add(const Duration(days: 6));
      await expectLater(restarted.get(path), throwsA(isA<StoreApiException>()));
      expect(storedBytes, lessThan(rawSnapshotBytes * .4));
    },
  );

  for (final reject in [false, true]) {
    test(
      'compressed write preserves ${reject ? 'access eviction' : 'new publication'} order',
      () async {
        SharedPreferences.resetStatic();
        final disk = <String, Object>{};
        final started = Completer<void>();
        final release = Completer<void>();
        final finished = Completer<void>();
        var writes = 0;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          if (call.method == 'getAll') return Map<String, Object>.from(disk);
          if (++writes == 1) {
            started.complete();
            await release.future;
          }
          disk[call.arguments['key'] as String] =
              call.arguments['value'] as String;
          if (writes == 2) finished.complete();
          return true;
        });
        addTearDown(() {
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
          SharedPreferences.resetStatic();
        });
        final network = _Catalog();
        final cache = PublicCatalogCache(network, store: 'compressed-order');
        // The full response must be available before its optional disk write.
        expect((await cache.get(path)).data, network.data);
        await started.future;
        cache.invalidate();
        if (reject) {
          network.failure = const StoreApiException(
            kind: StoreApiFailureKind.notFound,
            statusCode: 404,
            message: 'removed',
          );
          final rejection = expectLater(
            cache.get(path),
            throwsA(same(network.failure)),
          );
          release.complete();
          await rejection;
        } else {
          network.data[0]['name'] = 'منتج بعد النشر';
          expect((await cache.get(path)).data, network.data);
          release.complete();
        }
        await finished.future;
        final raw = await decodeCatalogSnapshot(
          disk.values.single as String,
          PublicCatalogCache.maxBytes,
        );
        final persisted = jsonDecode(raw) as Map;
        if (reject) {
          expect(persisted, isEmpty);
        } else {
          expect(persisted.values.single['data'], network.data);
        }
        SharedPreferences.resetStatic();
        network.failure = null;
        network.offline = true;
        final restarted = PublicCatalogCache(
          network,
          store: 'compressed-order',
        );
        if (reject) {
          await expectLater(
            restarted.get(path),
            throwsA(isA<StoreApiException>()),
          );
        } else {
          expect((await restarted.get(path)).data, network.data);
        }
      },
    );
  }

  for (final legacy in [false, true]) {
    test(
      '${legacy ? 'legacy JSON migrates' : 'corrupt compressed cache recovers'} on next network read',
      () async {
        final network = _Catalog();
        final raw = legacy
            ? jsonEncode({
                '$path?{}': {'saved': 0, 'data': [], 'headers': {}},
              })
            : 'catalog-gzip-v1:bad';
        SharedPreferences.setMockInitialValues({
          'public_catalog_v1:migration': raw,
        });
        addTearDown(SharedPreferences.resetStatic);
        final cache = PublicCatalogCache(network, store: 'migration');
        expect((await cache.get(path)).data, network.data);
        // Await the ordered eviction to also drain the preceding compressed write.
        network.failure = const StoreApiException(
          kind: StoreApiFailureKind.notFound,
          message: 'removed',
        );
        cache.invalidate();
        await expectLater(cache.get(path), throwsA(same(network.failure)));
        expect(
          (await SharedPreferences.getInstance()).getString(
            'public_catalog_v1:migration',
          ),
          '{}',
        );
      },
    );
  }
}
