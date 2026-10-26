import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/shopify_storefront_client.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_cart_gateway.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_buyer_cart_session.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_cart_session_store.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_cart_variant_resolver.dart';
import 'package:mobishop_store_app/features/cart/data/repositories/shopify_cart_repository.dart';
import 'package:mobishop_store_app/features/cart/domain/repositories/cart_repository.dart';

const _cartId = 'gid://shopify/Cart/customer-cart?key=secret';

class _Transport implements ShopifyStorefrontCartTransport {
  String domain = 'https://store.example';
  String checkout = 'https://store.example/cart/c/customer-cart?key=secret';
  bool failBootstrap = false;
  int reads = 0;
  int writes = 0;
  bool uncertain = false;
  String currency = 'EGP';
  String amount = '0';

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
      'subtotalAmount': {'amount': amount, 'currencyCode': currency},
      'totalAmount': {'amount': amount, 'currencyCode': currency},
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
    if (uncertain) throw const FormatException("Lost response");
    return {
      'cartCreate': {'cart': cart, 'userErrors': [], 'warnings': []},
    };
  }
}

class _LockedStore extends MemoryShopifyCartSessionStore {
  bool locked = true;
  @override
  Future<ShopifyCartSessionRecord?> read() async {
    if (locked) throw StateError('OS storage locked');
    return super.read();
  }
}

void main() {
  final connection = CommerceConnection(
    platform: CommercePlatform.shopify,
    storeOrigin: Uri.parse('https://customer.myshopify.com'),
  );
  ShopifyCartRepository repository(
    _Transport transport,
    ShopifyBuyerCartSession session,
  ) => ShopifyCartRepository(
    connection: connection,
    session: session,
    gateway: ShopifyCartGateway(transport: transport, connection: connection),
    variantResolver: ShopifyCartVariantResolver(reader: transport),
  );
  for (final entry in {
    'INR': (2, '12.34', '1234'),
    'ZAR': (2, '12.34', '1234'),
    'SEK': (2, '12.34', '1234'),
    'VND': (0, '1234', '1234'),
    'CLP': (0, '1234', '1234'),
    'TND': (3, '1.234', '1234'),
    'JOD': (3, '1.234', '1234'),
  }.entries) {
    test('Shopify cart keeps exact ${entry.key} monetary values', () async {
      final transport = _Transport()
        ..currency = entry.key
        ..amount = entry.value.$2;
      final repo = repository(transport, ShopifyBuyerCartSession(connection));
      addTearDown(repo.dispose);
      final cart = await repo.getCart();
      expect(cart.totals.currency.minorUnit, entry.value.$1);
      expect(cart.totals.priceMinor, entry.value.$3);
    });
  }
  test(
    'bootstrap failure never dispatches and does not permanently lock cart creation',
    () async {
      final transport = _Transport()..failBootstrap = true;
      final store = MemoryShopifyCartSessionStore();
      final session = ShopifyBuyerCartSession(connection, storage: store);
      final repo = repository(transport, session);
      await expectLater(
        repo.getCart(),
        throwsA(isA<CartRepositoryException>()),
      );
      expect(transport.writes, 0);
      expect(session.creationUncertain, false);
      expect(store.record, isNull);
      transport.failBootstrap = false;
      await repo.getCart();
      expect(transport.writes, 1);
      expect(session.cartId, _cartId);
      await repo.getCart();
      expect(transport.writes, 1);
    },
  );
  test(
    'ambiguous dispatched creation stays blocked and is never replayed',
    () async {
      final transport = _Transport()..uncertain = true;
      final session = ShopifyBuyerCartSession(connection);
      final repo = repository(transport, session);
      await expectLater(
        repo.getCart(),
        throwsA(isA<CartRepositoryException>()),
      );
      expect(session.creationUncertain, true);
      await expectLater(
        repo.getCart(),
        throwsA(isA<CartRepositoryException>()),
      );
      expect(transport.writes, 1);
    },
  );
  test(
    'temporary storage failure can be retried without deleting a known cart',
    () async {
      final store = _LockedStore()
        ..record = const ShopifyCartSessionRecord(cartId: _cartId);
      final session = ShopifyBuyerCartSession(connection, storage: store);
      await expectLater(session.hydrate(0), throwsStateError);
      expect(store.record?.cartId, _cartId);
      store.locked = false;
      await session.hydrate(0);
      expect(session.cartId, _cartId);
      expect(session.needsReconciliation, true);
    },
  );
}
