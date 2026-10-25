import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/live_app_design.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';

void main() {
  final endpoint = Platform.environment['LIVE_DESIGN_SMOKE_URL'];
  final origin = Platform.environment['LIVE_DESIGN_SMOKE_ORIGIN'];
  test(
    'public deployed design is valid and conditional refresh keeps the same release',
    () async {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      addTearDown(() => dio.close(force: true));
      final transport = DioLiveDesignTransport(dio, Uri.parse(endpoint!));
      final raw = await transport.fetch(null);
      expect(raw, isNotNull);
      final publication = PublishedAppDesign.parse(
        raw!,
        CommercePlatform.wooCommerce,
        Uri.parse(origin!),
      );
      expect(publication.revision, greaterThan(0));
      final unchanged = await transport.fetch(publication.etag);
      // An intermediary may return the unchanged body instead of forwarding 304.
      if (unchanged != null) {
        final second = PublishedAppDesign.parse(
          unchanged,
          CommercePlatform.wooCommerce,
          Uri.parse(origin),
        );
        expect(second.revision, publication.revision);
        expect(second.digest, publication.digest);
      }
      final output = Platform.environment['LIVE_DESIGN_SMOKE_OUTPUT'];
      if (output != null) await File(output).writeAsString(raw);
      // ignore: avoid_print -- Explicitly opted-in deployment verification.
      print(
        'Verified public revision ${publication.revision}, digest ${publication.digest}',
      );
    },
    skip: endpoint == null || origin == null,
  );
}
