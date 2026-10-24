import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_session_store51.dart';
import 'package:mobishop_store_app/features/cart/data/odoo/odoo_cart85.dart';
import 'package:mobishop_store_app/features/cart/data/repositories/odoo_cart_repository85.dart';
import 'package:mobishop_store_app/features/cart/domain/repositories/cart_repository.dart';

import 'support/odoo_merchant100.dart';

void main() {
  for (final host in [
    'alpha.odoo.example.invalid',
    'beta.odoo.example.invalid',
  ]) {
    test(
      '$host guest add/update/remove uses exact server quote and session',
      () async {
        final merchant = OdooMerchant100(host);
        final client = odooTestClient100(merchant);
        addTearDown(client.close);
        final repository = OdooCartRepository85(
          client: client,
          isCurrentSession: () => true,
        );
        addTearDown(repository.dispose);
        expect((await repository.getCart()).isEmpty, isTrue);
        final added = await repository.addItem(productId: 7, quantity: 2);
        expect(added.totals.priceMinor, '27158');
        expect(added.items.single.productId, 7);
        expect(added.items.single.quantityLimits.maximum, 9);
        expect(added.hasCalculatedShipping, isFalse);
        expect(
          added.paymentMethods,
          isEmpty,
          reason: 'No fabricated portal payment method',
        );
        expect(
          (await repository.updateItem(
            key: '12',
            quantity: 3,
          )).totals.priceMinor,
          '40737',
        );
        expect((await repository.removeItem('12')).isEmpty, isTrue);
        expect(client.isAuthenticated, isFalse);
        expect(merchant.requests.where((r) => r.method == 'POST').length, 3);
      },
    );
  }

  test('guest restart keeps own SID without promoting a customer', () async {
    final merchant = OdooMerchant100('alpha.odoo.example.invalid');
    final storage = MemoryOdooCustomerSessionStore51();
    final first = odooTestClient100(merchant, storage: storage);
    await first.addCartItem85(productId: 7, quantity: 1);
    first.close();
    expect((await storage.read())!.isGuest, isTrue);
    final second = odooTestClient100(merchant, storage: storage);
    addTearDown(second.close);
    expect((await second.restoreSession()).authenticated, isFalse);
    final response = await second.cart85();
    expect(
      OdooCart85.fromResponse(
        response,
        customerId: null,
        origin: second.origin,
      ).cart.itemsCount,
      1,
    );
  });

  test('disabled contract never sends a cart request', () async {
    final merchant = OdooMerchant100('alpha.odoo.example.invalid')..enabled = false;
    final client = odooTestClient100(merchant);
    addTearDown(client.close);
    await expectLater(
      client.cart85(),
      throwsA(
        isA<OdooCustomerException51>().having(
          (e) => e.code,
          'code',
          'cart_contract_unavailable',
        ),
      ),
    );
    expect(merchant.requests.length, 1);
  });

  test('invalid revalidation revokes a previous cart capability', () async {
    final merchant = OdooMerchant100('alpha.odoo.example.invalid');
    final client = odooTestClient100(merchant);
    addTearDown(client.close);
    await client.session();
    expect(client.cartSupported85, isTrue);
    merchant.malformedCapabilities = true;
    await expectLater(
      client.session(),
      throwsA(isA<OdooCustomerException51>()),
    );
    expect(client.cartSupported85, isFalse);
    await expectLater(
      client.addCartItem85(productId: 7, quantity: 1),
      throwsA(isA<OdooCustomerException51>()),
    );
    expect(
      merchant.requests.every((r) => r.uri.path.endsWith('/session')),
      isTrue,
    );
  });

  test(
    'queued writes are serialized; a revoked owner cannot receive or mutate',
    () async {
      final merchant = OdooMerchant100('alpha.odoo.example.invalid');
      final client = odooTestClient100(merchant);
      addTearDown(client.close);
      final repository = OdooCartRepository85(
        client: client,
        isCurrentSession: () => true,
      );
      addTearDown(repository.dispose);
      await repository.addItem(productId: 7, quantity: 1);
      merchant.pauseCart = Completer<void>();
      final first = repository.updateItem(key: '12', quantity: 2);
      final second = repository.updateItem(key: '12', quantity: 3);
      final firstResult = expectLater(
        first,
        throwsA(isA<CartRepositoryException>()),
      );
      final secondResult = expectLater(
        second,
        throwsA(isA<CartRepositoryException>()),
      );
      await Future<void>.delayed(Duration.zero);
      await client.clearLocalSession();
      merchant.pauseCart!.complete();
      await Future.wait([firstResult, secondResult]);
      expect(
        merchant.requests
            .where((r) => r.uri.path.endsWith('/cart/items/12'))
            .length,
        1,
      );
      expect(client.isAuthenticated, isFalse);
    },
  );

  test('failed write is not retried automatically', () async {
    final merchant = OdooMerchant100('alpha.odoo.example.invalid');
    final client = odooTestClient100(merchant);
    addTearDown(client.close);
    await client.session();
    merchant.status = 409;
    await expectLater(
      client.addCartItem85(productId: 7, quantity: 1),
      throwsA(isA<OdooCustomerException51>()),
    );
    expect(
      merchant.requests.where((r) => r.uri.path.endsWith('/cart/items')).length,
      1,
    );
  });

  for (final defect in ['owner', 'contract', 'image', 'amount', 'duplicate']) {
    test('rejects untrusted cart $defect', () async {
      final merchant = OdooMerchant100('alpha.odoo.example.invalid')..quantity = 1;
      final response = <String, dynamic>{
        'cart_contract_version': '85.1',
        'customer_id': null,
        'cart': merchant.cart,
      };
      final cart = response['cart'] as Map;
      switch (defect) {
        case 'owner':
          response['customer_id'] = 42;
        case 'contract':
          response['cart_contract_version'] = '999';
        case 'image':
          (cart['items'] as List).single['image_url'] =
              'https://another-store.example/image.png';
        case 'amount':
          (cart['totals'] as Map)['total_minor'] = '135.79';
        case 'duplicate':
          (cart['items'] as List).add((cart['items'] as List).single);
      }
      expect(
        () => OdooCart85.fromResponse(
          response,
          customerId: null,
          origin: Uri.https(merchant.host),
        ),
        throwsFormatException,
      );
    });
  }
}
