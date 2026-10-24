import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_session_store51.dart';
import 'package:mobishop_store_app/features/cart/data/odoo/odoo_cart85.dart';
import 'package:mobishop_store_app/features/cart/data/repositories/odoo_cart_repository85.dart';
import 'package:mobishop_store_app/features/cart/domain/repositories/cart_repository.dart';

class _Merchant implements HttpClientAdapter {
  _Merchant(this.host);
  final String host;
  final requests = <RequestOptions>[];
  int quantity = 0;
  int status = 200;
  bool enabled = true;
  bool malformedCapabilities = false;
  Completer<void>? pauseCart;
  void Function(Map<String, dynamic>)? alterCart;
  String get sid => '${host.split('.').first}_guest_session_1234567890';

  Map<String, dynamic> get cart => {
    'revision': List.filled(64, 'a').join(),
    'currency': {'code': 'EGP', 'symbol': 'EGP', 'minor_unit': 2},
    'items': [
      if (quantity > 0)
        {
          'line_id': 12,
          'product_id': 7,
          'quantity': quantity,
          'name': 'Store-priced item',
          'sku': 'SKU-7',
          'image_url': 'https://$host/web/image/product.product/7/image_512',
          'unit_price_minor': '12345',
          'subtotal_minor': '${12345 * quantity}',
          'tax_minor': '${1234 * quantity}',
          'total_minor': '${13579 * quantity}',
          'quantity_limit': {
            'minimum': 1,
            'maximum': 9,
            'multiple_of': 1,
            'editable': true,
          },
          'backorders_allowed': false,
          'stock_remaining': 9,
        },
    ],
    'totals': {
      'untaxed_minor': '${12345 * quantity}',
      'tax_minor': '${1234 * quantity}',
      'total_minor': '${13579 * quantity}',
      'items_minor': '${12345 * quantity}',
      'items_tax_minor': '${1234 * quantity}',
      'shipping_minor': '0',
      'shipping_tax_minor': '0',
    },
    for (final group in ['billing_address', 'shipping_address'])
      group: {
        for (final field in [
          'first_name',
          'last_name',
          'company',
          'address_1',
          'address_2',
          'city',
          'state',
          'postcode',
          'country',
          'email',
          'phone',
        ])
          field: '',
      },
    'needs_shipping': quantity > 0,
    'has_calculated_shipping': false,
    'checkout_zero_total': false,
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    expect(options.uri.host, host);
    expect(options.followRedirects, isFalse);
    expect(options.headers.containsKey('Authorization'), isFalse);
    final endpoint = options.uri.path.replaceFirst(
      '/api/mobile/v1/customer/',
      '',
    );
    final body = <String, dynamic>{
      'platform': 'odoo',
      'contract_version': '51.1',
      'ok': status == 200,
    };
    if (endpoint == 'session') {
      body.addAll({
        'customer': null,
        'auth': {
          'protocol': 'odoo_session_cookie',
          'authenticated': false,
          'csrf_token': 'csrf_fixture_123456',
        },
        'capabilities': {
          'profile': true,
          'addresses': true,
          'orders': true,
          'register': false,
          'push': false,
          'cart': enabled,
          'checkout': enabled,
          if (enabled) 'free_checkout': malformedCapabilities ? 'true' : true,
          if (enabled) 'payment_handoff': true,
        },
        if (enabled) 'cart_contract_version': '85.1',
      });
    } else if (endpoint.startsWith('cart')) {
      if (pauseCart != null) await pauseCart!.future;
      expect(options.headers['Cookie'], 'session_id=$sid');
      if (options.method == 'POST') {
        final data = options.data as Map;
        expect(data['csrf_token'], 'csrf_fixture_123456');
        final payload = jsonDecode(data['payload'] as String) as Map;
        if (status == 200) {
          if (endpoint == 'cart/items') {
            expect(payload['product_id'], 7);
            quantity += payload['quantity'] as int;
          } else {
            expect(endpoint, 'cart/items/12');
            quantity = payload['quantity'] as int;
          }
        }
      }
      body.addAll({
        'cart_contract_version': '85.1',
        'customer_id': null,
        'cart': cart,
      });
      alterCart?.call(body);
    }
    if (status != 200) body['error'] = {'code': 'cart_operation_rejected'};
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'set-cookie': [
          'session_id=$sid; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=3600',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

OdooCustomerClient51 _client(
  _Merchant merchant, {
  OdooCustomerSessionStore51? storage,
}) => OdooCustomerClient51(
  connection: CommerceConnection(
    platform: CommercePlatform.odoo,
    storeOrigin: Uri.https(merchant.host),
  ),
  adapter: merchant,
  sessionStore: storage,
);

void main() {
  for (final host in [
    'alpha.odoo.example.invalid',
    'beta.odoo.example.invalid',
  ]) {
    test(
      '$host guest add/update/remove uses exact server quote and session',
      () async {
        final merchant = _Merchant(host);
        final client = _client(merchant);
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
    final merchant = _Merchant('alpha.odoo.example.invalid');
    final storage = MemoryOdooCustomerSessionStore51();
    final first = _client(merchant, storage: storage);
    await first.addCartItem85(productId: 7, quantity: 1);
    first.close();
    expect((await storage.read())!.isGuest, isTrue);
    final second = _client(merchant, storage: storage);
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
    final merchant = _Merchant('alpha.odoo.example.invalid')..enabled = false;
    final client = _client(merchant);
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
    final merchant = _Merchant('alpha.odoo.example.invalid');
    final client = _client(merchant);
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
      final merchant = _Merchant('alpha.odoo.example.invalid');
      final client = _client(merchant);
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
    final merchant = _Merchant('alpha.odoo.example.invalid');
    final client = _client(merchant);
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
      final merchant = _Merchant('alpha.odoo.example.invalid')..quantity = 1;
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
