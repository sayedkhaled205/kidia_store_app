// Exercise the same customer-flow contracts on the native iOS engine.
// Fixtures deliberately avoid changing live customers, orders or payments.
import 'package:integration_test/integration_test.dart';

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  auth.main();
  deletion.main();
  gallery.main();
  wishlist.main();
  cart.main();
  catalog.main();
  checkout.main();
  checkout_auth.main();
}
