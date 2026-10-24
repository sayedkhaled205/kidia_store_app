import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/features/checkout/data/odoo/odoo_checkout101.dart';
import 'support/odoo_merchant100.dart';

void main() {
  for (final host in [
    'alpha.odoo.example.invalid',
    'beta.odoo.example.invalid',
  ]) {
    test(
      '$host checkout metadata uses own guest cookie and CSRF without merchant secrets',
      () async {
        final store = OdooMerchant100(host)..checkoutFormEnabled = true;
        final client = odooTestClient100(store);
        addTearDown(client.close);
        await client.session();
        final api = OdooCheckout101(client, isCurrent: () => true);
        final form = await api.form(countryId: 65);
        expect(form.fields.single.label, 'Merchant name');
        expect(store.checkoutPayloads.single, {
          'address_type': 'billing',
          'country_id': 65,
        });
        expect(
          store.requests.last.uri.path,
          '/api/mobile/v1/customer/checkout/address/form',
        );
        await api.save(
          type: 'billing',
          fields: {'name': 'Fixture buyer'},
          useForShipping: true,
        );
        expect(store.checkoutPayloads.last, {
          'address_type': 'billing',
          'fields': {'name': 'Fixture buyer'},
          'use_for_shipping': true,
        });
        await api.quote();
        expect(store.checkoutPayloads.last, isEmpty);
      },
    );
  }
  test(
    'old cart-enabled server cannot silently become native checkout',
    () async {
      final store = OdooMerchant100('alpha.odoo.example.invalid');
      final client = odooTestClient100(store);
      addTearDown(client.close);
      await expectLater(
        client.checkoutForm101(addressType: 'billing'),
        throwsA(isA<OdooCustomerException51>()),
      );
      expect(store.checkoutPayloads, isEmpty);
    },
  );
  test(
    'checkout rejects foreign owner even on an otherwise valid response',
    () async {
      final store = OdooMerchant100('alpha.odoo.example.invalid')
        ..checkoutFormEnabled = true
        ..alterCheckout = (raw) => raw['customer_id'] = 99;
      final client = odooTestClient100(store);
      addTearDown(client.close);
      await client.session();
      await expectLater(
        OdooCheckout101(client, isCurrent: () => true).form(),
        throwsA(anything),
      );
    },
  );
  test('pending form cannot enter the next checkout owner', () async {
    final store = OdooMerchant100('alpha.odoo.example.invalid')
      ..checkoutFormEnabled = true;
    final client = odooTestClient100(store);
    addTearDown(client.close);
    await client.session();
    var current = true;
    final api = OdooCheckout101(client, isCurrent: () => current);
    store.pauseCart = Completer<void>();
    final future = api.form();
    final rejected = expectLater(
      future,
      throwsA(isA<OdooCustomerException51>()),
    );
    while (store.checkoutPayloads.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    current = false;
    store.pauseCart!.complete();
    await rejected;
  });
  test('unknown field and duplicate carrier metadata fail closed', () {
    expect(
      () => OdooAddressField101({
        'name': 'partner_id',
        'label': 'Partner',
        'kind': 'text',
        'value': '',
        'required': true,
        'readonly': false,
        'choices': [],
      }),
      throwsFormatException,
    );
    expect(
      () => OdooAddressField101({
        'name': 'state_id',
        'label': 'State',
        'kind': 'select',
        'value': '999',
        'required': true,
        'readonly': false,
        'choices': [
          {'value': '1', 'label': 'State one'},
        ],
      }),
      throwsFormatException,
    );
  });
}
