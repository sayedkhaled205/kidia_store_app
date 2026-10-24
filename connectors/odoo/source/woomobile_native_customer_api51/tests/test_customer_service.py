"""Odoo transaction tests: fixtures are discarded, no confirmation/payment.

Run only on a disposable local/staging test database with Odoo --test-enable.
These are separate from the executable host contract tests and cannot be
reported as passed until an actual Odoo 18 test run returns success.
"""

from datetime import datetime

from odoo.tests.common import TransactionCase, tagged

from ..services.customer_service import CustomerContractError, CustomerService, scope_for


@tagged('post_install', '-at_install', 'woomobile_customer51')
class CustomerServiceTransactionTests(TransactionCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.company = cls.env.company
        cls.website = cls.env['website'].create({
            'name': 'Native 51 rollback only', 'domain': 'https://native51.example.invalid',
            'company_id': cls.company.id,
        })
        cls.other_website = cls.env['website'].create({
            'name': 'Other native 51 rollback only', 'domain': 'https://other51.example.invalid',
            'company_id': cls.company.id,
        })
        portal_group = cls.env.ref('base.group_portal')
        cls.customer_a = cls.env['res.users'].with_context(no_reset_password=True).create({
            'name': 'Native QA A', 'login': 'native51-a@example.invalid',
            'email': 'native51-a@example.invalid', 'company_id': cls.company.id,
            'company_ids': [(6, 0, cls.company.ids)], 'groups_id': [(6, 0, portal_group.ids)],
        })
        cls.customer_b = cls.env['res.users'].with_context(no_reset_password=True).create({
            'name': 'Native QA B', 'login': 'native51-b@example.invalid',
            'email': 'native51-b@example.invalid', 'company_id': cls.company.id,
            'company_ids': [(6, 0, cls.company.ids)], 'groups_id': [(6, 0, portal_group.ids)],
        })
        cls.address_a = cls.env['res.partner'].create({
            'name': 'QA delivery A', 'parent_id': cls.customer_a.partner_id.id,
            'type': 'delivery', 'company_id': cls.company.id, 'website_id': cls.website.id,
        })
        cls.address_b = cls.env['res.partner'].create({
            'name': 'QA delivery B', 'parent_id': cls.customer_b.partner_id.id,
            'type': 'delivery', 'company_id': cls.company.id, 'website_id': cls.website.id,
        })
        # State-only test quotations, no lines or action_confirm, invoice,
        # picking, payment, webhook dispatch or explicit transaction commit.
        cls.order_a = cls.env['sale.order'].create({
            'partner_id': cls.customer_a.partner_id.id, 'website_id': cls.website.id,
            'company_id': cls.company.id, 'state': 'sale',
        })
        cls.order_b = cls.env['sale.order'].create({
            'partner_id': cls.customer_b.partner_id.id, 'website_id': cls.website.id,
            'company_id': cls.company.id, 'state': 'sale',
        })
        cls.order_other_store = cls.env['sale.order'].create({
            'partner_id': cls.customer_a.partner_id.id, 'website_id': cls.other_website.id,
            'company_id': cls.company.id, 'state': 'sale',
        })
        # Odoo's normal sale portal rule requires the customer to follow the
        # order. action_confirm normally subscribes that customer; these
        # state-only rollback fixtures deliberately do not call that workflow.
        # Subscribe only each new fixture's owning partner, without posting a
        # message or bypassing portal ACLs. Foreign/store-negative tests remain.
        for order in (cls.order_a, cls.order_b, cls.order_other_store):
            order.message_subscribe(partner_ids=order.partner_id.ids)

    def service_a(self):
        env = self.env(user=self.customer_a.id)
        return CustomerService(env, scope_for(env, self.website))

    def test_profile_read_and_write_exact_customer(self):
        service = self.service_a()
        self.assertEqual(service.profile()['id'], self.customer_a.id)
        service.update_profile({'phone': '+20 QA 51'})
        self.assertEqual(self.customer_a.partner_id.phone, '+20 QA 51')
        self.assertNotEqual(self.customer_b.partner_id.phone, '+20 QA 51')
        with self.assertRaises(CustomerContractError):
            service.update_profile({'partner_id': self.customer_b.partner_id.id, 'phone': 'bad'})

    def test_address_foreign_customer_and_other_website_denied(self):
        service = self.service_a()
        self.assertIn(self.address_a.id, [item['id'] for item in service.addresses()['items']])
        with self.assertRaises(CustomerContractError):
            service.update_address(self.address_b.id, {'street': 'bad'})
        self.assertFalse(self.address_b.street)
        self.address_a.website_id = self.other_website
        with self.assertRaises(CustomerContractError):
            service.update_address(self.address_a.id, {'street': 'bad'})

    def test_address_relationship_is_immutable(self):
        service = self.service_a()
        with self.assertRaises(CustomerContractError):
            service.update_address(self.address_a.id, {'parent_id': self.customer_b.partner_id.id})
        self.assertEqual(self.address_a.parent_id, self.customer_a.partner_id)

    def test_address_create_is_bound_to_authenticated_customer(self):
        service = self.service_a()
        created = service.create_address({'type': 'delivery', 'name': 'New QA', 'street': 'Test 51'})
        record = self.env['res.partner'].browse(created['id'])
        self.assertEqual(record.parent_id, self.customer_a.partner_id)
        self.assertEqual(record.website_id, self.website)
        self.assertEqual(record.company_id, self.company)
        self.assertFalse(record.user_ids)

    def test_orders_retain_acl_plus_exact_customer_and_store_scope(self):
        service = self.service_a()
        found = {item['id'] for item in service.orders()['items']}
        self.assertIn(self.order_a.id, found)
        self.assertNotIn(self.order_b.id, found)
        self.assertNotIn(self.order_other_store.id, found)
        for order in [self.order_b, self.order_other_store]:
            with self.assertRaises(CustomerContractError):
                service.order(order.id)

    def test_shared_commercial_parent_does_not_grant_sibling_order_access(self):
        shared = self.env['res.partner'].create({'name': 'Shared QA organization', 'is_company': True})
        self.customer_a.partner_id.parent_id = shared
        self.customer_b.partner_id.parent_id = shared
        service = self.service_a()
        self.assertNotIn(self.order_b.id, {item['id'] for item in service.orders()['items']})
        with self.assertRaises(CustomerContractError):
            service.order(self.order_b.id)

    def test_revisions_follow_own_profile_not_foreign_customer(self):
        service = self.service_a()
        before = service.revision()
        self.customer_b.partner_id.phone = '+20 Other QA'
        self.assertEqual(before, service.revision())
        self.customer_a.partner_id.phone = '+20 Own QA'
        self.assertNotEqual(before['profile'], service.revision()['profile'])

    def _restore_order_timestamp(self, order, timestamp):
        # These IDs are newly-created TransactionCase fixtures only. Keep the
        # parent timestamp identical to prove revision does not depend on it.
        self.env.cr.execute('UPDATE sale_order SET write_date = %s WHERE id = %s',
                            [timestamp, order.id])
        order.invalidate_recordset(['write_date'])
        self.assertEqual(order.write_date, timestamp)

    def test_order_revision_tracks_state_with_fixed_timestamp(self):
        service = self.service_a()
        timestamp = self.order_a.write_date
        before = service.revision()['orders']
        # No action_cancel/stock/invoice/payment workflow; fixture state only.
        self.order_a.write({'state': 'cancel'})
        self._restore_order_timestamp(self.order_a, timestamp)
        self.assertNotEqual(before, service.revision()['orders'])

    def test_order_revision_tracks_lines_and_amounts_with_fixed_parent_timestamp(self):
        # Build a draft fixture service line first: no procurement/stock effect.
        self.order_a.write({'state': 'draft'})
        product = self.env['product.product'].create({
            'name': 'Native QA rollback-only service', 'type': 'service', 'list_price': 10,
        })
        line = self.env['sale.order.line'].create({
            'order_id': self.order_a.id, 'product_id': product.id,
            'name': 'Native QA line', 'product_uom_qty': 1,
            'product_uom': product.uom_id.id, 'price_unit': 10,
            'tax_id': [(5, 0, 0)],
        })
        self.order_a.write({'state': 'sale'})
        service = self.service_a()
        timestamp = self.order_a.write_date
        before = service.revision()['orders']
        line.write({'name': 'Native QA corrected visible line'})
        self._restore_order_timestamp(self.order_a, timestamp)
        self.assertNotEqual(before, service.revision()['orders'])
        before = service.revision()['orders']
        line.write({'product_uom_qty': 2, 'price_unit': 12})
        self._restore_order_timestamp(self.order_a, timestamp)
        self.assertNotEqual(before, service.revision()['orders'])

    def test_revision_older_order_and_foreign_order_are_separate(self):
        earlier = self.env['sale.order'].create({
            'partner_id': self.customer_a.partner_id.id, 'website_id': self.website.id,
            'company_id': self.company.id, 'state': 'sale', 'name': 'Earlier QA order',
            'date_order': datetime(2020, 1, 1, 12, 0),
        })
        earlier.message_subscribe(partner_ids=earlier.partner_id.ids)
        service = self.service_a()
        timestamp = earlier.write_date
        before = service.revision()['orders']
        earlier.write({'name': 'Corrected earlier QA order'})
        self._restore_order_timestamp(earlier, timestamp)
        self.assertNotEqual(before, service.revision()['orders'])
        before = service.revision()['orders']
        self.order_b.write({'name': 'Foreign customer QA change', 'state': 'cancel'})
        self.order_other_store.write({'name': 'Foreign website QA change', 'state': 'cancel'})
        self.assertEqual(before, service.revision()['orders'])

    def test_internal_and_changed_identity_rejected(self):
        with self.assertRaises(CustomerContractError):
            scope_for(self.env, self.website)
        scope = scope_for(self.env(user=self.customer_a.id), self.website)
        with self.assertRaises(CustomerContractError):
            CustomerService(self.env(user=self.customer_b.id), scope)
