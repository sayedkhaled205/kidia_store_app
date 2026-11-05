import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory('build/ios/simulator-artifacts');
  await output.create(recursive: true);
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          await File(
            '${output.path}/$name.png',
          ).writeAsBytes(bytes, flush: true);
          return true;
        },
    responseDataCallback: (data) async {
      final report = Map<String, dynamic>.of(data ?? <String, dynamic>{});
      report.remove('screenshots');
      await File(
        '${output.path}/live-public-result.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    },
  );
}
