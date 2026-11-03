import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'offline_fixture_http.dart';

void main() {
  test(
    'customer fixtures cannot open external or local network connections',
    () async {
      await HttpOverrides.runZoned(() async {
        final client = HttpClient();
        try {
          for (final url in [
            'https://example.test/image.jpg',
            'http://127.0.0.1:1/',
          ]) {
            await expectLater(
              client.getUrl(Uri.parse(url)),
              throwsA(
                isA<SocketException>().having(
                  (error) => error.message,
                  'message',
                  'Network disabled for customer fixtures',
                ),
              ),
            );
          }
        } finally {
          client.close(force: true);
        }
      }, createHttpClient: OfflineFixtureHttpOverrides().createHttpClient);
    },
  );
}
