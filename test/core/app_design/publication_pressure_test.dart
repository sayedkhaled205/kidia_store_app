import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/live_app_design.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';

import 'app_design_fixture58.dart';
import 'live_app_design_test.dart' show Cache, Transport, settle;

void main() {
  for (final platform in CommercePlatform.values) {
    final origin = platform == CommercePlatform.shopify
        ? 'https://fixture.myshopify.com'
        : appDesignOrigin58;
    test(
      '${platform.name}: 500 overlapping refresh requests perform one read and retain a dirty form',
      () async {
        final transport = Transport()..pending = Completer<String?>();
        final cache = Cache();
        final engine = LiveAppDesign(
          transport: transport,
          cache: cache,
          platform: platform,
          origin: Uri.parse(origin),
          interval: const Duration(hours: 1),
        );
        addTearDown(engine.dispose);
        engine.configure(active: true, safeToApply: false);
        await settle();
        await Future.wait(List.generate(500, (_) => engine.refresh()));
        expect(transport.calls, 1);
        transport.pending!.complete(release(1, platform, origin));
        await settle();
        expect(engine.revision, isNull);
        expect(cache.value, isNotNull);
        engine.configure(active: true, safeToApply: true);
        expect(engine.revision, 1);
        transport.pending = null;
        var changes = 0;
        engine.addListener(() => changes++);
        for (var revision = 2; revision <= 51; revision++) {
          transport.next = release(
            revision,
            platform,
            origin,
            color: revision.isEven ? '#112233' : '#4EA999',
          );
          await engine.refresh();
          expect(engine.revision, revision);
        }
        expect(changes, 50);
        transport.fail = true;
        await engine.refresh();
        expect(engine.revision, 51);
        engine.configure(active: false, safeToApply: true);
        final before = transport.calls;
        await Future.wait(List.generate(500, (_) => engine.refresh()));
        expect(transport.calls, before);
      },
    );
  }
}

String release(
  int revision,
  CommercePlatform platform,
  String origin, {
  String color = '#4EA999',
}) {
  final data = appDesignFixture58();
  data['platform'] = switch (platform) {
    CommercePlatform.wooCommerce => 'woocommerce',
    CommercePlatform.shopify => 'shopify',
    CommercePlatform.odoo => 'odoo',
  };
  data['store_origin'] = origin;
  data['identity']['primary_color'] = color;
  final encoded = base64Encode(utf8.encode(jsonEncode(data)));
  return jsonEncode({
    'protocol': 1,
    'revision': revision,
    'bundle': encoded,
    'sha256': sha256.convert(utf8.encode(encoded)).toString(),
  });
}
