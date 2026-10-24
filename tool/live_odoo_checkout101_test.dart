// Opt-in test: new in-memory guest basket only. Never submits an address,
// confirms an order or creates a payment. Clear only this probe's own basket.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/odoo_catalog_client.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/cart/data/repositories/odoo_cart_repository85.dart';
import 'package:mobishop_store_app/features/catalog/data/odoo/odoo_catalog_gateway.dart';
import 'package:mobishop_store_app/features/checkout/data/odoo/odoo_checkout101.dart';

void main() {
  test('authorized Odoo native address metadata and shipping HTTP flow', () async {
    expect(const bool.fromEnvironment('ALLOW_CART_MUTATION'), isTrue);
    expect(AppConfig.commercePlatform, CommercePlatform.odoo);
    final connection = AppConfig.commerceConnection;
    final reader = OdooCatalogClient(connection: connection);
    final client = OdooCustomerClient51(connection: connection);
    final catalog = OdooCatalogGateway(reader: reader, connection: connection);
    final repository = OdooCartRepository85(
      client: client,
      isCurrentSession: () => !client.isAuthenticated,
    );
    addTearDown(reader.close);
    addTearDown(client.close);
    addTearDown(repository.dispose);
    expect((await repository.getCart()).isEmpty, isTrue);
    expect(client.checkoutFormSupported101, isTrue);
    final api = OdooCheckout101(
      client,
      isCurrent: () => !client.isAuthenticated,
    );
    final page = await catalog.getProducts(perPage: 20);
    int? variantId;
    for (final product in page.items.where(
      (p) => p.isPurchasable && p.isInStock,
    )) {
      final variants = await catalog.getVariations(product.id);
      variantId = variants
          .where((v) => v.isPurchasable && v.isInStock)
          .firstOrNull
          ?.id;
      if (variantId != null) break;
    }
    expect(variantId, isNotNull);
    try {
      await repository.addItem(productId: variantId!, quantity: 1);
      final form = await api.form();
      // ignore: avoid_print
      print('CHECKOUT101_INITIAL_FORM_PASS fields=${form.fields.length}');
      expect(form.cart.cart.itemsCount, 1);
      expect(form.fields, isNotEmpty);
      expect(form.fields.map((f) => f.name), contains('country_id'));
      final country = form.fields.singleWhere((f) => f.name == 'country_id');
      // Select an explicitly authorized delivery country, not the first
      // alphabetic country which the merchant may not ship to or configure.
      const countryLabel = String.fromEnvironment(
        'CHECKOUT_TEST_COUNTRY',
        defaultValue: 'Egypt',
      );
      final alternative = country.choices.entries
          .where((v) => v.value == countryLabel)
          .firstOrNull
          ?.key;
      expect(alternative, isNotNull);
      if (alternative != null) {
        final changed = await api.form(countryId: int.parse(alternative));
        // ignore: avoid_print
        print(
          'CHECKOUT101_COUNTRY_CHANGE_PASS fields=${changed.fields.length}',
        );
        expect(
          changed.fields.singleWhere((f) => f.name == 'country_id').value,
          alternative,
        );
      }
      final shipping = await api.quote();
      expect(shipping.cart.cart.itemsCount, 1);
      expect(
        shipping.rates.map((r) => r.id).toSet().length,
        shipping.rates.length,
      );
      // Public count only: no address values, cookies, customer data or tokens.
      // ignore: avoid_print
      print(
        'CHECKOUT101_HTTP_PASS fields=${form.fields.length} rates=${shipping.rates.length}',
      );
    } finally {
      final cart = await repository.getCart();
      for (final item in cart.items) {
        await repository.removeItem(item.key);
      }
      expect((await repository.getCart()).isEmpty, isTrue);
    }
    expect(client.isAuthenticated, isFalse);
  });
}
