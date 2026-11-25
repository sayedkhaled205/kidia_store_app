import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/network/catalog_snapshot.dart';
import 'package:mobishop_store_app/core/network/catalog_snapshot_plain.dart'
    as web;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const prefix = 'catalog-gzip-v1:';
  String pack(List<int> bytes) => '$prefix${base64Encode(gzip.encode(bytes))}';

  test('small and legacy snapshots keep their exact JSON', () async {
    const raw = '{"saved":123,"headers":{},"data":[{"name":"كيديا 儿童"}]}';
    expect(await encodeCatalogSnapshot(raw), raw);
    expect(await decodeCatalogSnapshot(raw, 1024), raw);
  });

  test('large Unicode snapshot is lossless and keeps character limit', () async {
    final raw = jsonEncode({'data': List.filled(20000, 'منتج 儿童 👟')});
    final clock = Stopwatch()..start();
    final encoded = await encodeCatalogSnapshot(raw);
    final encodeUs = clock.elapsedMicroseconds;
    clock.reset();
    expect(await decodeCatalogSnapshot(encoded, raw.length), raw);
    debugPrint(
      'CATALOG_CODEC chars=${raw.length} stored=${encoded.length} encodeUs=$encodeUs decodeUs=${clock.elapsedMicroseconds}',
    );
    expect(encoded, startsWith(prefix));
    expect(encoded.length, lessThan(raw.length ~/ 4));
    await expectLater(
      decodeCatalogSnapshot(encoded, raw.length - 1),
      throwsFormatException,
    );
  });

  test('incompressible ASCII stays plain instead of growing on disk', () async {
    final random = Random(42);
    final raw = String.fromCharCodes(
      List.generate(40000, (_) => 32 + random.nextInt(95)),
    );
    expect(await encodeCatalogSnapshot(raw), raw);
  });

  test('browser keeps its previous plain storage format', () async {
    final raw = jsonEncode(List.filled(40000, 'منتج'));
    expect(await web.encodeCatalogSnapshot(raw), raw);
    expect(await web.decodeCatalogSnapshot(raw, raw.length), raw);
  });

  test(
    'truncated real gzip trailer is not accepted as a complete snapshot',
    () async {
      final compressed = gzip.encode(
        utf8.encode(jsonEncode(List.filled(10000, 'منتج'))),
      );
      for (var removed = 1; removed <= 8; removed++) {
        final raw =
            '$prefix${base64Encode(compressed.sublist(0, compressed.length - removed))}';
        await expectLater(
          decodeCatalogSnapshot(raw, 100000),
          throwsA(isA<Exception>()),
        );
      }
    },
  );

  test(
    'corrupt, truncated, invalid UTF8 and oversized data fail safely',
    () async {
      for (final raw in [
        '$prefix!!!',
        '$prefix${base64Encode([31, 139, 8])}',
        pack([255, 254]),
        pack(List.filled(4000, 65)),
        '$prefix${base64Encode([...gzip.encode(List.filled(2000, 65)), ...gzip.encode(List.filled(2000, 65))])}',
      ]) {
        await expectLater(
          decodeCatalogSnapshot(raw, 1000),
          throwsA(isA<Exception>()),
        );
      }
    },
  );
}
