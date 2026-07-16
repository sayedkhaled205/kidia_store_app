import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/cart/data/network/cart_token_store.dart';
import 'package:kidia_store_app/features/checkout/data/network/checkout_api_transport.dart';
import 'package:kidia_store_app/features/checkout/data/repositories/store_api_checkout_repository.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_submission.dart';
import 'package:kidia_store_app/features/checkout/domain/repositories/checkout_repository.dart';

import '../support/checkout_test_data.dart';

void main() {
  test(
    'loads payment requirements and method ids from the cart Store API',
    () async {
      final StoreApiCheckoutRepository repository = StoreApiCheckoutRepository(
        cartRepository: FakeCheckoutCartRepository(
          cart: checkoutCart(paymentMethods: <String>['cod', 'bacs', 'cod']),
        ),
        transport: FakeCheckoutTransport(),
        cartTokenStore: MemoryCartTokenStore(),
      );

      final state = await repository.loadCheckout();

      expect(state.needsPayment, isTrue);
      expect(state.needsShipping, isTrue);
      expect(state.paymentMethodIds, <String>['cod', 'bacs']);
      expect(state.cart.itemsCount, 2);
    },
  );

  test(
    'loads checkout fields filtered by installed WooCommerce plugins',
    () async {
      final FakeCheckoutTransport transport = FakeCheckoutTransport()
        ..configurationResponse = const CheckoutApiResponse(
          data: <String, dynamic>{
            'version': 1,
            'fields': <dynamic>[
              <String, dynamic>{
                'key': 'billing_vat_number',
                'group': 'billing',
                'type': 'text',
                'label': 'VAT number',
                'required': true,
                'priority': 35,
              },
            ],
          },
        );
      final StoreApiCheckoutRepository repository = StoreApiCheckoutRepository(
        cartRepository: FakeCheckoutCartRepository(cart: checkoutCart()),
        transport: transport,
        cartTokenStore: MemoryCartTokenStore(),
      );

      final state = await repository.loadCheckout();

      expect(state.hasDynamicFields, isTrue);
      expect(state.fieldDefinitions.single.key, 'billing_vat_number');
      expect(state.fieldDefinitions.single.required, isTrue);
      expect(transport.configurationCalls, 1);
    },
  );

  test('places a standard checkout without card or gateway secrets', () async {
    final MemoryCartTokenStore tokenStore = MemoryCartTokenStore()
      ..write('cart-token-1');
    final FakeCheckoutTransport transport = FakeCheckoutTransport()
      ..response = const CheckoutApiResponse(
        data: <String, dynamic>{
          'order_id': 88,
          'status': 'pending',
          'payment_result': <String, dynamic>{
            'payment_status': 'pending',
            'redirect_url': 'https://payments.example.com/order/88',
          },
        },
      );
    final StoreApiCheckoutRepository repository = StoreApiCheckoutRepository(
      cartRepository: FakeCheckoutCartRepository(cart: checkoutCart()),
      transport: transport,
      cartTokenStore: tokenStore,
    );

    final CheckoutOrderResult result = await repository.placeOrder(
      _submission('request-1'),
    );

    expect(result.orderId, 88);
    expect(result.requiresRedirect, isTrue);
    expect(transport.cartTokens.single, 'cart-token-1');
    expect(transport.idempotencyKeys.single, 'request-1');
    final Map<String, dynamic> body = transport.bodies.single;
    expect(body['payment_method'], 'cod');
    expect(body['customer_note'], 'Leave at reception');
    expect(body['payment_data'], isEmpty);
    expect(body, isNot(contains('card_number')));
    expect(
      (body['billing_address'] as Map<String, String>)['email'],
      'ada@example.com',
    );
  });

  test(
    'submits safe custom checkout plugin fields through Store API',
    () async {
      final FakeCheckoutTransport transport = FakeCheckoutTransport();
      final StoreApiCheckoutRepository repository = StoreApiCheckoutRepository(
        cartRepository: FakeCheckoutCartRepository(cart: checkoutCart()),
        transport: transport,
        cartTokenStore: (MemoryCartTokenStore()..write('token')),
      );

      await repository.placeOrder(
        _submission(
          'custom-fields',
          customFields: const <String, String>{'billing_vat_number': 'EG-123'},
        ),
      );

      final Map<String, dynamic> body = transport.bodies.single;
      expect(body['additional_fields'], <String, String>{
        'billing_vat_number': 'EG-123',
      });
      expect(
        ((body['extensions'] as Map<String, dynamic>)['woo_mobile_cms']
            as Map<String, dynamic>)['checkout_fields'],
        <String, String>{'billing_vat_number': 'EG-123'},
      );
    },
  );

  test('bootstraps the shared Cart-Token once when needed', () async {
    final MemoryCartTokenStore tokenStore = MemoryCartTokenStore();
    late FakeCheckoutCartRepository cartRepository;
    cartRepository = FakeCheckoutCartRepository(
      cart: checkoutCart(),
      onGetCart: () async {
        tokenStore.write('bootstrapped-token');
        return cartRepository.cart;
      },
    );
    final FakeCheckoutTransport transport = FakeCheckoutTransport();
    final StoreApiCheckoutRepository repository = StoreApiCheckoutRepository(
      cartRepository: cartRepository,
      transport: transport,
      cartTokenStore: tokenStore,
    );

    await repository.placeOrder(_submission('request-2'));

    expect(cartRepository.getCartCalls, 1);
    expect(transport.cartTokens.single, 'bootstrapped-token');
  });

  test(
    'serializes duplicate submissions and reuses a successful result',
    () async {
      final Completer<CheckoutApiResponse> response =
          Completer<CheckoutApiResponse>();
      final FakeCheckoutTransport transport = FakeCheckoutTransport()
        ..onPlaceOrder = () => response.future;
      final StoreApiCheckoutRepository repository = StoreApiCheckoutRepository(
        cartRepository: FakeCheckoutCartRepository(cart: checkoutCart()),
        transport: transport,
        cartTokenStore: (MemoryCartTokenStore()..write('token')),
      );
      final CheckoutSubmission submission = _submission('same-key');

      final Future<CheckoutOrderResult> first = repository.placeOrder(
        submission,
      );
      final Future<CheckoutOrderResult> second = repository.placeOrder(
        submission,
      );
      await waitForCondition(() => transport.calls == 1);
      response.complete(
        const CheckoutApiResponse(
          data: <String, dynamic>{
            'order_id': 91,
            'status': 'processing',
            'payment_result': <String, dynamic>{'payment_status': 'success'},
          },
        ),
      );

      expect((await first).orderId, 91);
      expect((await second).orderId, 91);
      expect(transport.calls, 1);
    },
  );

  test('surfaces the authoritative cart from a 409 response', () async {
    final FakeCheckoutTransport transport = FakeCheckoutTransport()
      ..error = CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.rejected,
        message: 'Conflict',
        statusCode: 409,
        data: <String, dynamic>{
          'code': 'woocommerce_rest_cart_changed',
          'message': 'Cart changed on the server.',
          'data': <String, dynamic>{
            'status': 409,
            'cart': checkoutCartJson(totalPrice: '15500'),
          },
        },
      );
    final StoreApiCheckoutRepository repository = StoreApiCheckoutRepository(
      cartRepository: FakeCheckoutCartRepository(cart: checkoutCart()),
      transport: transport,
      cartTokenStore: (MemoryCartTokenStore()..write('token')),
    );

    await expectLater(
      repository.placeOrder(_submission('conflict-key')),
      throwsA(
        isA<CheckoutRepositoryException>()
            .having(
              (CheckoutRepositoryException error) => error.kind,
              'kind',
              CheckoutFailureKind.conflict,
            )
            .having(
              (CheckoutRepositoryException error) =>
                  error.authoritativeCart?.totals.priceMinor,
              'authoritative total',
              '15500',
            ),
      ),
    );
  });

  test('rejects invalid standard fields before contacting the store', () async {
    final FakeCheckoutTransport transport = FakeCheckoutTransport();
    final StoreApiCheckoutRepository repository = StoreApiCheckoutRepository(
      cartRepository: FakeCheckoutCartRepository(cart: checkoutCart()),
      transport: transport,
      cartTokenStore: (MemoryCartTokenStore()..write('token')),
    );
    final CheckoutSubmission invalid = CheckoutSubmission(
      billingAddress: const CheckoutAddress(),
      shippingAddress: const CheckoutAddress(),
      customerNote: '',
      paymentMethodId: 'cod',
      idempotencyKey: 'valid-key',
    );

    await expectLater(
      repository.placeOrder(invalid),
      throwsA(
        isA<CheckoutRepositoryException>().having(
          (CheckoutRepositoryException error) => error.kind,
          'kind',
          CheckoutFailureKind.invalidInput,
        ),
      ),
    );
    expect(transport.calls, 0);
  });

  test('turns a malformed 409 body into a safe conflict error', () async {
    final FakeCheckoutTransport transport = FakeCheckoutTransport()
      ..error = const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.rejected,
        message: 'Checkout conflict.',
        statusCode: 409,
        data: <String, dynamic>{'data': 'not-an-object'},
      );
    final StoreApiCheckoutRepository repository = StoreApiCheckoutRepository(
      cartRepository: FakeCheckoutCartRepository(cart: checkoutCart()),
      transport: transport,
      cartTokenStore: (MemoryCartTokenStore()..write('token')),
    );

    await expectLater(
      repository.placeOrder(_submission('malformed-conflict')),
      throwsA(
        isA<CheckoutRepositoryException>()
            .having(
              (CheckoutRepositoryException error) => error.kind,
              'kind',
              CheckoutFailureKind.conflict,
            )
            .having(
              (CheckoutRepositoryException error) => error.authoritativeCart,
              'authoritative cart',
              isNull,
            ),
      ),
    );
  });

  test(
    'rejects unsafe header tokens before making a network request',
    () async {
      final StoreApiCheckoutTransport transport = StoreApiCheckoutTransport(
        storeUri: Uri.parse('https://shop.example.com'),
      );

      await expectLater(
        transport.placeOrder(
          cartToken: 'token\nInjected: value',
          idempotencyKey: 'safe-key',
          body: const <String, dynamic>{},
        ),
        throwsA(
          isA<CheckoutApiTransportException>().having(
            (CheckoutApiTransportException error) => error.kind,
            'kind',
            CheckoutTransportFailureKind.configuration,
          ),
        ),
      );
    },
  );
}

CheckoutSubmission _submission(
  String key, {
  Map<String, String> customFields = const <String, String>{},
}) {
  const CheckoutAddress address = CheckoutAddress(
    firstName: 'Ada',
    lastName: 'Lovelace',
    address1: '1 Market Street',
    city: 'London',
    postcode: 'SW1A',
    country: 'GB',
    email: 'ada@example.com',
    phone: '12345',
  );
  return CheckoutSubmission(
    billingAddress: address,
    shippingAddress: address,
    customerNote: 'Leave at reception',
    paymentMethodId: 'cod',
    idempotencyKey: key,
    customFields: customFields,
  );
}
