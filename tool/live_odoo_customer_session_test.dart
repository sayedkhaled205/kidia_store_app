// Opt-in public contract probe. This is intentionally outside test/ so ordinary
// regression gates never contact a real store. It reads a fresh guest session
// only; no credentials, cart mutation, order creation or payment is performed.
// Run with STORE_PLATFORM=odoo and an explicitly authorized HTTPS STORE_URL.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/cart/data/odoo/odoo_cart85.dart';

void main() {
  test(
    'authorized Odoo guest session accepts the installed account contract',
    () async {
      expect(AppConfig.commercePlatform, CommercePlatform.odoo);
      final connection = AppConfig.commerceConnection;
      final client = OdooCustomerClient51(connection: connection);
      addTearDown(client.close);
      final session = await client.session();
      expect(session.authenticated, isFalse);
      expect(session.customer, isNull);
      expect(client.isAuthenticated, isFalse);
      if (client.cartSupported85) {
        final response = await client.cart85();
        final cart = OdooCart85.fromResponse(
          response,
          customerId: null,
          origin: connection.storeOrigin,
        ).cart;
        expect(cart.isEmpty, isTrue);
        expect(cart.totals.priceMinor, '0');
        expect(cart.paymentMethods, isEmpty);
      }
    },
  );
}
