import 'dart:async';

import 'package:kidia_store_app/features/cart/data/models/cart_model.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:kidia_store_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:kidia_store_app/features/checkout/data/network/checkout_api_transport.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_submission.dart';
import 'package:kidia_store_app/features/checkout/domain/repositories/checkout_repository.dart';

typedef CheckoutLoadCallback = Future<CheckoutState> Function();
typedef CheckoutSubmitCallback =
    Future<CheckoutOrderResult> Function(CheckoutSubmission submission);
typedef CheckoutCustomerUpdateCallback =
    Future<Cart> Function(
      CheckoutAddress billingAddress,
      CheckoutAddress shippingAddress,
    );

class FakeCheckoutRepository implements CheckoutRepository {
  FakeCheckoutRepository({
    CheckoutState? state,
    this.onLoad,
    this.onSubmit,
    this.onUpdateCustomer,
  }) : state = state ?? CheckoutState(cart: checkoutCart());

  CheckoutState state;
  CheckoutLoadCallback? onLoad;
  CheckoutSubmitCallback? onSubmit;
  CheckoutCustomerUpdateCallback? onUpdateCustomer;
  int loadCalls = 0;
  int submitCalls = 0;
  int updateCustomerCalls = 0;
  final List<CheckoutSubmission> submissions = <CheckoutSubmission>[];

  @override
  Future<CheckoutState> loadCheckout() async {
    loadCalls++;
    final CheckoutLoadCallback? callback = onLoad;
    return callback == null ? state : callback();
  }

  @override
  Future<Cart> updateCustomer({
    required CheckoutAddress billingAddress,
    required CheckoutAddress shippingAddress,
  }) async {
    updateCustomerCalls++;
    final CheckoutCustomerUpdateCallback? callback = onUpdateCustomer;
    return callback == null
        ? state.cart
        : callback(billingAddress, shippingAddress);
  }

  @override
  Future<CheckoutOrderResult> placeOrder(CheckoutSubmission submission) async {
    submitCalls++;
    submissions.add(submission);
    final CheckoutSubmitCallback? callback = onSubmit;
    if (callback != null) {
      return callback(submission);
    }
    return checkoutOrderResult;
  }
}

class FakeCheckoutCartRepository implements CartRepository {
  FakeCheckoutCartRepository({required this.cart, this.onGetCart});

  Cart cart;
  Future<Cart> Function()? onGetCart;
  int getCartCalls = 0;

  @override
  Future<Cart> getCart() async {
    getCartCalls++;
    return onGetCart == null ? cart : onGetCart!();
  }

  @override
  Future<Cart> addItem({
    required int productId,
    int quantity = 1,
    List<CartItemVariation> variation = const <CartItemVariation>[],
  }) async => cart;

  @override
  Future<Cart> updateItem({required String key, required int quantity}) async =>
      cart;

  @override
  Future<Cart> removeItem(String key) async => cart;

  @override
  Future<Cart> applyCoupon(String code) async => cart;

  @override
  Future<Cart> removeCoupon(String code) async => cart;
}

class FakeCheckoutTransport implements CheckoutApiTransport {
  CheckoutApiResponse configurationResponse = const CheckoutApiResponse(
    data: <String, dynamic>{'version': 1, 'fields': <dynamic>[]},
  );
  CheckoutApiResponse response = const CheckoutApiResponse(
    data: <String, dynamic>{
      'order_id': 730,
      'status': 'processing',
      'payment_result': <String, dynamic>{
        'payment_status': 'success',
        'redirect_url': '',
      },
    },
  );
  Object? error;
  Future<CheckoutApiResponse> Function()? onPlaceOrder;
  Future<CheckoutApiResponse> Function()? onUpdateCustomer;
  int calls = 0;
  int updateCustomerCalls = 0;
  int configurationCalls = 0;
  final List<String> cartTokens = <String>[];
  final List<String> idempotencyKeys = <String>[];
  final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> customerBodies = <Map<String, dynamic>>[];

  @override
  Future<CheckoutApiResponse> loadConfiguration() async {
    configurationCalls++;
    return configurationResponse;
  }

