// Focused native gesture regression; the full customer suite imports these too.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/offline_fixture_http.dart';
import '../test/features/product/presentation/product_image_gallery_test.dart'
    as gallery;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final previous = HttpOverrides.current;
  setUpAll(() => HttpOverrides.global = OfflineFixtureHttpOverrides());
  tearDownAll(() => HttpOverrides.global = previous);
  gallery.main();
}
