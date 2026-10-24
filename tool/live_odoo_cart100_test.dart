// Opt-in acceptance against an explicitly authorized store. A new in-memory
// guest SID is used, never an existing buyer session. No confirmation/payment.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/odoo_catalog_client.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/cart/data/repositories/odoo_cart_repository85.dart';
import 'package:mobishop_store_app/features/catalog/data/odoo/odoo_catalog_gateway.dart';

void main() {
  test('authorized Odoo fresh guest basket add/update/remove', () async {
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
    expect(
      variantId,
      isNotNull,
      reason: 'A published purchasable variant is required',
    );
    try {
      final added = await repository.addItem(
        productId: variantId!,
        quantity: 1,
      );
      expect(added.itemsCount, 1);
      final line = added.items.single;
      expect(line.productId, variantId);
      expect(added.totals.currency.code, isNotEmpty);
      if (line.quantityLimits.maximum >= 2) {
        final updated = await repository.updateItem(key: line.key, quantity: 2);
        expect(updated.items.single.quantity, 2);
      }
    } finally {
      // Reconcile the exact known SID even when a mutation response is lost;
      // never replay addItem. Only remove lines in this new test guest basket.
      final current = await repository.getCart();
      for (final item in current.items) {
        await repository.removeItem(item.key);
      }
      expect((await repository.getCart()).isEmpty, isTrue);
    }
    expect(client.isAuthenticated, isFalse);
  });
}
