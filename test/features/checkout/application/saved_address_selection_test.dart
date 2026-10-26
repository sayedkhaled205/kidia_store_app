import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/checkout/application/checkout_controller.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/saved_checkout_address92.dart';
import '../support/checkout_test_data.dart';

void main() {
  const values = {
    'first_name': 'Ada',
    'last_name': 'Test',
    'country': 'US',
    'state': 'CA',
    'city': 'Test city',
    'address_1': 'Test street',
    'phone': '5550100',
  };
  test(
    'saved addresses deduplicate order and blank optional fields but preserve distinct contacts',
    () {
      final rows = SavedCheckoutAddress92.parse([
        {'id': 'first', 'label': 'First', 'values': values},
        {
          'id': 'duplicate',
          'label': 'Other label',
          'values': {
            ...Map.fromEntries(values.entries.toList().reversed),
            'address_1': ' Test street ',
            'company': '',
          },
        },
        {
          'id': 'phone',
          'values': {...values, 'phone': '5550101'},
        },
        {
          'id': 'company',
          'values': {...values, 'company': 'Company'},
        },
        {
          'id': 'custom',
          'values': {...values, 'building': 'B'},
        },
      ]);
      expect(rows.map((row) => row.id), [
        'first',
        'phone',
        'company',
        'custom',
      ]);
    },
  );
  test(
    'native billing and shipping copies with inherited contact appear once',
    () async {
      final cart = checkoutCart();
      final controller = CheckoutController(
        repository: FakeCheckoutRepository(
          state: CheckoutState(
            cart: cart,
            savedAddresses: [
              SavedCheckoutAddress92(
                id: 'billing',
                label: 'Billing',
                values: {...values, 'email': cart.billingAddress.email},
              ),
              SavedCheckoutAddress92(
                id: 'shipping',
                label: 'Shipping',
                values: values,
              ),
              SavedCheckoutAddress92(
                id: 'other',
                label: 'Other contact',
                values: {...values, 'email': 'another@example.test'},
              ),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.savedAddresses.map((row) => row.id), [
        'billing',
        'other',
      ]);
    },
  );
  test(
    'one saved ID selected, editing/new remain open, incomplete custom fields cannot be hidden',
    () async {
      final controller = CheckoutController(
        repository: FakeCheckoutRepository(
          state: CheckoutState(
            cart: checkoutCart(),
            savedAddresses: [
              SavedCheckoutAddress92(id: 'one', label: 'One', values: values),
              SavedCheckoutAddress92(
                id: 'two',
                label: 'Two',
                values: {...values, 'phone': '5550101'},
              ),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.selectSavedAddress(values, addressId: 'one');
      expect(controller.selectedSavedAddressId, 'one');
      expect(controller.showBillingEditor, false);
      controller.selectSavedAddress({
        ...values,
        'phone': '5550101',
      }, addressId: 'two');
      expect(controller.selectedSavedAddressId, 'two');
      expect(controller.billingAddress.phone, '5550101');
      controller.editSavedAddress();
      expect(controller.showBillingEditor, true);
      controller.updateBillingAddress(
        controller.billingAddress.copyWith(address1: 'Edited street'),
      );
      expect(controller.selectedSavedAddressId, isNull);
      controller.enterNewAddress();
      expect(controller.selectedSavedAddressId, isNull);
      expect(controller.showBillingEditor, true);
      expect(controller.billingAddress.address1, isEmpty);
    },
  );
  test(
    'required custom fields keep editor open and cannot bypass validation',
    () async {
      final controller = CheckoutController(
        repository: FakeCheckoutRepository(
          state: CheckoutState(
            cart: checkoutCart(),
            fieldDefinitions: [
              CheckoutFieldDefinition(
                key: 'building',
                group: CheckoutFieldGroup.billing,
                type: CheckoutFieldType.text,
                label: 'Building',
                required: true,
              ),
            ],
            savedAddresses: [
              SavedCheckoutAddress92(id: 'one', label: 'One', values: values),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.selectSavedAddress(values, addressId: 'one');
      expect(controller.showBillingEditor, true);
      expect(controller.validate(), false);
      controller.setFieldValue('building', 'B');
      expect(controller.showBillingEditor, true);
      expect(controller.validate(), true);
      expect(controller.selectedSavedAddressId, isNull);
    },
  );
}
