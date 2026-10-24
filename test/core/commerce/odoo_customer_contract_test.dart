import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_session_store51.dart';

// The public 51.1 envelope stays unchanged when the separately gated 85.1
// cart contract is enabled. No merchant fixture uses real customer credentials.
class _Store implements HttpClientAdapter {
  _Store(this.host, {this.cartEnabled = false});
  final String host;
  bool cartEnabled;
  bool authenticated = false;
  int customerId = 42;
  int status = 200;
  final requests = <RequestOptions>[];
  void Function(Map<String, dynamic>)? alter;
  Completer<void>? pauseProfile;

  String get sid =>
      '${host.split('.').first}_${authenticated ? 'buyer' : 'guest'}_session_1234567890';

  Map<String, dynamic> get profile => {
    'id': customerId,
    'partner_id': customerId + 100,
    'name': 'Fixture buyer',
    'email': 'buyer@$host',
    'login': 'buyer@$host',
    'phone': '',
    'mobile': '',
    'editable_fields': ['name', 'phone', 'mobile'],
    'address': {
      'id': customerId + 100,
      'type': 'contact',
      for (final key in [
        'name',
        'phone',
        'mobile',
        'street',
        'street2',
        'city',
        'zip',
        'country_code',
        'state_name',
      ])
        key: '',
      'country_id': null,
      'state_id': null,
    },
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
    final endpoint = options.uri.path.split('/').last;
    if (endpoint == 'profile' && pauseProfile != null) {
      await pauseProfile!.future;
    }
    if (endpoint == 'login') authenticated = true;
    if (endpoint == 'logout') authenticated = false;
    final body = <String, dynamic>{
      'platform': 'odoo',
      'contract_version': '51.1',
      'ok': status < 300,
      if (status >= 300) 'error': {'code': 'customer_session_required'},
      if (endpoint == 'login') 'refresh_csrf': true,
      if (endpoint == 'logout') 'logged_out': true,
      if (['session', 'login', 'profile'].contains(endpoint))
        'customer': authenticated ? profile : null,
      if (endpoint == 'session') ...{
        'auth': {
          'protocol': 'odoo_session_cookie',
          'authenticated': authenticated,
          'csrf_token': 'fixture_csrf_1234567890',
        },
        'capabilities': {
          'profile': true,
          'addresses': true,
          'orders': true,
          'register': false,
          'push': false,
          'cart': cartEnabled,
          'checkout': cartEnabled,
          if (cartEnabled) ...{'free_checkout': true, 'payment_handoff': true},
        },
        if (cartEnabled) 'cart_contract_version': '85.1',
      },
    };
    alter?.call(body);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'set-cookie': [
          'session_id=$sid; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=3600',
        ],
        if (status == 302) 'location': ['https://other.example.invalid/'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

OdooCustomerClient51 _client(
  _Store store, {
  OdooCustomerSessionStore51? storage,
}) => OdooCustomerClient51(
  connection: CommerceConnection(
    platform: CommercePlatform.odoo,
    storeOrigin: Uri.https(store.host),
  ),
  adapter: store,
  sessionStore: storage,
);

void main() {
  for (final host in [
    'alpha.odoo.example.invalid',
    'beta.odoo.example.invalid',
  ]) {
    for (final cart in [false, true]) {
      test('$host account works with cart capability $cart', () async {
        final store = _Store(host, cartEnabled: cart);
        final client = _client(store);
        addTearDown(client.close);
        expect((await client.session()).authenticated, isFalse);
        expect(
          (await client.login(
            login: 'buyer@$host',
            password: 'fixture-only',
          )).id,
          42,
        );
        expect((await client.profile()).email, 'buyer@$host');
        expect(client.isAuthenticated, isTrue);
        expect(
          store.requests.every(
            (r) =>
                !r.uri.path.contains('/cart') &&
                !r.uri.path.contains('/checkout'),
          ),
          isTrue,
        );
      });
    }
  }

  test(
    'server cart availability can change without breaking account restore',
    () async {
      final store = _Store('alpha.odoo.example.invalid');
      final storage = MemoryOdooCustomerSessionStore51();
      final first = _client(store, storage: storage);
      await first.login(login: 'buyer', password: 'fixture-only');
      first.close();
      store.cartEnabled = true;
      final restored = _client(store, storage: storage);
      addTearDown(restored.close);
      expect((await restored.restoreSession()).customer?.id, 42);
    },
  );

  for (final invalid in [
    'cart_type',
    'checkout_type',
    'missing_cart_version',
    'unknown_cart_version',
    'checkout_without_cart',
    'missing_free',
    'handoff_type',
    'inconsistent_checkout',
    'profile_permission',
  ]) {
    test('rejects malformed capability $invalid', () async {
      final store = _Store('alpha.odoo.example.invalid', cartEnabled: true);
      store.alter = (body) {
        final caps = body['capabilities'] as Map<String, dynamic>;
        switch (invalid) {
          case 'cart_type':
            caps['cart'] = 'true';
          case 'checkout_type':
            caps['checkout'] = 1;
          case 'missing_cart_version':
            body.remove('cart_contract_version');
          case 'unknown_cart_version':
            body['cart_contract_version'] = '999.0';
          case 'checkout_without_cart':
            caps['cart'] = false;
          case 'missing_free':
            caps.remove('free_checkout');
          case 'handoff_type':
            caps['payment_handoff'] = 'yes';
          case 'inconsistent_checkout':
            caps['checkout'] = false;
          case 'profile_permission':
            caps['profile'] = false;
        }
      };
      final client = _client(store);
      addTearDown(client.close);
      await expectLater(
        client.session(),
        throwsA(isA<OdooCustomerException51>()),
      );
      expect(client.isAuthenticated, isFalse);
      expect(store.requests, hasLength(1));
    });
  }

  test(
    'rejects a stored session from a different merchant before sending cookie',
    () async {
      final a = _Store('alpha.odoo.example.invalid');
      final storage = MemoryOdooCustomerSessionStore51();
      final first = _client(a, storage: storage);
      await first.login(login: 'buyer', password: 'fixture-only');
      first.close();
      final b = _Store('beta.odoo.example.invalid');
      final next = _client(b, storage: storage);
      addTearDown(next.close);
      expect((await next.restoreSession()).authenticated, isFalse);
      expect(b.requests, isEmpty);
    },
  );

  test(
    'changed customer during restore never exposes the new identity',
    () async {
      final store = _Store('alpha.odoo.example.invalid');
      final storage = MemoryOdooCustomerSessionStore51();
      final first = _client(store, storage: storage);
      await first.login(login: 'buyer', password: 'fixture-only');
      first.close();
      store.customerId = 99;
      final next = _client(store, storage: storage);
      addTearDown(next.close);
      await expectLater(
        next.restoreSession(),
        throwsA(isA<OdooCustomerException51>()),
      );
      expect(next.customer, isNull);
      expect(await storage.read(), isNull);
    },
  );

  test(
    'late profile response cannot restore a locally revoked customer',
    () async {
      final store = _Store('alpha.odoo.example.invalid');
      final client = _client(store);
      addTearDown(client.close);
      await client.login(login: 'buyer', password: 'fixture-only');
      store.pauseProfile = Completer<void>();
      final pending = client.profile();
      final rejected = expectLater(
        pending,
        throwsA(isA<OdooCustomerException51>()),
      );
      await Future<void>.delayed(Duration.zero);
      await client.clearLocalSession();
      store.pauseProfile!.complete();
      await rejected;
      expect(client.isAuthenticated, isFalse);
    },
  );

  for (final status in [302, 401, 403]) {
    test(
      'rejects redirect or expired session $status without another host request',
      () async {
        final store = _Store('alpha.odoo.example.invalid');
        final client = _client(store);
        addTearDown(client.close);
        await client.login(login: 'buyer', password: 'fixture-only');
        store.status = status;
        await expectLater(
          client.profile(),
          throwsA(isA<OdooCustomerException51>()),
        );
        expect(store.requests.every((r) => r.uri.host == store.host), isTrue);
        if (status != 302) expect(client.isAuthenticated, isFalse);
      },
    );
  }
}
