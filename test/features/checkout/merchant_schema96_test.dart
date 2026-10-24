import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_model.dart';
import 'package:mobishop_store_app/features/cart/data/network/cart_token_store.dart';
import 'package:mobishop_store_app/features/checkout/application/checkout_controller.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_api_transport.dart';
import 'package:mobishop_store_app/features/checkout/data/repositories/store_api_checkout_repository.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:mobishop_store_app/features/checkout/presentation/checkout_screen.dart';
import 'application/checkout_shipping_test.dart' show ShippingRepository, quote;
import 'support/checkout_test_data.dart';

List<CheckoutFieldDefinition> _fields() => [
  CheckoutFieldDefinition(
    key: 'billing_state',
    group: CheckoutFieldGroup.billing,
    type: CheckoutFieldType.select,
    label: 'المحافظة',
    required: true,
    options: {'EGC': 'القاهرة', 'EGBH': 'البحيرة'},
  ),
  CheckoutFieldDefinition(
    key: 'shipping_state',
    group: CheckoutFieldGroup.shipping,
    type: CheckoutFieldType.select,
    label: 'Delivery province',
    required: true,
    options: {'EGC': 'القاهرة', 'EGBH': 'البحيرة'},
  ),
];

void main() {
  test(
    'each opening reads current merchant labels, requirements and shipping policy',
    () async {
      final transport = FakeCheckoutTransport();
      final repo = StoreApiCheckoutRepository(
        cartRepository: FakeCheckoutCartRepository(cart: checkoutCart()),
        transport: transport,
        cartTokenStore: MemoryCartTokenStore(),
        requireMerchantConfiguration: true,
      );
      for (final allowed in [true, false, true]) {
        final label = allowed ? 'Province' : 'المحافظة';
        transport.configurationResponse = CheckoutApiResponse(
          data: {
            'version': 9,
            'renderer': 'native',
            'payment_methods': [],
            'shipping': {'allow_different_address': allowed},
            'fields': [
              {
                'key': 'billing_state',
                'group': 'billing',
                'type': 'state',
                'label': label,
                'placeholder': 'Choose $label',
                'required': allowed,
                'options': {'custom': 'Merchant district'},
              },
              {
                'key': 'shipping_postcode',
                'group': 'shipping',
                'type': 'text',
                'label': 'Delivery postcode',
                'required': true,
              },
            ],
          },
        );
        final state = await repo.loadCheckout();
        expect(state.allowDifferentShippingAddress, allowed);
        final field = state.fieldDefinitions.first;
        expect(field.label, label);
        expect(field.placeholder, 'Choose $label');
        expect(field.required, allowed);
        expect(field.options, {'custom': 'Merchant district'});
        expect(
          state.fieldDefinitions.any((f) => f.key == 'billing_postcode'),
          isFalse,
        );
      }
      expect(transport.configurationCalls, 3);
      expect(transport.calls, 0);
    },
  );

  test(
    'absent or malformed policy never invents a separate address option',
    () async {
      for (final policy in [
        null,
        {},
        {'allow_different_address': 'false'},
        {'allow_different_address': 1},
      ]) {
        final transport = FakeCheckoutTransport()
          ..configurationResponse = CheckoutApiResponse(
            data: {
              'version': 9,
              'renderer': 'native',
              'payment_methods': [],
              'shipping': policy,
              'fields': [
                {
                  'key': 'billing_first_name',
                  'group': 'billing',
                  'label': 'Name',
                },
              ],
            },
          );
        final state = await StoreApiCheckoutRepository(
          cartRepository: FakeCheckoutCartRepository(cart: checkoutCart()),
          transport: transport,
          cartTokenStore: MemoryCartTokenStore(),
          requireMerchantConfiguration: true,
        ).loadCheckout();
        expect(state.allowDifferentShippingAddress, isFalse);
      }
    },
  );

  test(
    'billing-only policy ignores stale shipping destination in quotes and order',
    () async {
      final json = checkoutCartJson();
      (json['shipping_address'] as Map)['city'] = 'Old other city';
      final repo = ShippingRepository()
        ..state = CheckoutState(
          cart: CartModel.fromJson(json).toEntity(),
          allowDifferentShippingAddress: false,
        );
      final controller = CheckoutController(repository: repo);
      repo.onQuote = (_) async => quote();
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.shipToDifferentAddress, isFalse);
      controller.setShipToDifferentAddress(true);
      expect(controller.shipToDifferentAddress, isFalse);
      await controller.refreshShipping();
      expect(repo.destinations.last.city, 'London');
      await controller.selectShippingRate(0, 'flat_rate:2');
      expect(controller.checkout!.allowDifferentShippingAddress, isFalse);
      controller.setPaymentMethod('card');
      repo.onUpdateCustomer = (_, _) async => controller.cart!;
      expect(
        await controller.submit(),
        isNotNull,
        reason:
            '${controller.submitError} ${controller.fieldErrors} ${controller.shippingReady}',
      );
      expect(repo.submissions.single.shippingAddress.city, 'London');
    },
  );

  for (final dynamicFields in [false, true]) {
    for (final allowed in [false, true]) {
      testWidgets(
        'address choice follows policy: dynamic=$dynamicFields allowed=$allowed',
        (tester) async {
          final repo = FakeCheckoutRepository(
            state: CheckoutState(
              cart: quote(),
              allowDifferentShippingAddress: allowed,
              fieldDefinitions: dynamicFields ? _fields() : [],
            ),
          );
          await tester.pumpWidget(
            MaterialApp(home: CheckoutScreen(repository: repo)),
          );
          await tester.pumpAndSettle();
          final toggle = find.byKey(
            const Key('checkout-different-shipping-toggle'),
          );
          expect(toggle, allowed ? findsOneWidget : findsNothing);
          if (dynamicFields) expect(find.text('المحافظة *'), findsOneWidget);
          if (allowed) {
            await tester.ensureVisible(toggle);
            await tester.tap(toggle);
            await tester.pumpAndSettle();
            expect(
              find.byKey(
                Key(
                  dynamicFields
                      ? 'checkout-dynamic-shipping_state'
                      : 'checkout-shipping-firstName',
                ),
              ),
              findsOneWidget,
            );
            await tester.tap(toggle);
            await tester.pumpAndSettle();
          }
          expect(repo.submitCalls, 0);
        },
      );
    }
  }
}