  @override
  Future<CheckoutApiResponse> updateCustomer({
    required String cartToken,
    required Map<String, dynamic> body,
  }) async {
    updateCustomerCalls++;
    cartTokens.add(cartToken);
    customerBodies.add(Map<String, dynamic>.from(body));
    final Object? currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    final Future<CheckoutApiResponse> Function()? callback = onUpdateCustomer;
    return callback == null
        ? CheckoutApiResponse(data: checkoutCartJson())
        : callback();
  }

  @override
  Future<CheckoutApiResponse> placeOrder({
    required String cartToken,
    required String idempotencyKey,
    required Map<String, dynamic> body,
  }) async {
    calls++;
    cartTokens.add(cartToken);
    idempotencyKeys.add(idempotencyKey);
    bodies.add(Map<String, dynamic>.from(body));
    final Object? currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    final Future<CheckoutApiResponse> Function()? callback = onPlaceOrder;
    return callback == null ? response : callback();
  }
}

const CheckoutOrderResult checkoutOrderResult = CheckoutOrderResult(
  orderId: 730,
  status: 'processing',
  paymentStatus: 'success',
);

Cart checkoutCart({
  bool empty = false,
  bool needsPayment = true,
  bool needsShipping = true,
  List<String> paymentMethods = const <String>['cod'],
  String totalPrice = '12500',
}) {
  return CartModel.fromJson(
    checkoutCartJson(
      empty: empty,
      needsPayment: needsPayment,
      needsShipping: needsShipping,
      paymentMethods: paymentMethods,
      totalPrice: totalPrice,
    ),
  ).toEntity();
}

Map<String, dynamic> checkoutCartJson({
  bool empty = false,
  bool needsPayment = true,
  bool needsShipping = true,
  List<String> paymentMethods = const <String>['cod'],
  String totalPrice = '12500',
}) {
  const Map<String, dynamic> currency = <String, dynamic>{
    'currency_code': 'USD',
    'currency_symbol': r'$',
    'currency_minor_unit': 2,
    'currency_decimal_separator': '.',
    'currency_thousand_separator': ',',
    'currency_prefix': r'$',
    'currency_suffix': '',
  };
  return <String, dynamic>{
    'items': empty
        ? <dynamic>[]
        : <dynamic>[
            <String, dynamic>{
              'key': 'item-key',
              'id': 38,
              'quantity': 2,
              'quantity_limits': <String, dynamic>{
                'minimum': 1,
                'maximum': 10,
                'multiple_of': 1,
                'editable': true,
              },
              'name': 'Checkout Product',
              'short_description': '',
              'sku': 'CO-38',
              'backorders_allowed': false,
              'show_backorder_badge': false,
              'sold_individually': false,
              'images': <dynamic>[],
              'variation': <dynamic>[],
              'prices': <String, dynamic>{
                'price': '5000',
                'regular_price': '5000',
                'sale_price': '5000',
                ...currency,
              },
              'totals': <String, dynamic>{
                'line_subtotal': '10000',
                'line_subtotal_tax': '0',
                'line_total': '10000',
                'line_total_tax': '0',
                ...currency,
              },
            },
          ],
    'coupons': <dynamic>[],
    'totals': <String, dynamic>{
      'total_items': empty ? '0' : '10000',
      'total_items_tax': '0',
      'total_fees': '0',
      'total_fees_tax': '0',
      'total_discount': '0',
      'total_discount_tax': '0',
      'total_shipping': empty ? '0' : '2500',
      'total_shipping_tax': '0',
      'total_price': empty ? '0' : totalPrice,
      'total_tax': '0',
      ...currency,
    },
    'shipping_address': <String, dynamic>{
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'address_1': '1 Market Street',
      'city': 'London',
      'postcode': 'SW1A',
      'country': 'GB',
    },
    'billing_address': <String, dynamic>{
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'address_1': '1 Market Street',
      'city': 'London',
      'postcode': 'SW1A',
      'country': 'GB',
      'email': 'ada@example.com',
      'phone': '12345',
    },
    'items_count': empty ? 0 : 2,
    'items_weight': 0,
    'needs_payment': needsPayment,
    'needs_shipping': needsShipping,
    'has_calculated_shipping': true,
    'payment_methods': paymentMethods,
    'errors': <dynamic>[],
  };
}

Future<void> waitForCondition(bool Function() condition) async {
  for (int attempt = 0; attempt < 50; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Timed out waiting for an asynchronous test condition.');
}
