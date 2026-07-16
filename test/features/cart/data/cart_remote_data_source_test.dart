import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:kidia_store_app/features/cart/data/network/cart_api_transport.dart';
import 'package:kidia_store_app/features/cart/data/network/cart_token_store.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';

import 'cart_test_fixture.dart';

void main() {
  group('StoreApiCartRemoteDataSource', () {
    test('bootstraps with StoreApiClient then reuses Cart-Token', () async {
      final _FakeStoreApiClient client = _FakeStoreApiClient(<StoreApiResponse>[
        _cartResponse(token: 'token-1'),
      ]);
      final _FakeCartApiTransport transport = _FakeCartApiTransport(<Object>[
        _cartResponse(token: 'token-1'),
      ]);
      final MemoryCartTokenStore tokens = MemoryCartTokenStore();
      final StoreApiCartRemoteDataSource source = StoreApiCartRemoteDataSource(
        storeApiClient: client,
        transport: transport,
        tokenStore: tokens,
      );

      await source.fetchCart();
      await source.fetchCart();

      expect(client.paths, <String>['/wp-json/wc/store/v1/cart']);
      expect(tokens.read(), 'token-1');
      expect(transport.requests.single.method, CartApiMethod.get);
      expect(transport.requests.single.headers['Cart-Token'], 'token-1');
    });

    test('bootstraps before mutation and captures a rotated token', () async {
      final _FakeStoreApiClient client = _FakeStoreApiClient(<StoreApiResponse>[
        _cartResponse(token: 'token-1'),
      ]);
      final _FakeCartApiTransport transport = _FakeCartApiTransport(<Object>[
        _cartResponse(token: 'token-2'),
      ]);
      final MemoryCartTokenStore tokens = MemoryCartTokenStore();
      final StoreApiCartRemoteDataSource source = StoreApiCartRemoteDataSource(
        storeApiClient: client,
        transport: transport,
        tokenStore: tokens,
      );

      await source.addItem(
        productId: 42,
        quantity: 2,
        variation: const <CartItemVariation>[
          CartItemVariation(attribute: 'pa_size', value: 'm'),
        ],
      );

      final _CartRequest request = transport.requests.single;
      expect(request.method, CartApiMethod.post);
      expect(request.path, '/wp-json/wc/store/v1/cart/add-item');
      expect(request.headers['Cart-Token'], 'token-1');
      expect(request.body?['id'], 42);
      expect(request.body?['quantity'], 2);
      expect(
        (request.body?['variation'] as List<dynamic>).single,
        <String, String>{'attribute': 'pa_size', 'value': 'm'},
      );
      expect(tokens.read(), 'token-2');
    });

    test(
      'uses official Store API endpoints for item and coupon changes',
      () async {
        final MemoryCartTokenStore tokens = MemoryCartTokenStore()
          ..write('session-token');
        final _FakeCartApiTransport transport = _FakeCartApiTransport(
          List<Object>.filled(4, _cartResponse(token: 'session-token')),
        );
        final StoreApiCartRemoteDataSource source =
            StoreApiCartRemoteDataSource(
              storeApiClient: _FakeStoreApiClient(const <StoreApiResponse>[]),
              transport: transport,
              tokenStore: tokens,
            );

        await source.updateItem(key: 'item-key', quantity: 3);
        await source.removeItem('item-key');
        await source.applyCoupon('SAVE10');
        await source.removeCoupon('SAVE10');

        expect(
          transport.requests.map((_CartRequest value) => value.path),
          <String>[
            '/wp-json/wc/store/v1/cart/update-item',
            '/wp-json/wc/store/v1/cart/remove-item',
            '/wp-json/wc/store/v1/cart/apply-coupon',
            '/wp-json/wc/store/v1/cart/remove-coupon',
          ],
        );
        expect(transport.requests[0].body, <String, dynamic>{
          'key': 'item-key',
          'quantity': 3,
        });
        expect(transport.requests[2].body, <String, dynamic>{'code': 'SAVE10'});
      },
    );

    test('preserves the server cart carried by a 409 conflict', () async {
      final MemoryCartTokenStore tokens = MemoryCartTokenStore()
        ..write('session-token');
      final _FakeCartApiTransport transport = _FakeCartApiTransport(<Object>[
        CartApiTransportException(
          message: 'Conflict',
          statusCode: 409,
          data: <String, dynamic>{
            'code': 'woocommerce_rest_cart_invalid_key',
            'message': 'Cart item no longer exists.',
            'data': <String, dynamic>{
              'status': 409,
              'cart': cartJsonFixture(totalPrice: '9000'),
            },
          },
        ),
      ]);
      final StoreApiCartRemoteDataSource source = StoreApiCartRemoteDataSource(
        storeApiClient: _FakeStoreApiClient(const <StoreApiResponse>[]),
        transport: transport,
        tokenStore: tokens,
      );

      try {
        await source.updateItem(key: 'stale-key', quantity: 2);
        fail('Expected a conflict.');
      } on CartRemoteException catch (error) {
        expect(error.kind, CartFailureKind.conflict);
        expect(error.apiError?.code, 'woocommerce_rest_cart_invalid_key');
        expect(error.serverCart?.totals.priceMinor, '9000');
      }
    });
  });
}

StoreApiResponse _cartResponse({required String token}) {
  return StoreApiResponse(
    data: cartJsonFixture(),
    statusCode: 200,
    headers: <String, List<String>>{
      'cart-token': <String>[token],
    },
  );
}

class _FakeStoreApiClient implements StoreApiClient {
  _FakeStoreApiClient(this._responses);

  final List<StoreApiResponse> _responses;
  final List<String> paths = <String>[];
  int _index = 0;

  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    paths.add(path);
    if (_index >= _responses.length) {
      throw StateError('No StoreApiClient response queued.');
    }
    return _responses[_index++];
  }
}

class _CartRequest {
  const _CartRequest({
    required this.method,
    required this.path,
    required this.body,
    required this.headers,
  });

  final CartApiMethod method;
  final String path;
  final Map<String, dynamic>? body;
  final Map<String, String> headers;
}

class _FakeCartApiTransport implements CartApiTransport {
  _FakeCartApiTransport(this._responses);

  final List<Object> _responses;
  final List<_CartRequest> requests = <_CartRequest>[];
  int _index = 0;

  @override
  Future<StoreApiResponse> request(
    CartApiMethod method,
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    requests.add(
      _CartRequest(
        method: method,
        path: path,
        body: body == null ? null : Map<String, dynamic>.from(body),
        headers: Map<String, String>.from(headers ?? const <String, String>{}),
      ),
    );
    if (_index >= _responses.length) {
      throw StateError('No CartApiTransport response queued.');
    }
    final Object response = _responses[_index++];
    if (response is CartApiTransportException) {
      throw response;
    }
    return response as StoreApiResponse;
  }
}
