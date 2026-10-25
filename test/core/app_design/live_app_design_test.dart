import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/live_app_design.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'app_design_fixture58.dart';

String release(int revision, {String color = '#4EA999', String? origin}) {
  final data = appDesignFixture58();
  (data['identity'] as Map)['primary_color'] = color;
  if (origin != null) data['store_origin'] = origin;
  final encoded = base64Encode(utf8.encode(jsonEncode(data)));
  return jsonEncode({
    'protocol': 1,
    'revision': revision,
    'bundle': encoded,
    'sha256': sha256.convert(utf8.encode(encoded)).toString(),
  });
}

class Cache implements LiveDesignCache {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    if (fail) throw StateError('offline disk');
    value = next;
  }
}

class Transport implements LiveDesignTransport {
  String? next, etag;
  int calls = 0;
  bool fail = false;
  Completer<String?>? pending;
  @override
  Future<String?> fetch(String? tag) async {
    calls++;
    etag = tag;
    if (fail) throw StateError('offline');
    return pending == null ? next : pending!.future;
  }
}

Future<void> settle() => pumpEventQueue(times: 12);
void main() {
  late Cache cache;
  late Transport transport;
  late LiveAppDesign engine;
  setUp(() {
    cache = Cache();
    transport = Transport();
    engine = LiveAppDesign(
      transport: transport,
      cache: cache,
      platform: CommercePlatform.odoo,
      origin: Uri.parse(appDesignOrigin58),
      interval: const Duration(hours: 1),
    );
  });
  tearDown(() => engine.dispose());
  test(
    'publishes without rebuilding and keeps offline cache across restart',
    () async {
      transport.next = release(1);
      engine.configure(active: true, safeToApply: true);
      await settle();
      expect(engine.revision, 1);
      transport.next = release(2, color: '#112233');
      await engine.refresh();
      expect(engine.design!.identity['primary_color'], '#112233');
      final restarted = LiveAppDesign(
        transport: Transport()..fail = true,
        cache: cache,
        platform: CommercePlatform.odoo,
        origin: Uri.parse(appDesignOrigin58),
      );
      restarted.configure(active: true, safeToApply: true);
      await settle();
      expect(restarted.revision, 2);
      restarted.dispose();
    },
  );
  test(
    'draft or not-modified response never replaces current design',
    () async {
      cache.value = release(3);
      engine.configure(active: true, safeToApply: true);
      await settle();
      expect(engine.revision, 3);
      expect(transport.etag, startsWith('"3-'));
      transport.fail = true;
      await engine.refresh();
      expect(engine.revision, 3);
    },
  );
  test('checkout and login defer application until safe Home route', () async {
    transport.next = release(4);
    engine.configure(active: true, safeToApply: false);
    await settle();
    expect(engine.design, isNull);
    expect(cache.value, isNotNull);
    engine.configure(active: true, safeToApply: true);
    expect(engine.revision, 4);
  });
  test(
    'invalid, oversized and foreign-store data keep last good version',
    () async {
      transport.next = release(5);
      engine.configure(active: true, safeToApply: true);
      await settle();
      for (final bad in [
        'bad json',
        release(6, origin: 'https://foreign.invalid'),
        release(6).replaceFirst('"protocol":1', '"protocol":2'),
        'x' * (PublishedAppDesign.maxResponseBytes + 1),
      ]) {
        transport.next = bad;
        await engine.refresh();
        expect(engine.revision, 5);
      }
    },
  );
  test(
    'rollback uses a newer revision; stale CDN revisions are ignored',
    () async {
      transport.next = release(9, color: '#123456');
      engine.configure(active: true, safeToApply: true);
      await settle();
      transport.next = release(8);
      await engine.refresh();
      expect(engine.revision, 9);
      transport.next = release(10);
      await engine.refresh();
      expect(engine.revision, 10);
      expect(engine.design!.identity['primary_color'], '#4EA999');
    },
  );
  test(
    'background and disposal stop updates; concurrent refresh is coalesced',
    () async {
      transport.pending = Completer<String?>();
      engine.configure(active: true, safeToApply: true);
      await settle();
      await engine.refresh();
      expect(transport.calls, 1);
      engine.configure(active: false, safeToApply: true);
      transport.pending!.complete(release(11));
      await settle();
      expect(engine.design, isNull);
      await engine.refresh();
      expect(transport.calls, 1);
      engine.configure(active: true, safeToApply: true);
      await settle();
      expect(engine.revision, 11);
    },
  );
  test(
    'bad cache and failing disk do not prevent valid live updates',
    () async {
      cache.value = 'broken';
      cache.fail = true;
      transport.next = release(12);
      engine.configure(active: true, safeToApply: true);
      await settle();
      expect(engine.revision, 12);
    },
  );
}
