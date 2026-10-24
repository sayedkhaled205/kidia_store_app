import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_session_store51.dart';

class OdooMerchant100 implements HttpClientAdapter {
  OdooMerchant100(this.host);
  final String host;
  final requests = <RequestOptions>[];
  int quantity = 0;
  int status = 200;
  bool enabled = true;
  bool checkoutFormEnabled = false;
  final checkoutPayloads = <Map<String, dynamic>>[];
  void Function(Map<String, dynamic>)? alterCheckout;
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
        if (checkoutFormEnabled) 'checkout_form_contract_version': '101.1',
        if (checkoutFormEnabled) 'shipping_contract_version': '100.1',
      });
    } else if (endpoint.startsWith('checkout/')) {
      expect(options.method, 'POST');
      expect(options.headers['Cookie'], 'session_id=$sid');
      final data = options.data as Map;
      expect(data['csrf_token'], 'csrf_fixture_123456');
      checkoutPayloads.add(
        Map<String, dynamic>.from(jsonDecode(data['payload'] as String) as Map),
      );
      if (pauseCart != null) await pauseCart!.future;
      body.addAll({
        'cart_contract_version': '85.1',
        'customer_id': null,
        'cart': cart,
        'checkout_form_contract_version': '101.1',
        'shipping_contract_version': '100.1',
        'address_type': 'billing',
        'separate_shipping_allowed': false,
        'use_same_address': true,
        'fields': [
          {
            'name': 'name',
            'label': 'Merchant name',
            'kind': 'text',
            'value': '',
            'required': true,
            'readonly': false,
            'choices': [],
          },
        ],
        'shipping_rates': [],
      });
      alterCheckout?.call(body);
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

OdooCustomerClient51 odooTestClient100(
  OdooMerchant100 merchant, {
  OdooCustomerSessionStore51? storage,
}) => OdooCustomerClient51(
  connection: CommerceConnection(
    platform: CommercePlatform.odoo,
    storeOrigin: Uri.https(merchant.host),
  ),
  adapter: merchant,
  sessionStore: storage,
);
