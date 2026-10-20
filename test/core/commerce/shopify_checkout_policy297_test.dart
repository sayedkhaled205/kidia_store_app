import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/shopify_checkout_policy297.dart';
import 'package:mobishop_store_app/core/commerce/shopify_storefront_client.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_cart_gateway.dart';

const _cartId = 'gid://shopify/Cart/customer-cart?key=secret';

class _Transport implements ShopifyStorefrontCartTransport {
  String domain = 'https://store.example';
  String checkout = 'https://store.example/cart/c/customer-cart?key=secret';
  bool failBootstrap = false;
  int reads = 0;
  int writes = 0;

  Map<String, dynamic> get cart => {
    'id': _cartId,
    'checkoutUrl': checkout,
    'totalQuantity': 0,
    'updatedAt': '2026-10-20T00:00:00Z',
    'buyerIdentity': {'countryCode': 'EG'},
    'lines': {
      'nodes': [],
      'pageInfo': {'hasNextPage': false, 'endCursor': null},
    },
    'cost': {
      'subtotalAmount': {'amount': '0', 'currencyCode': 'EGP'},
      'totalAmount': {'amount': '0', 'currencyCode': 'EGP'},
      'subtotalAmountEstimated': false,
      'totalAmountEstimated': false,
    },
    'discountCodes': [],
  };

  @override
  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic> variables = const {},
  }) async {
    if (document.contains('MobileStoreCheckoutDomain')) {
      reads++;
      if (failBootstrap) throw const FormatException('bootstrap unavailable');
      expect(variables, isEmpty);
      return {
        'shop': {
          'primaryDomain': {'url': domain},
        },
      };
    }
    return {'cart': cart};
  }

  @override
  Future<Map<String, dynamic>> cartMutation(
    String document, {
    Map<String, dynamic> variables = const {},
  }) async {
    writes++;
    return {
      'cartCreate': {'cart': cart, 'userErrors': [], 'warnings': []},
    };
  }
}

void main() {
  final connection = CommerceConnection(
    platform: CommercePlatform.shopify,
    storeOrigin: Uri.parse('https://customer.myshopify.com'),
  );

  test('canonical checkout does not require a domain lookup', () async {
    final transport = _Transport()..failBootstrap = true;
    final policy = ShopifyCheckoutPolicy297(
      connection: connection,
      reader: transport,
    );
    await policy.verify(Uri.parse('https://customer.myshopify.com/cart/c/a'));
    expect(transport.reads, 0);
  });

  test(
    'custom checkout is allowed only after independent shop bootstrap',
    () async {
      final transport = _Transport();
      final policy = ShopifyCheckoutPolicy297(
        connection: connection,
        reader: transport,
      );
      await policy.verify(Uri.parse(transport.checkout));
      await policy.verify(Uri.parse(transport.checkout));
      expect(transport.reads, 1);
      await expectLater(
        policy.verify(Uri.parse('https://other.example/cart/c/a')),
        throwsFormatException,
      );
      expect(transport.reads, 1);
    },
  );

  for (final destination in [
    'http://store.example/cart/c/a',
    'https://user:pass@store.example/cart/c/a',
    'https://store.example:9443/cart/c/a',
    'https://store.example/cart/c/a#token',
  ]) {
    test('reject unsafe checkout $destination before network', () async {
      final transport = _Transport();
      final policy = ShopifyCheckoutPolicy297(
        connection: connection,
        reader: transport,
      );
      await expectLater(
        policy.verify(Uri.parse(destination)),
        throwsFormatException,
      );
      expect(transport.reads, 0);
    });
  }

  for (final domain in [
    'http://store.example',
    'https://u:p@store.example',
    'https://store.example:9443',
    'https://store.example/path',
    'https://store.example?redirect=x',
  ]) {
    test('reject invalid primary domain $domain', () async {
      final transport = _Transport()..domain = domain;
      final policy = ShopifyCheckoutPolicy297(
        connection: connection,
        reader: transport,
      );
      await expectLater(
        policy.verify(Uri.parse(transport.checkout)),
        throwsFormatException,
      );
    });
  }

  test('failed bootstrap retries and never sends a cart write', () async {
    final transport = _Transport()..failBootstrap = true;
    final gateway = ShopifyCartGateway(
      transport: transport,
      connection: connection,
    );
    await expectLater(gateway.createCart(), throwsFormatException);
    expect(transport.writes, 0);
    transport.failBootstrap = false;
    final result = await gateway.createCart();
    expect(result.accepted, isTrue);
    expect(result.cart!.checkoutUrl, Uri.parse(transport.checkout));
    expect(transport.reads, 2);
    expect(transport.writes, 1);
  });

  test(
    'read existing custom-domain cart accepts exact bootstrap host',
    () async {
      final transport = _Transport();
      final gateway = ShopifyCartGateway(
        transport: transport,
        connection: connection,
      );
      expect(
        (await gateway.getCart(_cartId)).checkoutUrl,
        Uri.parse(transport.checkout),
      );
      transport.checkout = 'https://foreign.example/cart/c/a';
      await expectLater(gateway.getCart(_cartId), throwsFormatException);
      expect(transport.writes, 0);
    },
  );
}
