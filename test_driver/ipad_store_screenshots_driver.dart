import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory('build/ipad-store-screenshots');
  await output.create(recursive: true);
  final device = Platform.environment['IOS_TEST_DEVICE'];
  if (device == null) throw StateError('An actual iPad simulator is required');
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          if (name != 'diagnostic-timeout' &&
              !RegExp(r'^0[1-5]-[a-z-]+$').hasMatch(name)) {
            throw StateError('Invalid capture name');
          }
          // iOS captures these original PNG bytes at takeScreenshot time.
          // Native onScreenshot callbacks run after the test has finished.
          await File('${output.path}/$name.png')
              .writeAsBytes(bytes, flush: true);
          return true;
        },
    responseDataCallback: (data) async {
      final report = Map<String, dynamic>.of(data ?? <String, dynamic>{});
      report.remove('screenshots');
      await File('${output.path}/capture-report.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    },
  );
}
