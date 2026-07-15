import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/home/presentation/home_action_launcher.dart';

void main() {
  group('HomeActionLauncher.parseExternalHttpUri', () {
    test('accepts absolute HTTP and HTTPS links', () {
      expect(
        HomeActionLauncher.parseExternalHttpUri('https://example.com/deal'),
        Uri.parse('https://example.com/deal'),
      );
      expect(
        HomeActionLauncher.parseExternalHttpUri(' http://example.com/path '),
        Uri.parse('http://example.com/path'),
      );
    });

    test('rejects unsafe or incomplete links', () {
      for (final String value in <String>[
        '',
        'example.com',
        '/relative/path',
        'javascript:alert(1)',
        'file:///tmp/file',
        'mailto:customer@example.com',
        'https:///missing-host',
      ]) {
        expect(
          HomeActionLauncher.parseExternalHttpUri(value),
          isNull,
          reason: value,
        );
      }
    });
  });
}
