import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/core/network/public_catalog_cache.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';

class _Reader implements StoreApiClient {
  int id = 1;
  bool offline = false;
  StoreApiException? failure;

  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (failure != null) throw failure!;
    if (offline) {
      throw const StoreApiException(
        kind: StoreApiFailureKind.connection,
        message: 'offline fixture',
      );
    }
    return StoreApiResponse(
      data: [
        {'id': id},
      ],
      statusCode: 200,
    );
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  const path = '/wp-json/wc/store/v1/products';
  late Map<String, Object> disk;
  late Future<bool> Function(MethodCall) write;

  setUp(() {
    SharedPreferences.resetStatic();
    disk = {};
    write = (call) async {
      disk[call.arguments['key'] as String] = call.arguments['value'] as Object;
      return true;
    };
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'getAll') return Map<String, Object>.from(disk);
      if (call.method == 'setString') return write(call);
      throw StateError('Unexpected preference operation: ${call.method}');
    });
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
  });

  test('a burst of catalog results shares one queued disk snapshot', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var writes = 0;
    write = (call) async {
      if (++writes == 1) {
        started.complete();
        await release.future;
      }
      disk[call.arguments['key'] as String] = call.arguments['value'] as Object;
      return true;
    };
    final reader = _Reader();
    final cache = PublicCatalogCache(reader, store: 'fixture');
    await cache.get(path, queryParameters: {'page': 1});
    await started.future;
    for (var page = 2; page <= 21; page++) {
      reader.id = page;
      final result = await cache.get(path, queryParameters: {'page': page});
      expect(result.data, [
        {'id': page},
      ]);
    }
    release.complete();
    await Future<void>.delayed(Duration.zero);
    expect(
      writes,
      2,
      reason: 'Do not write the same merged snapshot 20 times.',
    );
    expect(jsonDecode(disk.values.single as String).length, 21);

    SharedPreferences.resetStatic();
    reader.offline = true;
    final restarted = PublicCatalogCache(reader, store: 'fixture');
    for (var page = 1; page <= 21; page++) {
      expect(
        (await restarted.get(path, queryParameters: {'page': page})).data,
        [
          {'id': page},
        ],
      );
    }
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'fresh products are readable while the optional disk write is held',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final persisted = Completer<void>();
      write = (call) async {
        started.complete();
        await release.future;
        disk[call.arguments['key'] as String] =
            call.arguments['value'] as Object;
        persisted.complete();
        return true;
      };
      final cache = PublicCatalogCache(_Reader(), store: 'fixture');
      var readable = false;
      final result = cache.get(path).then((value) {
        readable = true;
        return value;
      });
      await started.future;
      await Future<void>.delayed(Duration.zero);
      final readableBeforeDisk = readable;
      release.complete();
      await persisted.future;
      expect((await result).data, [
        {'id': 1},
      ]);
      expect(
        readableBeforeDisk,
        isTrue,
        reason: 'A completed network read must not wait for optional storage.',
      );
    },
  );

  test(
    'queued writes preserve the newer publication after a disk restart',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final persisted = Completer<void>();
      var writes = 0;
      write = (call) async {
        final sequence = ++writes;
        if (sequence == 1) {
          started.complete();
          await release.future;
        }
        disk[call.arguments['key'] as String] =
            call.arguments['value'] as Object;
        if (sequence == 2) persisted.complete();
        return true;
      };
      final reader = _Reader();
      final cache = PublicCatalogCache(reader, store: 'fixture');
      final first = cache.get(path);
      await started.future;
      reader.id = 9;
      cache.invalidate();
      var freshReadable = false;
      final second = cache.get(path).then((value) {
        freshReadable = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      final availableBeforeDisk = freshReadable;
      release.complete();
      await Future.wait([first, second, persisted.future]);
      expect(availableBeforeDisk, isTrue);
      expect(writes, 2);
      expect(jsonDecode(disk.values.single as String).values.single['data'], [
        {'id': 9},
      ]);
      SharedPreferences.resetStatic();
      reader.offline = true;
      final restarted = PublicCatalogCache(reader, store: 'fixture');
      expect((await restarted.get(path)).data, [
        {'id': 9},
      ]);
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('failed disk storage does not fail public product reads', () async {
    final failed = Completer<void>();
    write = (_) async {
      failed.complete();
      throw PlatformException(code: 'storage_full');
    };
    final reader = _Reader();
    final cache = PublicCatalogCache(reader, store: 'fixture');
    expect((await cache.get(path)).data, [
      {'id': 1},
    ]);
    await failed.future;
    reader.offline = true;
    expect((await cache.get(path)).data, [
      {'id': 1},
    ]);
  });

  test(
    'access-error eviction follows a held write without restoring it',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var writes = 0;
      write = (call) async {
        if (++writes == 1) {
          started.complete();
          await release.future;
        }
        disk[call.arguments['key'] as String] =
            call.arguments['value'] as Object;
        return true;
      };
      final reader = _Reader();
      final cache = PublicCatalogCache(reader, store: 'fixture');
      await cache.get(path);
      await started.future;
      const gone = StoreApiException(
        kind: StoreApiFailureKind.notFound,
        message: 'removed product fixture',
        statusCode: 404,
      );
      reader.failure = gone;
      cache.invalidate();
      final rejected = expectLater(cache.get(path), throwsA(same(gone)));
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await rejected;
      expect(writes, 2);
      expect(jsonDecode(disk.values.single as String), isEmpty);

      SharedPreferences.resetStatic();
      reader.failure = null;
      reader.offline = true;
      final restarted = PublicCatalogCache(reader, store: 'fixture');
      await expectLater(
        restarted.get(path),
        throwsA(
          isA<StoreApiException>().having(
            (error) => error.kind,
            'kind',
            StoreApiFailureKind.connection,
          ),
        ),
      );
    },
  );

  test('the write queue recovers after an earlier storage failure', () async {
    final failed = Completer<void>();
    final persisted = Completer<void>();
    var writes = 0;
    write = (call) async {
      if (++writes == 1) {
        failed.complete();
        throw PlatformException(code: 'storage_full');
      }
      disk[call.arguments['key'] as String] = call.arguments['value'] as Object;
      persisted.complete();
      return true;
    };
    final reader = _Reader();
    final cache = PublicCatalogCache(reader, store: 'fixture');
    await cache.get(path);
    await failed.future;
    reader.id = 9;
    cache.invalidate();
    expect((await cache.get(path)).data, [
      {'id': 9},
    ]);
    await persisted.future;
    expect(writes, 2);

    SharedPreferences.resetStatic();
    reader.offline = true;
    final restarted = PublicCatalogCache(reader, store: 'fixture');
    expect((await restarted.get(path)).data, [
      {'id': 9},
    ]);
    await Future<void>.delayed(Duration.zero);
  });
}
