"""Five rollback-only genuine Odoo ORM cart cases, not Native acceptance.

Uses a narrowly patched HTTP context because website_sale model methods consume
Odoo's request proxy. All cart/price/stock/address/confirm methods are the actual
installed inherited ORM implementations, not mocks or invented order states.
Only new fixture records are modified, and TransactionCase discards them.
"""

from contextlib import ExitStack
from types import SimpleNamespace
from unittest.mock import patch

from odoo.addons.website_sale.controllers.main import WebsiteSale
from odoo.http import Session
from odoo.tests.common import TransactionCase, tagged

from ..services.cart_service85 import CartService85, CheckoutRejected85
from ..services.customer_service import CustomerContractError, scope_for


@tagged('post_install', '-at_install', 'woomobile_cart85')
class CartService85TransactionTests(TransactionCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.company = cls.env.company
        cls.website = cls.env['website'].create({
            'name': 'Native cart85 rollback only', 'domain': 'https://cart85.example.invalid',
            'company_id': cls.company.id, 'prevent_zero_price_sale': False,
            'account_on_checkout': 'optional', 'ecommerce_access': 'everyone',
        })
        cls.pricelist = cls.env['product.pricelist'].create({
            'name': 'Native85 fixture pricing', 'currency_id': cls.company.currency_id.id,
            'company_id': cls.company.id, 'website_id': cls.website.id, 'selectable': True,
        })
        cls.product = cls.env['product.product'].create({
            'name': 'Native85 rollback service', 'type': 'service', 'list_price': 10,
            'sale_ok': True, 'is_published': True, 'website_id': cls.website.id,
            'company_id': cls.company.id, 'taxes_id': [(5, 0, 0)],
        })
        # A real merchant pricelist rule makes the service free; no line-price
        # override, arbitrary stock write or disabled pricing constraint.
        cls.env['product.pricelist.item'].create({
            'pricelist_id': cls.pricelist.id, 'applied_on': '0_product_variant',
            'product_id': cls.product.id, 'compute_price': 'fixed', 'fixed_price': 0,
        })
        portal = cls.env.ref('base.group_portal')
        cls.customer = cls.env['res.users'].with_context(no_reset_password=True).create({
            'name': 'Native85 rollback buyer', 'login': 'native85-rollback@example.invalid',
            'email': 'native85-rollback@example.invalid', 'company_id': cls.company.id,
            'company_ids': [(6, 0, cls.company.ids)], 'groups_id': [(6, 0, portal.ids)],
        })
        cls.customer.partner_id.property_product_pricelist = cls.pricelist

    def setUp(self):
        super().setUp()
        env = self.env(user=self.website.user_id.id, context={
            **self.env.context, 'website_id': self.website.id,
            'allowed_company_ids': self.company.ids,
            'lang': self.website.default_lang_id.code,
        })
        self.req = SimpleNamespace(
            env=env, context=env.context, db=env.cr.dbname, session=Session(
                {'website_sale_current_pl': self.pricelist.id, 'debug': ''},
                sid='native85-rollback-only-no-http-session', new=True,
            ),
            geoip=SimpleNamespace(country_code=False), lang=SimpleNamespace(code=env.lang),
            is_frontend=True, website=self.website.with_env(env), website_routing=self.website.id,
            httprequest=SimpleNamespace(host_url='https://cart85.example.invalid/',
                                        headers={'Odoo-Link-Preview': 'True'}),
        )
        self.req.redirect = lambda location: SimpleNamespace(location=location)
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        for target in (
            'odoo.addons.website_sale.models.website.request',
            'odoo.addons.website_sale.models.sale_order.request',
            'odoo.addons.website_sale.controllers.main.request',
        ):
            self.stack.enter_context(patch(target, self.req))
        self.service = CartService85(self.req, self.website, controller=WebsiteSale())

    def test_guest_add_quantity_and_original_remove(self):
        cart, _warning = self.service.add({'product_id': self.product.id, 'quantity': 2})
        self.assertEqual(cart['items'][0]['quantity'], 2)
        self.assertEqual(cart['totals']['total_minor'], '0')
        line_id = cart['items'][0]['line_id']
        cart, _warning = self.service.update(line_id, {'quantity': 3})
        self.assertEqual(cart['items'][0]['quantity'], 3)
        cart, _warning = self.service.update(line_id, {'quantity': 0})
        self.assertEqual(cart['items'], [])
        self.assertNotIn('sale_order_id', self.req.session)

    def test_guest_cookie_lease_cannot_read_another_guest_basket(self):
        self.service.add({'product_id': self.product.id, 'quantity': 1})
        own_id = self.req.session['sale_order_id']
        self.req.session.pop('woomobile_native_cart85_lease')
        foreign_session = CartService85(self.req, self.website, controller=WebsiteSale())
        with self.assertRaises(CustomerContractError):
            foreign_session.cart()
        order = self.env['sale.order'].browse(own_id)
        self.assertEqual(order.state, 'draft')
        self.assertEqual(order.order_line.product_uom_qty, 1)

    def test_guest_to_portal_rebind_is_original_sale_get_order(self):
        self.service.add({'product_id': self.product.id, 'quantity': 1})
        order_id = self.req.session['sale_order_id']
        self.req.env = self.req.env(user=self.customer.id)
        self.req.website = self.website.with_env(self.req.env)
        scope = scope_for(self.req.env, self.website)
        service = CartService85(self.req, self.website, controller=WebsiteSale(), customer_scope=scope)
        self.assertEqual(service.cart()['items'][0]['quantity'], 1)
        order = self.env['sale.order'].browse(order_id)
        self.assertEqual(order.partner_id, self.customer.partner_id)
        self.assertEqual(order.native_cart_customer_uid85, self.customer.id)

    def test_stale_totals_rejected_before_confirmation(self):
        cart, _warning = self.service.add({'product_id': self.product.id, 'quantity': 1})
        order_id = self.req.session['sale_order_id']
        with self.assertRaises(CheckoutRejected85) as raised:
            self.service.confirm({
                'idempotency_key': 'qa85-stale-totals-only', 'cart_revision': cart['revision'],
                'confirmed_total_minor': '1', 'currency': cart['currency']['code'], 'customer_note': '',
            })
        self.assertFalse(raised.exception.proof['checkout_dispatched'])
        self.assertEqual(self.env['sale.order'].browse(order_id).state, 'draft')

    def test_free_original_confirmation_receipt_and_exact_recovery(self):
        self.service.add({'product_id': self.product.id, 'quantity': 1})
        self.req.env = self.req.env(user=self.customer.id)
        self.req.website = self.website.with_env(self.req.env)
        service = CartService85(self.req, self.website, controller=WebsiteSale(),
                                customer_scope=scope_for(self.req.env, self.website))
        country = self.env.ref('base.eg')
        partner = self.customer.partner_id
        partner.write({'street': 'Rollback only road', 'city': 'Cairo', 'country_id': country.id,
                       'phone': '+20 QA 85', 'zip': '11511'})
        cart = service.cart()
        key = 'qa85-genuine-free-confirm-only'
        payload = {'idempotency_key': key, 'cart_revision': cart['revision'],
                   'confirmed_total_minor': '0', 'currency': cart['currency']['code'],
                   'customer_note': ''}
        result = service.confirm(payload)
        self.assertEqual(result['state'], 'order_created')
        self.assertEqual(result['receipt_kind'], 'zero_total')
        self.assertEqual(result['payment_status'], 'success')
        self.assertEqual(service.outcome({'idempotency_key': key})['order']['id'], result['order']['id'])
        self.assertEqual(service.confirm(payload)['order']['id'], result['order']['id'])
        self.assertEqual(service.cart()['items'], [])
        actual = self.env['sale.order'].browse(result['order']['id'])
        self.assertEqual(actual.state, 'sale')
        self.assertFalse(actual.transaction_ids)
        self.assertFalse(actual.invoice_ids)
