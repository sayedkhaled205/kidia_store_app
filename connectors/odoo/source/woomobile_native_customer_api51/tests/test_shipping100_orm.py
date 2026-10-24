"""Real Odoo carrier and tax integration; all records are rollback fixtures.

Uses the cart85 request fixture. No carrier, pricing or tax method is mocked.
No payment is created. The original five inherited cart cases also run.
"""

from odoo.addons.website_sale.controllers.delivery import Delivery

from .test_cart_service85 import CartService85TransactionTests
from ..services.customer_service import CustomerContractError, money_minor, scope_for
from ..services.cart_service85 import CartService85
from ..services.shipping100 import shipping_quotes100, select_shipping100


class Shipping100TransactionTests(CartService85TransactionTests):
    def shipping_order100(self):
        self.product.write({'type': 'consu', 'allow_out_of_stock_order': True})
        self.customer.partner_id.write({
            'street': 'Rollback only road', 'city': 'Cairo',
            'country_id': self.env.ref('base.eg').id, 'zip': '11511', 'phone': '+20 QA 100',
        })
        self.req.env = self.req.env(user=self.customer.id)
        self.req.website = self.website.with_env(self.req.env)
        service = CartService85(self.req, self.website, controller=self.service.controller,
                                customer_scope=scope_for(self.req.env, self.website))
        service.add({'product_id': self.product.id, 'quantity': 1})
        self.shipping_service100 = service
        order = self.env['sale.order'].browse(self.req.session['sale_order_id'])
        self.assertTrue(order._has_deliverable_products())
        return order.with_context(website_id=self.website.id)

    def carrier100(self, country, price, taxes=None):
        product = self.env['product.product'].create({
            'name': 'Native100 rollback delivery', 'type': 'service',
            'company_id': self.company.id, 'taxes_id': [(6, 0, taxes.ids if taxes else [])],
        })
        return self.env['delivery.carrier'].create({
            'name': 'Native100 rollback ' + country.code, 'delivery_type': 'fixed',
            'fixed_price': price, 'product_id': product.id, 'company_id': self.company.id,
            'website_id': self.website.id, 'website_published': True,
            'country_ids': [(6, 0, country.ids)],
        })

    def test_shipping100_quote_matches_original_website_tax_calculation(self):
        order = self.shipping_order100()
        tax = self.env['account.tax'].create({
            'name': 'Native100 rollback tax', 'amount': 14, 'amount_type': 'percent',
            'type_tax_use': 'sale', 'company_id': self.company.id,
        })
        carrier = self.carrier100(self.env.ref('base.eg'), 12.34, tax)
        # Original Delivery consumes request.website; bind the same existing
        # fixture request on that alias only, never mock rates or compute_all.
        from unittest.mock import patch
        with patch('odoo.addons.website_sale.controllers.delivery.request', self.req):
            expected = Delivery._get_rate(carrier, order)
        quote = next(value for value in shipping_quotes100(order) if value['carrier_id'] == carrier.id)
        self.assertEqual(quote['display_price_minor'],
                         money_minor(expected['price'], order.currency_id.decimal_places))
        self.assertEqual(quote['price_minor'], '1234')
        self.assertEqual(quote['tax_minor'], '173')
        self.assertFalse(order.transaction_ids)

    def test_shipping100_destination_uses_original_merchant_availability(self):
        order = self.shipping_order100()
        egypt = self.carrier100(self.env.ref('base.eg'), 12.34)
        usa = self.carrier100(self.env.ref('base.us'), 25.67)
        offered = {value['carrier_id'] for value in shipping_quotes100(order)}
        self.assertIn(egypt.id, offered)
        self.assertNotIn(usa.id, offered)
        order.partner_shipping_id.country_id = self.env.ref('base.us')
        offered = {value['carrier_id'] for value in shipping_quotes100(order)}
        self.assertNotIn(egypt.id, offered)
        self.assertIn(usa.id, offered)

    def test_shipping100_selection_uses_current_rate_and_original_delivery_line(self):
        order = self.shipping_order100()
        carrier = self.carrier100(self.env.ref('base.eg'), 12.34)
        select_shipping100(order, carrier.id)
        self.assertEqual(order.carrier_id, carrier)
        self.assertEqual(order.order_line.filtered('is_delivery').price_subtotal, 12.34)
        carrier.fixed_price = 17.89
        select_shipping100(order, carrier.id)
        delivery = order.order_line.filtered('is_delivery')
        self.assertEqual(len(delivery), 1)
        self.assertEqual(delivery.price_subtotal, 17.89)
        self.assertEqual(order.state, 'draft')
        self.assertFalse(order.transaction_ids)

    def test_shipping100_unavailable_destination_does_not_replace_selected_carrier(self):
        order = self.shipping_order100()
        egypt = self.carrier100(self.env.ref('base.eg'), 12.34)
        usa = self.carrier100(self.env.ref('base.us'), 25.67)
        select_shipping100(order, egypt.id)
        with self.assertRaises(CustomerContractError) as error:
            select_shipping100(order, usa.id)
        self.assertEqual(error.exception.code, 'shipping_method_unavailable')
        self.assertEqual(order.carrier_id, egypt)
        self.assertEqual(order.order_line.filtered('is_delivery').price_subtotal, 12.34)

    def test_shipping100_stale_cart_revision_cannot_select_carrier(self):
        order = self.shipping_order100()
        carrier = self.carrier100(self.env.ref('base.eg'), 12.34)
        service = self.shipping_service100
        with self.assertRaises(CustomerContractError) as error:
            service.shipping_select100({'carrier_id': carrier.id, 'cart_revision': '0' * 64})
        self.assertEqual(error.exception.code, 'cart_revision_changed')
        quote = service.shipping_quote100({})
        self.assertEqual(quote['shipping_contract_version'], '100.1')
        result = service.shipping_select100({
            'carrier_id': carrier.id, 'cart_revision': quote['cart']['revision'],
        })
        self.assertEqual(result['cart']['totals']['shipping_minor'], '1234')
        self.assertEqual(order.state, 'draft')

    def test_shipping100_no_caller_order_partner_or_price_authority(self):
        order = self.shipping_order100()
        carrier = self.carrier100(self.env.ref('base.eg'), 12.34)
        service = self.shipping_service100
        revision = service.cart()['revision']
        for field in ('order_id', 'partner_id', 'price', 'website_id'):
            with self.subTest(field=field), self.assertRaises(CustomerContractError):
                service.shipping_select100({
                    'carrier_id': carrier.id, 'cart_revision': revision, field: 1,
                })
        self.assertFalse(order.transaction_ids)
