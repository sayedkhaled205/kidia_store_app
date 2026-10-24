"""Native address projection exercises real inherited QWeb and submit hooks.

Only rollback fixtures; no order confirmation, payment, or business hook mocks.
"""
from .test_shipping100_orm import Shipping100TransactionTests
from ..services.customer_service import CustomerContractError


class Checkout101TransactionTests(Shipping100TransactionTests):
    def test_checkout101_guest_form_without_existing_address(self):
        self.service.add({'product_id': self.product.id, 'quantity': 1})
        form = self.service.address_metadata101({'address_type': 'billing', 'country_id': None})
        self.assertTrue(form['fields'])

    def form101(self):
        self.shipping_order100()
        return self.shipping_service100.address_metadata101({
            'address_type': 'billing', 'country_id': self.env.ref('base.eg').id,
        })

    def test_checkout101_merchant_inherited_label_is_used(self):
        self.env['ir.ui.view'].create({
            'name': 'Native101 rollback label', 'type': 'qweb',
            'inherit_id': self.env.ref('website_sale.address').id,
            'website_id': self.website.id,
            'arch_db': '''<data><xpath expr="//label[@for='o_state_id']" position="replace">
              <label for="o_state_id">Native101 governorate</label>
            </xpath></data>''',
        })
        fields = {field['name']: field for field in self.form101()['fields']}
        self.assertEqual(fields['state_id']['label'], 'Native101 governorate')
        self.assertTrue(fields['country_id']['required'])
        self.assertNotIn('csrf_token', fields)
        self.assertNotIn('partner_id', fields)

    def test_checkout101_same_address_uses_original_update_and_clears_delivery(self):
        form = self.form101()
        service = self.shipping_service100
        order = service.order()
        carrier = self.carrier100(self.env.ref('base.eg'), 12.34)
        service.shipping_select100({'carrier_id': carrier.id, 'cart_revision': service.cart()['revision']})
        fields = {field['name']: field['value'] for field in form['fields']}
        fields.update(name='Native85 rollback buyer', street='Native101 new road', city='Cairo',
                      country_id=str(self.env.ref('base.eg').id), zip='11511',
                      phone='+201000000000', email='native85-rollback@example.invalid')
        fields = {field['name']: fields.get(field['name'], '') for field in form['fields']}
        for field in form['fields']:
            if field['kind'] == 'select' and field['required'] and not fields[field['name']]:
                fields[field['name']] = field['choices'][0]['value']
        result = service.save_address101({'address_type': 'billing', 'fields': fields, 'use_for_shipping': True})
        self.assertEqual(order.partner_invoice_id, order.partner_shipping_id)
        self.assertEqual(order.partner_shipping_id.street, 'Native101 new road')
        self.assertFalse(order.carrier_id)
        self.assertFalse(order.order_line.filtered('is_delivery'))
        self.assertEqual(result['shipping_contract_version'], '100.1')
        self.assertEqual(order.state, 'draft')
        self.assertFalse(order.transaction_ids)

    def test_checkout101_unknown_merchant_field_blocks_instead_of_dropping(self):
        self.env['ir.ui.view'].create({
            'name': 'Native101 rollback unsupported', 'type': 'qweb',
            'inherit_id': self.env.ref('website_sale.address').id,
            'website_id': self.website.id,
            'arch_db': '''<data><xpath expr="//form" position="inside">
              <label for="native101_door">Door code</label>
              <input name="x_native101_door" id="native101_door" required="required"/>
            </xpath></data>''',
        })
        with self.assertRaises(CustomerContractError) as error:
            self.form101()
        self.assertEqual(error.exception.code, 'checkout_form_not_supported')

    def test_checkout101_caller_cannot_choose_partner_or_order(self):
        self.shipping_order100()
        for name in ('partner_id', 'order_id', 'callback', 'required_fields'):
            with self.subTest(field=name), self.assertRaises(CustomerContractError):
                self.shipping_service100.address_metadata101({
                    'address_type': 'billing', 'country_id': None, name: 1,
                })

    def test_checkout101_separate_delivery_does_not_overwrite_billing(self):
        self.customer.groups_id = [(4, self.env.ref('account.group_delivery_invoice_address').id)]
        self.shipping_order100()
        service = self.shipping_service100
        order = service.order()
        billing = order.partner_invoice_id
        old_street = billing.street
        form = service.address_metadata101({'address_type': 'delivery', 'country_id': self.env.ref('base.eg').id})
        self.assertTrue(form['separate_shipping_allowed'])
        values = {'name': 'Native101 rollback receiver', 'street': 'Native101 delivery only',
                  'city': 'Cairo', 'country_id': str(self.env.ref('base.eg').id),
                  'zip': '11511', 'email': 'native101@example.invalid', 'phone': '+201000000000'}
        fields = {field['name']: values.get(field['name'], field['value']) for field in form['fields']}
        for field in form['fields']:
            if field['kind'] == 'select' and field['required'] and not fields[field['name']]:
                fields[field['name']] = field['choices'][0]['value']
        service.save_address101({'address_type': 'delivery', 'fields': fields, 'use_for_shipping': False})
        self.assertEqual(order.partner_invoice_id, billing)
        self.assertEqual(billing.street, old_street)
        self.assertNotEqual(order.partner_shipping_id, billing)
        self.assertEqual(order.partner_shipping_id.street, 'Native101 delivery only')
        self.assertFalse(service.address_metadata101({
            'address_type': 'billing', 'country_id': self.env.ref('base.eg').id,
        })['use_same_address'])
        self.assertFalse(order.transaction_ids)
