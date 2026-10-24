"""Host input/fingerprint tests only; not installed Odoo/Native acceptance."""

import importlib.util
import pathlib
import sys
import types
import unittest


SERVICES = pathlib.Path(__file__).resolve().parents[1] / 'services'
PACKAGE = '_woomobile_cart_contract85_host'
package = types.ModuleType(PACKAGE)
package.__path__ = [str(SERVICES)]
sys.modules.setdefault(PACKAGE, package)


def load(name):
    spec = importlib.util.spec_from_file_location(PACKAGE + '.' + name, SERVICES / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


customer = load('customer_service')
contract = load('cart_contract85')


class CartContract85HostTests(unittest.TestCase):
    def test_exact_native_variant_and_quantity(self):
        self.assertEqual(contract.add_fields({'product_id': 37, 'quantity': 2}), (37, 2))
        for value in (True, '2', 2.0, -1, 0, contract.MAX_QUANTITY + 1):
            with self.subTest(value=value), self.assertRaises(customer.CustomerContractError):
                contract.add_fields({'product_id': 37, 'quantity': value})

    def test_no_partner_order_price_tax_or_domain_inputs(self):
        for field in ('partner_id', 'order_id', 'price_unit', 'tax_id', 'domain', 'website_id'):
            with self.subTest(field=field), self.assertRaises(customer.CustomerContractError):
                contract.add_fields({'product_id': 37, 'quantity': 2, field: 1})

    def test_update_zero_means_original_cart_line_removal(self):
        self.assertEqual(contract.update_fields({'quantity': 0}), 0)
        self.assertEqual(contract.update_fields({'quantity': 3}), 3)

    def test_existing_fractional_quote_never_rounded(self):
        self.assertEqual(contract.integral_quantity(2.0), 2)
        for value in ('0.5', float('nan'), float('inf'), '-1'):
            with self.subTest(value=value), self.assertRaises(customer.CustomerContractError):
                contract.integral_quantity(value)

    def test_confirmation_does_not_accept_numeric_money_or_extra_fields(self):
        payload = {
            'idempotency_key': 'qa85-native-attempt-123456789',
            'cart_revision': 'a' * 64, 'confirmed_total_minor': '0', 'currency': 'EGP',
            'customer_note': '',
        }
        self.assertEqual(contract.confirm_fields(payload)[2], '0')
        for changed in (payload | {'confirmed_total_minor': 0}, payload | {'payment_method': 'fake'},
                        payload | {'currency': 'egp'}, payload | {'confirmed_total_minor': '-1'}):
            with self.assertRaises(customer.CustomerContractError):
                contract.confirm_fields(changed)

    def test_nonzero_quote_is_valid_contract_input_not_fake_zero(self):
        payload = {'idempotency_key': 'qa85-native-attempt-123456789', 'cart_revision': 'a' * 64,
                   'confirmed_total_minor': '9875', 'currency': 'EGP', 'customer_note': ''}
        self.assertEqual(contract.confirm_fields(payload)[2], '9875')

    def test_fingerprint_includes_actual_quote_and_visible_totals(self):
        snapshot = {'items': [], 'totals': {'total_minor': '0'}}
        first = contract.cart_revision(snapshot, order_id=12)
        self.assertNotEqual(first, contract.cart_revision(snapshot, order_id=13))
        self.assertNotEqual(first, contract.cart_revision(
            snapshot | {'totals': {'total_minor': '1'}}, order_id=12,
        ))
        self.assertEqual(first, contract.cart_revision(snapshot, order_id=12))

    def test_attempt_hash_does_not_store_raw_buyer_input(self):
        value = 'qa85-native-attempt-123456789'
        digest = contract.attempt_digest(value)
        self.assertEqual(len(digest), 64)
        self.assertNotIn(value, digest)


if __name__ == '__main__':
    unittest.main()
