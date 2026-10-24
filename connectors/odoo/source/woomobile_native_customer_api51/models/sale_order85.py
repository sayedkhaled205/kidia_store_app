"""Private proof fields on genuine website quotations, not parallel orders.

No new business workflow or customer-facing ORM permission is introduced.
The HTTP service may access these only after proving the native Cookie basket.
Import requires a normal module upgrade before enabling the HTTP feature gate.
"""

from odoo import fields, models


class SaleOrderNative85(models.Model):
    _inherit = 'sale.order'

    # A key cannot confirm a second quote even if two HTTP requests race while
    # their Cookie basket is first being created. Existing ordinary quotes have
    # a NULL key and are unaffected by PostgreSQL's uniqueness rule.
    _sql_constraints = [(
        'native_checkout_attempt85_unique',
        'unique(native_checkout_key85, website_id, company_id, native_cart_customer_uid85)',
        'This Native checkout attempt is already bound to its original quotation.',
    )]

    native_cart_lease85 = fields.Char(copy=False, index=True, groups='base.group_system')
    native_cart_customer_uid85 = fields.Integer(copy=False, groups='base.group_system')
    native_checkout_key85 = fields.Char(copy=False, index=True, groups='base.group_system')
    native_checkout_revision85 = fields.Char(copy=False, groups='base.group_system')
    native_checkout_note_hash85 = fields.Char(copy=False, groups='base.group_system')
    native_checkout_total_minor85 = fields.Char(copy=False, groups='base.group_system')
    native_checkout_currency85 = fields.Char(copy=False, groups='base.group_system')
    native_checkout_state85 = fields.Selection(
        [('dispatched', 'Native checkout dispatched'),
         ('payment_handoff', 'Native quotation payment handoff'),
         ('confirmed', 'Native checkout confirmed')],
        copy=False, groups='base.group_system',
    )
