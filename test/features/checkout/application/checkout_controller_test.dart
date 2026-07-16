import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_model.dart';
import 'package:kidia_store_app/features/checkout/application/checkout_controller.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:kidia_store_app/features/checkout/domain/repositories/checkout_repository.dart';

import '../support/checkout_test_data.dart';

void main() {
  group('CheckoutController', () {
    test('loads addresses and auto-selects the only payment method', () async {
      final CheckoutController controller = CheckoutController(
        repository: FakeCheckoutRepository(),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.status, CheckoutStatus.ready);
      expect(controller.billingAddress.firstName, 'Ada');
      expect(controller.billingAddress.email, 'ada@example.com');
      expect(controller.shipToDifferentAddress, isFalse);
      expect(controller.paymentMethodId, 'cod');
      expect(controller.validate(), isTrue);
    });

    test(
      'defaults hidden country and updates WooCommerce before checkout',
      () async {
        final Map<String, dynamic> cartJson = checkoutCartJson();
        (cartJson['billing_address'] as Map<String, dynamic>)['country'] = '';
        (cartJson['shipping_address'] as Map<String, dynamic>)['country'] = '';
        late CheckoutAddress updatedBilling;
        late CheckoutAddress updatedShipping;
        final FakeCheckoutRepository repository = FakeCheckoutRepository(
          state: CheckoutState(
            cart: CartModel.fromJson(cartJson).toEntity(),
            fieldDefinitions: <CheckoutFieldDefinition>[
              CheckoutFieldDefinition(
                key: 'billing_country',
                group: CheckoutFieldGroup.billing,
                type: CheckoutFieldType.hidden,
                label: 'Country',
                defaultValue: 'EG',
              ),
              CheckoutFieldDefinition(
                key: 'billing_state',
                group: CheckoutFieldGroup.billing,
                type: CheckoutFieldType.select,
                label: 'المحافظة',
                required: true,
                options: const <String, String>{'C': 'القاهرة'},
              ),
            ],
          ),
          onUpdateCustomer:
              (CheckoutAddress billing, CheckoutAddress shipping) async {
                updatedBilling = billing;
                updatedShipping = shipping;
                return checkoutCart(totalPrice: '15000');
              },
        );
        final CheckoutController controller = CheckoutController(
          repository: repository,
        );
        addTearDown(controller.dispose);
        await controller.load();

        expect(controller.billingAddress.country, 'EG');
        expect(
          controller
              .fieldsFor(CheckoutFieldGroup.billing)
              .map((CheckoutFieldDefinition field) => field.key),
          isNot(contains('billing_country')),
        );

        controller.setFieldValue('billing_state', 'C');
        expect((await controller.submit())?.orderId, 730);
        expect(repository.updateCustomerCalls, 1);
        expect(updatedBilling.country, 'EG');
        expect(updatedBilling.state, 'C');
        expect(updatedShipping.country, 'EG');
        expect(updatedShipping.state, 'C');
        expect(controller.cart?.totals.priceMinor, '15000');
      },
    );

    test('validates and submits a plugin-provided checkout field', () async {
      final FakeCheckoutRepository repository = FakeCheckoutRepository(
        state: CheckoutState(
          cart: checkoutCart(),
          fieldDefinitions: <CheckoutFieldDefinition>[
            CheckoutFieldDefinition(
              key: 'billing_vat_number',
              group: CheckoutFieldGroup.billing,
              type: CheckoutFieldType.text,
              label: 'VAT number',
              required: true,
            ),
          ],
        ),
      );
      final CheckoutController controller = CheckoutController(
        repository: repository,
      );
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.validate(), isFalse);
      expect(controller.errorFor('billing_vat_number'), isNotNull);
      controller.setFieldValue('billing_vat_number', ' EG-123 ');
      expect(controller.validate(), isTrue);
      await controller.submit();

      expect(repository.submissions.single.customFields, <String, String>{
        'billing_vat_number': 'EG-123',
      });
    });

    test(
      'validates billing, optional shipping, note, and payment selection',
      () async {
        final CheckoutController controller = CheckoutController(
          repository: FakeCheckoutRepository(
            state: CheckoutState(
              cart: checkoutCart(paymentMethods: <String>['cod', 'bacs']),
            ),
          ),
        );
        addTearDown(controller.dispose);
        await controller.load();

        controller.updateBillingAddress(const CheckoutAddress());
        controller.setShipToDifferentAddress(true);
        controller.updateShippingAddress(const CheckoutAddress(country: 'EGY'));
        controller.setCustomerNote(List<String>.filled(1001, 'x').join());

        expect(controller.validate(), isFalse);
        expect(controller.errorFor('billing.firstName'), isNotNull);
        expect(controller.errorFor('billing.email'), isNotNull);
        expect(controller.errorFor('shipping.address1'), isNotNull);
        expect(controller.errorFor('shipping.country'), isNotNull);
        expect(controller.errorFor('paymentMethod'), isNotNull);
        expect(controller.errorFor('customerNote'), isNotNull);
      },
    );

    test('coalesces a double submit into one order request', () async {
      final Completer<CheckoutOrderResult> order =
          Completer<CheckoutOrderResult>();
      final FakeCheckoutRepository repository = FakeCheckoutRepository(
        onSubmit: (_) => order.future,
      );
      final CheckoutController controller = CheckoutController(
        repository: repository,
        clock: () => DateTime.fromMicrosecondsSinceEpoch(100),
      );
      addTearDown(controller.dispose);
      await controller.load();

      final Future<CheckoutOrderResult?> first = controller.submit();
      final Future<CheckoutOrderResult?> second = controller.submit();
      expect(identical(first, second), isTrue);
      await waitForCondition(() => repository.submitCalls == 1);
      order.complete(checkoutOrderResult);

      expect((await first)?.orderId, 730);
      expect((await second)?.orderId, 730);
      expect(repository.submitCalls, 1);
      expect(controller.status, CheckoutStatus.success);
      expect(repository.submissions.single.idempotencyKey, 'checkout-100-1');
    });

    test(
      'reuses the request key after an uncertain failure until form changes',
      () async {
        int attempt = 0;
        final FakeCheckoutRepository repository = FakeCheckoutRepository(
          onSubmit: (_) async {
            attempt++;
            if (attempt < 3) {
              throw const CheckoutRepositoryException(
                kind: CheckoutFailureKind.connection,
                message: 'Connection lost after sending.',
              );
            }
            return checkoutOrderResult;
          },
        );
        final CheckoutController controller = CheckoutController(
          repository: repository,
          clock: () => DateTime.fromMicrosecondsSinceEpoch(200),
        );
        addTearDown(controller.dispose);
        await controller.load();

        expect(await controller.submit(), isNull);
        expect(await controller.submit(), isNull);
        expect(
          repository.submissions[0].idempotencyKey,
          repository.submissions[1].idempotencyKey,
        );

        controller.setCustomerNote('Changed');
        expect((await controller.submit())?.orderId, 730);
        expect(
          repository.submissions[2].idempotencyKey,
          isNot(repository.submissions[1].idempotencyKey),
        );
      },
    );

    test('replaces totals with the authoritative cart on conflict', () async {
      final FakeCheckoutRepository repository = FakeCheckoutRepository(
        onSubmit: (_) async => throw CheckoutRepositoryException(
          kind: CheckoutFailureKind.conflict,
          message: 'Cart changed.',
          statusCode: 409,
          authoritativeCart: checkoutCart(totalPrice: '17500'),
        ),
      );
      final CheckoutController controller = CheckoutController(
        repository: repository,
      );
      addTearDown(controller.dispose);
      await controller.load();

      expect(await controller.submit(), isNull);

      expect(controller.status, CheckoutStatus.ready);
      expect(controller.cart?.totals.priceMinor, '17500');
      expect(controller.submitError, 'Cart changed.');
    });

    test('ignores a stale checkout load response', () async {
      final Completer<CheckoutState> stale = Completer<CheckoutState>();
      final Completer<CheckoutState> fresh = Completer<CheckoutState>();
      int call = 0;
      final FakeCheckoutRepository repository = FakeCheckoutRepository(
        onLoad: () => call++ == 0 ? stale.future : fresh.future,
      );
      final CheckoutController controller = CheckoutController(
        repository: repository,
      );
      addTearDown(controller.dispose);

      final Future<void> first = controller.load();
      await waitForCondition(() => repository.loadCalls == 1);
      final Future<void> second = controller.load();
      await waitForCondition(() => repository.loadCalls == 2);
      fresh.complete(CheckoutState(cart: checkoutCart(totalPrice: '19000')));
      await second;
      stale.complete(CheckoutState(cart: checkoutCart(totalPrice: '11000')));
      await first;

      expect(controller.cart?.totals.priceMinor, '19000');
    });
  });
}
