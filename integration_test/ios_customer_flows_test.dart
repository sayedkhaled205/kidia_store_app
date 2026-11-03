// Exercise the same customer-flow contracts on native Android and iOS engines.
// Fixtures deliberately avoid changing live customers, orders or payments.
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import '../test/support/offline_fixture_http.dart';

import '../test/features/auth/presentation/auth_screen_test.dart' as auth;
import '../test/features/account/presentation/account_deletion_test.dart'
    as deletion;
import '../test/features/product/presentation/product_image_gallery_test.dart'
    as gallery;
import '../test/features/wishlist/presentation/wishlist_screen_test.dart'
    as wishlist;
import '../test/features/cart/presentation/cart_screen_test.dart' as cart;
import '../test/features/catalog/presentation/catalog_screens_test.dart'
    as catalog;
import '../test/features/checkout/presentation/checkout_screen_test.dart'
    as checkout;
import '../test/features/auth/presentation/checkout_auth_gate_test.dart'
    as checkout_auth;
import '../test/features/page_builder/presentation/wordmark_bounds_test.dart'
    as wordmark;

void main() {
  // The native test runner may have already initialized this binding.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().defaultTestTimeout =
      const Timeout(Duration(minutes: 3));
  final previousHttpOverrides = HttpOverrides.current;
  setUpAll(() => HttpOverrides.global = OfflineFixtureHttpOverrides());
  tearDownAll(() => HttpOverrides.global = previousHttpOverrides);
  // Imported widget fixtures synthesize text and viewport sizes. Keep their
  // keyboard deterministic; physical keyboard behavior needs its own UI run.
  setUp(
    () =>
        IntegrationTestWidgetsFlutterBinding.instance.testTextInput.register(),
  );
  tearDown(
    () => IntegrationTestWidgetsFlutterBinding.instance.testTextInput
        .unregister(),
  );
  auth.main();
  deletion.main();
  gallery.main();
  wishlist.main();
  cart.main();
  catalog.main();
  checkout.main();
  checkout_auth.main();
  wordmark.main();
}
