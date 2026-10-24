"""Boundary tests only. Actual carrier/tax behavior requires Odoo ORM tests."""

import importlib.util
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import Mock

SERVICES = Path(__file__).resolve().parents[1] / 'services'
PACKAGE = '_woomobile_shipping100_host'
package = types.ModuleType(PACKAGE)
package.__path__ = [str(SERVICES)]
sys.modules[PACKAGE] = package


def load(name):
    spec = importlib.util.spec_from_file_location(PACKAGE + '.' + name, SERVICES / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


customer = load('customer_service')
shipping = load('shipping100')


class Shipping100HostTests(unittest.TestCase):
    def test_failed_or_invalid_quotes_never_become_free_shipping(self):
        for rate in (None, {}, {'success': False, 'price': 0},
                     {'success': 1, 'price': 0}, {'success': True, 'price': True},
                     {'success': True, 'price': '10'},
                     *({'success': True, 'price': p} for p in (-1, float('nan'), float('inf')))):
            with self.subTest(rate=rate):
                self.assertIsNone(shipping.carrier_quote100(None, None, rate))

    def test_genuine_zero_quote_is_allowed(self):
        self.assertTrue(shipping._valid_rate100({'success': True, 'price': 0}))

    def test_active_payment_blocks_shipping_before_rate_or_write(self):
        for state in ('pending', 'authorized', 'done', 'unknown'):
            with self.subTest(state=state):
                order = Mock(transaction_ids=[types.SimpleNamespace(state=state)])
                order._has_deliverable_products.return_value = True
                with self.assertRaises(customer.CustomerContractError) as error:
                    shipping.select_shipping100(order, 123)
                self.assertEqual(error.exception.code, 'checkout_outcome_required')
                order._get_delivery_methods.assert_not_called()
                order._set_delivery_method.assert_not_called()

    def test_service_only_order_never_offers_or_selects_delivery(self):
        order = Mock()
        order._has_deliverable_products.return_value = False
        self.assertEqual(shipping.shipping_quotes100(order), [])
        with self.assertRaises(customer.CustomerContractError):
            shipping.select_shipping100(order, 1)
        order._get_delivery_methods.assert_not_called()

    def test_unavailable_carrier_cannot_be_selected_by_id(self):
        order = Mock(transaction_ids=[])
        order._has_deliverable_products.return_value = True
        order._get_delivery_methods.return_value.filtered.return_value = []
        with self.assertRaises(customer.CustomerContractError) as error:
            shipping.select_shipping100(order, 999)
        self.assertEqual(error.exception.code, 'shipping_method_unavailable')
        order._set_delivery_method.assert_not_called()

    def test_failed_rate_cannot_replace_existing_delivery(self):
        order = Mock(transaction_ids=[])
        order._has_deliverable_products.return_value = True
        carrier = order._get_delivery_methods.return_value.filtered.return_value
        carrier.rate_shipment.return_value = {'success': False, 'price': 0}
        with self.assertRaises(customer.CustomerContractError) as error:
            shipping.select_shipping100(order, 3)
        self.assertEqual(error.exception.code, 'shipping_rate_unavailable')
        order._set_delivery_method.assert_not_called()


if __name__ == '__main__':
    unittest.main()
