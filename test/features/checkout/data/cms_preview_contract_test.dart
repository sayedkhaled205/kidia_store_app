import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/checkout/data/repositories/cms_preview_checkout_repository.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_field_definition.dart';

void main() {
  final fields = [
    {
      'key': 'billing_state',
      'group': 'billing',
      'type': 'state',
      'label': 'المحافظة',
      'required': true,
    },
    {
      'key': 'shipping_postcode',
      'group': 'shipping',
      'type': 'text',
      'label': 'ZIP',
      'required': true,
    },
  ];
  final config = <String, dynamic>{
    'version': 8,
    'renderer': 'native',
    'fields': fields,
    'defaults': {
      'country': 'EG',
      'states': {'C': 'القاهرة', 'ALX': 'الإسكندرية'},
    },
    'shipping': {'allow_different_address': false},
    'payment_methods': [
      {'id': 'card', 'title': 'الكارت', 'native_adapter': 'kashier'},
      {'id': 'cod', 'title': 'نقدًا عند الاستلام', 'native_adapter': 'offline'},
    ],
  };
  final catalog = <String, dynamic>{
    'products': [
      {'id': 7, 'name': 'Item', 'price_minor': '45500', 'currency_code': 'EGP'},
    ],
  };

  test(
    'preview preserves merchant fields, state options and payment capability',
    () async {
      final state = await CmsPreviewCheckoutRepository(
        {},
        catalog,
        configuration: config,
      ).loadCheckout();
      expect(state.fieldDefinitions.map((f) => f.key), [
        'billing_state',
        'shipping_postcode',
      ]);
      final governorate = state.fieldDefinitions.first;
      expect(governorate.label, 'المحافظة');
      expect(governorate.type, CheckoutFieldType.select);
      expect(governorate.options['C'], 'القاهرة');
      expect(state.allowDifferentShippingAddress, false);
      expect(state.cart.billingAddress.country, 'EG');
      expect(state.cart.needsPayment, true);
      expect(state.cart.hasCalculatedShipping, false);
      expect(state.cart.paymentMethods, ['card', 'cod']);
      expect(state.nativePaymentAdapters['card'], 'kashier');
      expect(state.paymentMethodLabels['card'], 'الكارت');
      expect(state.cart.totals.currency.code, 'EGP');
    },
  );

  test(
    'different stores retain their own methods and explicit editor drafts',
    () async {
      final state = await CmsPreviewCheckoutRepository(
        {
          'checkout_fields': [
            {
              'key': 'billing_state',
              'group': 'billing',
              'label': 'Edited label',
            },
          ],
        },
        catalog,
        configuration: {
          ...config,
          'payment_methods': [
            {'id': 'cod', 'title': 'Cash', 'native_adapter': 'offline'},
          ],
          'shipping': {'allow_different_address': true},
        },
      ).loadCheckout();
      expect(state.cart.paymentMethods, ['cod']);
      expect(state.nativePaymentAdapters.containsKey('card'), false);
      expect(state.allowDifferentShippingAddress, true);
      expect(state.fieldDefinitions.single.label, 'Edited label');
    },
  );
}
