import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:mobishop_store_app/features/cart/data/network/cart_api_transport.dart';
import 'package:mobishop_store_app/features/cart/data/network/secure_cart_token_store.dart';

import 'cart_test_fixture.dart';

SecureCartTokenStore store({
  String url = 'https://fixture.test/shop',
  Future<CartTokenOwner?> Function()? owner,
}) => SecureCartTokenStore(
  storeUri: Uri.parse(url),
  currentOwner: owner ?? () async => null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'fresh process sends persisted guest token instead of creating empty cart',
    () async {
      final first = store();
      await first.restore();
      first.write('synthetic-guest-basket');
      await first.flush();
      final restarted = store();
      final network = _Network();
      final source = StoreApiCartRemoteDataSource(
        storeApiClient: network,
        transport: network,
        tokenStore: restarted,
      );
      final cart = await source.fetchCart();
      expect(cart.toEntity().itemsCount, 2);
      expect(network.headers.single['Cart-Token'], 'synthetic-guest-basket');
      expect(
        jsonDecode(
          (await const FlutterSecureStorage().read(key: restarted.storageKey))!,
        )['token'],
        'synthetic-rotated',
      );
    },
  );

  test('store and install paths do not share guest baskets', () async {
    final first = store();
    await first.restore();
    first.write('synthetic-guest');
    await first.flush();
    for (final origin in [
      'https://another.test/shop',
      'https://fixture.test/other',
    ]) {
      final other = store(url: origin);
      await other.restore();
      expect(other.read(), isNull);
    }
    final same = store(url: 'https://fixture.test/shop/');
    await same.restore();
    expect(same.read(), 'synthetic-guest');
  });

  test(
    'login promotes basket to owner and logout removes persisted credential',
    () async {
      final first = store();
      await first.restore();
      first.write('synthetic-guest');
      first.setOwner(CartTokenOwner(1, 'session-one'));
      await first.flush();
      expect(first.read(), 'synthetic-guest');
      first.write('synthetic-customer');
      await first.flush();
      final restarted = store(
        owner: () async => CartTokenOwner(1, 'session-one'),
      );
      await restarted.restore();
      expect(restarted.read(), 'synthetic-customer');
      first.clear();
      first.setOwner(null);
      await first.flush();
      final next = store();
      await next.restore();
      expect(next.read(), isNull);
    },
  );

  test(
    'restored signed-in session never adopts persisted guest credential',
    () async {
      final first = store();
      await first.restore();
      first.write('synthetic-guest');
      await first.flush();
      final signedIn = store(
        owner: () async => CartTokenOwner(1, 'session-one'),
      );
      await signedIn.restore();
      expect(signedIn.read(), isNull);
      expect(
        await const FlutterSecureStorage().read(key: first.storageKey),
        isNull,
      );
    },
  );

  for (final transition in ['clear', 'login']) {
    test(
      '$transition during restoration cannot revive old guest basket',
      () async {
        final initial = store();
        await initial.restore();
        initial.write('synthetic-old');
        await initial.flush();
        final identity = Completer<CartTokenOwner?>();
        final restarted = store(owner: () => identity.future);
        final pending = restarted.restore();
        if (transition == 'clear') {
          restarted.clear();
        } else {
          restarted.setOwner(CartTokenOwner(1, 'session-one'));
        }
        identity.complete(null);
        await pending;
        await restarted.flush();
        expect(restarted.read(), isNull);
        expect(
          await const FlutterSecureStorage().read(key: restarted.storageKey),
          isNull,
        );
      },
    );
  }

  test('clear queued after write wins across new store instance', () async {
    final first = store();
    await first.restore();
    first.write('synthetic-old');
    first.clear();
    final next = store();
    await next.restore();
    expect(next.read(), isNull);
  });

  test(
    'login followed immediately by restart retains the adopted guest cart',
    () async {
      final first = store();
      await first.restore();
      first.write('adopted-guest');
      first.setOwner(CartTokenOwner(1, 'session-one'));
      final restarted = store(
        owner: () async => CartTokenOwner(1, 'session-one'),
      );
      await restarted.restore();
      expect(restarted.read(), 'adopted-guest');
    },
  );

  for (final owner in [
    null,
    CartTokenOwner(2, 'session-two'),
    CartTokenOwner(1, 'different-session'),
  ]) {
    test(
      'cold start rejects cart outside the exact restored session: ${owner?.userId}/${owner == null}',
      () async {
        final first = store(
          owner: () async => CartTokenOwner(1, 'session-one'),
        );
        await first.restore();
        first.write('private-customer-cart');
        await first.flush();
        final restarted = store(owner: () async => owner);
        await restarted.restore();
        expect(restarted.read(), isNull);
        expect(
          await const FlutterSecureStorage().read(key: first.storageKey),
          isNull,
        );
      },
    );
  }

  test(
    'same-owner token rotation rebinds basket without storing auth tokens',
    () async {
      final first = store(owner: () async => CartTokenOwner(1, 'session-one'));
      await first.restore();
      first.write('customer-basket');
      first.setOwner(CartTokenOwner(1, 'session-two'));
      await first.flush();
      final encoded = await const FlutterSecureStorage().read(
        key: first.storageKey,
      );
      expect(encoded, isNot(contains('session-one')));
      expect(encoded, isNot(contains('session-two')));
      final restarted = store(
        owner: () async => CartTokenOwner(1, 'session-two'),
      );
      await restarted.restore();
      expect(restarted.read(), 'customer-basket');
    },
  );

  test(
    'initial auth listener preserves matching customer disk basket',
    () async {
      final first = store(owner: () async => CartTokenOwner(1, 'session-one'));
      await first.restore();
      first.write('customer-basket');
      await first.flush();
      final identity = Completer<CartTokenOwner?>();
      final restarted = store(owner: () => identity.future);
      final restoring = restarted.restore();
      restarted.setOwner(CartTokenOwner(1, 'session-one'));
      identity.complete(CartTokenOwner(1, 'session-one'));
      await restoring;
      expect(restarted.read(), 'customer-basket');
    },
  );

  test(
    'switching customers clears basket before the new owner can read it',
    () async {
      final first = store(owner: () async => CartTokenOwner(1, 'session-one'));
      await first.restore();
      first.write('private-customer-cart');
      first.setOwner(CartTokenOwner(2, 'session-two'));
      expect(first.read(), isNull);
      await first.flush();
      final restarted = store(
        owner: () async => CartTokenOwner(2, 'session-two'),
      );
      await restarted.restore();
      expect(restarted.read(), isNull);
    },
  );
}

class _Network implements StoreApiClient, CartApiTransport {
  final headers = <Map<String, String>>[];
  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => throw StateError('Restored cart must not bootstrap a new guest');
  @override
  Future<StoreApiResponse> request(
    CartApiMethod method,
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    expect(method, CartApiMethod.get);
    this.headers.add(headers ?? {});
    return StoreApiResponse(
      data: cartJsonFixture(itemsCount: 2),
      statusCode: 200,
      headers: const {
        'cart-token': ['synthetic-rotated'],
      },
    );
  }
}
