"""Native transport around the installed Odoo 18 website_sale workflow.

The genuine website quote is the basket. Its ORM cart hooks calculate quantity,
stock, prices, taxes and delivery; its original validation confirms free orders.
Nonzero checkout hands the exact own quote to Odoo's existing public document
flow. No payment transaction is created, marked paid or simulated here.
"""

import hashlib
import json
import math
import secrets
from urllib.parse import parse_qs, urlencode, urljoin, urlsplit

from werkzeug.wrappers import Response as WerkzeugResponse

from odoo.exceptions import ValidationError
from odoo.tools.mail import plaintext2html

from .cart_contract85 import (
    ADDRESS_FIELDS, MAX_QUANTITY, add_fields, attempt_digest, attempt_key,
    cart_revision, confirm_fields, exact_fields, integral_quantity, update_fields,
)
from .customer_service import CustomerContractError, CustomerService, bounded_text, money_minor, positive_id
from .shipping100 import (
    SHIPPING_VERSION100, assert_shipping_mutable100, shipping_quotes100, select_shipping100,
)
from .checkout101 import CHECKOUT_FORM_VERSION101, ADDRESS_NAMES101, parse_address_form101


LEASE = 'woomobile_native_cart85_lease'
MAX_ADDRESS_FEEDBACK_BYTES85 = 20000


def address_feedback85(result):
    """Read the original website address route's bounded HTTP JSON feedback."""
    reject = lambda: CustomerContractError('checkout_address_feedback_invalid', 502)
    if isinstance(result, WerkzeugResponse):
        if (not 200 <= result.status_code < 300
                or (result.content_length is not None
                    and result.content_length > MAX_ADDRESS_FEEDBACK_BYTES85)):
            raise reject()
        try:
            result = result.get_data()
        except (RuntimeError, TypeError, ValueError):
            raise reject() from None
    if not isinstance(result, (str, bytes, bytearray)):
        raise reject()
    try:
        size = len(result.encode('utf-8')) if isinstance(result, str) else len(result)
        if size > MAX_ADDRESS_FEEDBACK_BYTES85:
            raise reject()
        feedback = json.loads(result)
    except (ValueError, UnicodeError, RecursionError):
        raise reject() from None
    if not isinstance(feedback, dict):
        raise reject()
    return feedback


class CheckoutRejected85(CustomerContractError):
    def __init__(self, code, key, customer_id, revision):
        super().__init__(code, 409)
        self.proof = {'state': 'rejected_before_dispatch', 'checkout_dispatched': False,
                      'idempotency_key': key,
                      'customer_id': customer_id, 'cart_revision': revision}


class CartService85:
    def __init__(self, req, website, *, controller, customer_scope=None):
        self.request = req
        # website_context reads website configuration under sudo. Restore the
        # actual request user before sale_get_order derives its buyer/pricelist.
        self.website = website.with_env(req.env).with_company(website.company_id)
        self.env = self.website.env
        self.session = req.session
        self.controller = controller
        self.scope = customer_scope
        self.uid = customer_scope.uid if customer_scope else 0
        claim = self.session.get(LEASE)
        if not isinstance(claim, dict) or (
            claim.get('website_id') != website.id
            or claim.get('company_id') != website.company_id.id
            or not isinstance(claim.get('lease'), str)
            or len(claim['lease']) != 64
        ):
            claim = {'website_id': website.id, 'company_id': website.company_id.id,
                     'lease': secrets.token_hex(32)}
            self.session[LEASE] = claim
        self.lease = claim['lease']

    def _same_store(self, order):
        return (order.website_id.id == self.website.id
                and order.company_id.id == self.website.company_id.id)

    def _lock(self, order):
        # The ID came from the trusted Cookie basket or exact own-key search,
        # never a caller-supplied order ID. Re-read after waiting for the lock.
        self.env.cr.execute('SELECT id FROM sale_order WHERE id = %s FOR UPDATE', [order.id])
        order.invalidate_recordset()
        if not order.exists() or not self._same_store(order):
            raise CustomerContractError('cart_not_found', 404)
        return order

    def _owned(self, order, *, allow_guest_rebind=False):
        if not self._same_store(order):
            return False
        if self.uid:
            if (allow_guest_rebind and order.native_cart_customer_uid85 == 0
                    and order.native_cart_lease85 == self.lease and order.state == 'draft'):
                return True  # sale_get_order performs Odoo's original login rebind next.
            return (order.partner_id.id == self.scope.partner_id
                    and order.native_cart_customer_uid85 in (0, self.uid))
        return (order.native_cart_customer_uid85 == 0
                and order.native_cart_lease85 in (False, self.lease))

    def _preflight(self):
        order_id = self.session.get('sale_order_id')
        candidate = self.env['sale.order'].sudo().browse(order_id).exists() if order_id else None
        if candidate:
            self._lock(candidate)
            if not self._owned(candidate, allow_guest_rebind=True):
                self.website.sale_reset()
                raise CustomerContractError('cart_session_changed', 401)
            if candidate.state != 'draft':
                self.website.sale_reset()
        elif self.uid:
            last = self.env.user.partner_id.last_website_so_id
            if last and (not self._same_store(last) or last.partner_id.id != self.scope.partner_id):
                # A server-only nonexisting sentinel prevents Odoo's implicit
                # last-cart fallback from mutating another website quotation.
                # force_create still uses its normal prepare/create hooks.
                self.session['sale_order_id'] = -1

    def order(self, *, create=False, mutable=False):
        self._preflight()
        order = self.website.sale_get_order(force_create=create)
        if not order:
            return order
        self._lock(order)
        if not self._owned(order):
            self.website.sale_reset()
            raise CustomerContractError('cart_session_changed', 401)
        if order.state != 'draft':
            self.website.sale_reset()
            return self.env['sale.order']
        if mutable and order.native_checkout_state85 in ('dispatched', 'payment_handoff'):
            raise CustomerContractError('checkout_outcome_required', 409)
        if not order.native_cart_lease85 or order.native_cart_customer_uid85 != self.uid:
            order.write({'native_cart_lease85': self.lease,
                         'native_cart_customer_uid85': self.uid})
        return order

    def _currency(self, currency):
        return {'code': currency.name, 'symbol': currency.symbol or currency.name,
                'minor_unit': currency.decimal_places}

    @staticmethod
    def _address(partner, *, empty=False):
        if empty or not partner:
            return {field: '' for field in ADDRESS_FIELDS}
        pieces = (partner.name or '').strip().split(' ', 1)
        return {
            'first_name': pieces[0] if pieces else '',
            'last_name': pieces[1] if len(pieces) > 1 else '',
            'company': partner.company_name or '', 'address_1': partner.street or '',
            'address_2': partner.street2 or '', 'city': partner.city or '',
            'state': partner.state_id.code or '', 'postcode': partner.zip or '',
            'country': partner.country_id.code or '', 'email': partner.email or '',
            'phone': partner.phone or partner.mobile or '',
        }

    def snapshot(self, order):
        currency = order.currency_id if order else self.website.currency_id
        digits = currency.decimal_places
        items = []
        if order:
            for line in order.website_order_line:
                product = line.product_id
                if not product or line.display_type or line.is_delivery:
                    continue
                if product.type == 'combo' or line.combo_item_id:
                    raise CustomerContractError('combo_cart_configuration_required', 422)
                amount = integral_quantity(line.product_uom_qty)
                remaining = None
                maximum = MAX_QUANTITY
                allow_backorder = bool(getattr(product, 'allow_out_of_stock_order', True))
                if (getattr(product, 'is_storable', False)
                        and hasattr(order, '_get_cart_and_free_qty')):
                    cart_qty, free_qty = order._get_cart_and_free_qty(product, line=line)
                    remaining = max(0, math.floor(free_qty))
                    if not allow_backorder:
                        maximum = max(0, math.floor(free_qty - (cart_qty - line.product_uom_qty)))
                reduced_price = line.price_reduce_taxexcl if 'price_reduce_taxexcl' in line._fields else line.price_unit
                items.append({
                    'line_id': line.id, 'product_id': product.id, 'quantity': amount,
                    'name': line.name_short or product.display_name, 'sku': product.default_code or '',
                    'image_url': urljoin(self.request.httprequest.host_url,
                                         self.website.image_url(product, 'image_512')),
                    'unit_price_minor': money_minor(reduced_price, digits),
                    'subtotal_minor': money_minor(line.price_subtotal, digits),
                    'tax_minor': money_minor(line.price_tax, digits),
                    'total_minor': money_minor(line.price_total, digits),
                    'quantity_limit': {'minimum': 1, 'maximum': min(MAX_QUANTITY, maximum),
                                       'multiple_of': 1, 'editable': maximum >= 1},
                    'backorders_allowed': allow_backorder, 'stock_remaining': remaining,
                })
        anonymous = not order or order._is_anonymous_cart()
        shipping_lines = order.order_line.filtered('is_delivery') if order else self.env['sale.order.line']
        result = {
            'currency': self._currency(currency), 'items': items,
            'totals': {
                'untaxed_minor': money_minor(order.amount_untaxed if order else 0, digits),
                'tax_minor': money_minor(order.amount_tax if order else 0, digits),
                'total_minor': money_minor(order.amount_total if order else 0, digits),
                'items_minor': money_minor(sum(order._get_non_delivery_lines().mapped('price_subtotal')) if order else 0, digits),
                'items_tax_minor': money_minor(sum(order._get_non_delivery_lines().mapped('price_tax')) if order else 0, digits),
                'shipping_minor': money_minor(sum(shipping_lines.mapped('price_subtotal')), digits),
                'shipping_tax_minor': money_minor(sum(shipping_lines.mapped('price_tax')), digits),
            },
            'billing_address': self._address(order.partner_invoice_id if order else None, empty=anonymous),
            'shipping_address': self._address(order.partner_shipping_id if order else None, empty=anonymous),
            'needs_shipping': bool(order and order._has_deliverable_products()),
            'has_calculated_shipping': bool(order and order._is_delivery_ready()),
            'checkout_zero_total': bool(order and currency.is_zero(order.amount_total)),
        }
        result['revision'] = cart_revision(result, order_id=order.id if order else 0)
        # The original website address form uses this same country reference
        # list. These public choices are not quote/payment authority and must
        # not change the cart fingerprint when only UI language changes.
        countries = self.env['res.country'].sudo().search([], limit=501)
        if len(countries) > 500:
            raise CustomerContractError('checkout_country_configuration_required', 422)
        result['checkout_metadata'] = {
            'countries': [{'id': country.id, 'code': country.code, 'name': country.name}
                          for country in countries],
            'account_on_checkout': self.website.account_on_checkout,
        }
        return result

    def cart(self):
        order = self.order()
        if order and not order.native_checkout_state85:
            order._recompute_taxes()
            order._recompute_prices()
        return self.snapshot(order)

    def add(self, payload):
        product_id, amount = add_fields(payload)
        product = self.env['product.product'].browse(product_id).exists()
        if (not product or not product.active or not product._is_add_to_cart_allowed()
                or not product.product_tmpl_id.filtered_domain(self.website.sale_product_domain())):
            raise CustomerContractError('cart_product_not_available', 404)
        if product.type == 'combo' or any(
            value.is_custom or value.attribute_id.create_variant == 'no_variant'
            for value in product.product_template_attribute_value_ids
        ):
            raise CustomerContractError('product_configuration_required', 422)
        order = self.order(create=True, mutable=True)
        result = order._cart_update(product_id=product_id, add_qty=amount)
        self.session['website_sale_cart_quantity'] = order.cart_quantity
        return self.snapshot(order), result.get('warning') or ''

    def update(self, line_id, payload):
        amount = update_fields(payload)
        order = self.order(mutable=True)
        line_id = positive_id(line_id)
        line = order.website_order_line.filtered(lambda row: row.id == line_id) if order else None
        if not line or line.is_delivery or line.product_id.type == 'combo' or line.combo_item_id:
            raise CustomerContractError('cart_line_not_found', 404)
        # Odoo treats set_qty=0 as add_qty unless add_qty=None is explicit.
        result = order._cart_update(product_id=line.product_id.id, line_id=line.id,
                                    add_qty=None, set_qty=amount)
        self.session['website_sale_cart_quantity'] = order.cart_quantity
        if not order.cart_quantity:
            self.website.sale_reset()
        return self.snapshot(order), result.get('warning') or ''

    def _address_form(self, data):
        exact_fields(data, ADDRESS_FIELDS)
        data = {field: bounded_text(value, maximum=254 if field == 'email' else 240)
                for field, value in data.items()}
        country = self.env['res.country'].search([('code', '=', data['country'].upper())], limit=1)
        state = self.env['res.country.state'].search([
            ('country_id', '=', country.id), ('code', '=', data['state']),
        ], limit=1) if data['state'] else self.env['res.country.state']
        if not country or (data['state'] and not state):
            raise CustomerContractError('invalid_country_or_state')
        return {'name': (data['first_name'] + ' ' + data['last_name']).strip(),
                'company_name': data['company'], 'street': data['address_1'],
                'street2': data['address_2'], 'city': data['city'], 'zip': data['postcode'],
                'country_id': str(country.id), 'state_id': str(state.id) if state else False,
                'email': data['email'], 'phone': data['phone']}

    def addresses(self, payload):
        exact_fields(payload, {'billing_address', 'shipping_address'})
        order = self.order(mutable=True)
        if not order or not order.cart_quantity:
            raise CustomerContractError('cart_empty', 409)
        for address_type, key in [('billing', 'billing_address'), ('delivery', 'shipping_address')]:
            if address_type == 'delivery' and order.only_services:
                continue
            form = self._address_form(payload[key])
            partner = order.partner_invoice_id if address_type == 'billing' else order.partner_shipping_id
            if self.scope and not order._is_anonymous_cart():
                # Normal website_sale permits commercial descendants; this
                # transport is deliberately exact-customer like account51.
                CustomerService(self.env, self.scope)._address(partner.id)
            feedback = address_feedback85(self.controller.shop_address_submit(
                partner_id=partner.id if not order._is_anonymous_cart() else None,
                address_type=address_type, use_delivery_as_billing='false', **form,
            ))
            if feedback.get('invalid_fields') or feedback.get('messages'):
                raise CustomerContractError('checkout_address_invalid', 400)
            if not str(feedback.get('redirectUrl', '')).startswith('/shop/'):
                raise CustomerContractError('checkout_address_incomplete', 409)
        # Same preparation as website_sale.shop_checkout: choose the existing
        # compatible merchant delivery method and let its own rate hook price it.
        if order._has_deliverable_products():
            available = order._get_delivery_methods()
            method = order._get_preferred_delivery_method(available)
            if method:
                order._set_delivery_method(method, rate=method.rate_shipment(order))
        order._recompute_taxes()
        order._recompute_prices()
        return self.snapshot(order)

    def _shipping_snapshot100(self, order):
        return {
            'cart': self.snapshot(order),
            'shipping_contract_version': SHIPPING_VERSION100,
            'shipping_rates': shipping_quotes100(order),
        }

    def address_metadata101(self, payload):
        exact_fields(payload, {'address_type', 'country_id'})
        address_type = payload['address_type']
        if address_type not in ('billing', 'delivery'):
            raise CustomerContractError('invalid_address_type')
        order = self.order(mutable=True)
        if not order or not order.cart_quantity:
            raise CustomerContractError('cart_empty', 409)
        assert_shipping_mutable100(order)
        separate = bool(not order.only_services and self.env.user.has_group(
            'account.group_delivery_invoice_address'))
        if address_type == 'delivery' and not separate:
            raise CustomerContractError('separate_shipping_unavailable', 409)
        partner = order.partner_invoice_id if address_type == 'billing' else order.partner_shipping_id
        if (order._is_anonymous_cart() or
                (address_type == 'delivery' and partner == order.partner_invoice_id)):
            # A separate delivery address must be a new address when the quote
            # currently shares one partner for billing and shipping.
            partner = self.env['res.partner'].sudo().browse()
        elif self.scope:
            CustomerService(self.env, self.scope)._address(partner.id)
        values = self.controller._prepare_address_form_values(
            order, partner, address_type, use_delivery_as_billing=not separate,
        )
        country_id = payload['country_id']
        if country_id is not None:
            country = self.env['res.country'].sudo().browse(positive_id(country_id)).exists()
            if not country or country not in values['countries']:
                raise CustomerContractError('invalid_country_or_state')
            values.update(country=country, country_states=country.state_ids,
                          state_id=partner.state_id.id if partner.country_id == country else False,
                          zip_before_city='zip' in country.get_address_fields() and 'city' in country.get_address_fields()
                          and country.get_address_fields().index('zip') < country.get_address_fields().index('city'))
        country = values['country']
        mandatory = (self.controller._get_mandatory_billing_address_fields(country)
                     if address_type == 'billing'
                     else self.controller._get_mandatory_delivery_address_fields(country))
        markup = self.env['ir.ui.view']._render_template('website_sale.address', values)
        return {'checkout_form_contract_version': CHECKOUT_FORM_VERSION101,
                'address_type': address_type,
                'separate_shipping_allowed': separate,
                'use_same_address': not separate or order.partner_invoice_id == order.partner_shipping_id,
                'fields': parse_address_form101(markup, mandatory),
                'cart': self.snapshot(order)}

    def save_address101(self, payload):
        exact_fields(payload, {'address_type', 'fields', 'use_for_shipping'})
        data = payload['fields']
        if (not isinstance(data, dict) or set(data) - ADDRESS_NAMES101
                or not isinstance(payload['use_for_shipping'], bool)):
            raise CustomerContractError('invalid_cart_fields')
        data = {key: bounded_text(value, maximum=254) for key, value in data.items()}
        country_id = data.get('country_id', '')
        if not country_id.isdigit() or not 1 <= int(country_id) <= 2147483647:
            raise CustomerContractError('invalid_country_or_state')
        schema = self.address_metadata101({'address_type': payload['address_type'],
                                          'country_id': int(country_id)})
        fields = {field['name']: field for field in schema['fields']}
        if set(data) != set(fields):
            raise CustomerContractError('checkout_form_changed', 409)
        for key, value in data.items():
            field = fields[key]
            if ((field['required'] and not value)
                    or (field['kind'] == 'select' and value
                        and value not in {choice['value'] for choice in field['choices']})
                    or (field['readonly'] and value != field['value'])):
                raise CustomerContractError('checkout_address_invalid')
        order = self.order(mutable=True)
        kind = payload['address_type']
        same = payload['use_for_shipping']
        if kind == 'delivery' and same:
            raise CustomerContractError('invalid_cart_fields')
        if not schema['separate_shipping_allowed']:
            same = True  # Same restriction as the actual merchant form.
        partner = order.partner_invoice_id if kind == 'billing' else order.partner_shipping_id
        feedback = address_feedback85(self.controller.shop_address_submit(
            partner_id=(partner.id if not order._is_anonymous_cart()
                        and not (kind == 'delivery' and partner == order.partner_invoice_id) else None),
            # The original combined-address operation is delivery + billing,
            # not billing alone (which leaves an old delivery destination).
            address_type='delivery' if same else kind,
            use_delivery_as_billing='true' if same else 'false',
            required_fields=','.join(name for name, field in fields.items() if field['required']),
            **data,
        ))
        if feedback.get('invalid_fields') or feedback.get('missing_fields') or feedback.get('messages'):
            raise CustomerContractError('checkout_address_invalid')
        if not str(feedback.get('redirectUrl', '')).startswith('/shop/'):
            raise CustomerContractError('checkout_address_incomplete', 409)
        order.invalidate_recordset()
        order._recompute_taxes()
        order._recompute_prices()
        # Remove a no-longer-available delivery line after the destination changes.
        # A fresh explicit carrier selection calculates its current server rate.
        if order.carrier_id:
            order._remove_delivery_line()
            order.carrier_id = False
        return self._shipping_snapshot100(order)

    def shipping_quote100(self, payload):
        exact_fields(payload, set())
        order = self.order(mutable=True)
        assert_shipping_mutable100(order)
        if order:
            order._recompute_taxes()
            order._recompute_prices()
        return self._shipping_snapshot100(order)

    def shipping_select100(self, payload):
        exact_fields(payload, {'carrier_id', 'cart_revision'})
        carrier_id = positive_id(payload['carrier_id'])
        order = self.order(mutable=True)
        if not order or not order.cart_quantity:
            raise CustomerContractError('cart_empty', 409)
        assert_shipping_mutable100(order)
        current = self.cart()
        if payload['cart_revision'] != current['revision']:
            raise CustomerContractError('cart_revision_changed', 409)
        select_shipping100(order, carrier_id)
        return self._shipping_snapshot100(order)

    def _attempt_order(self, key):
        domain = [('website_id', '=', self.website.id),
                  ('company_id', '=', self.website.company_id.id),
                  ('native_checkout_key85', '=', attempt_digest(key)),
                  ('native_cart_customer_uid85', '=', self.uid)]
        if self.uid:
            domain.append(('partner_id', '=', self.scope.partner_id))
        else:
            domain.append(('native_cart_lease85', '=', self.lease))
        order = self.env['sale.order'].sudo().search(domain, limit=1)
        return self._lock(order) if order else order

    def _payment_url(self, order):
        origin = self.request.httprequest.host_url
        if order._has_to_be_paid():
            relative = order.get_portal_url()
        else:
            # Installed original abandoned-cart recovery retains this exact
            # quote. Never force merge/squash or alter merchant payment flags.
            relative = '/shop/cart?' + urlencode({'access_token': order._portal_ensure_token()})
        target = urlsplit(urljoin(origin, relative))
        trusted = urlsplit(origin)
        if (target.scheme != 'https' or target.netloc != trusted.netloc
                or target.path not in ('/shop/cart', '/my/orders/%s' % order.id)
                or not parse_qs(target.query).get('access_token')):
            raise CustomerContractError('invalid_store_payment_handoff', 503)
        return target.geturl()

    def _checkout_data(self, order, key):
        confirmed = order.state in ('sale', 'done')
        free = order.currency_id.is_zero(order.amount_total)
        paid = confirmed and (free or order._is_paid())
        state = 'order_created' if paid else 'order_created_unpaid' if confirmed else 'payment_handoff'
        result = {'state': state, 'idempotency_key': key, 'customer_id': self.uid or None,
                  'order': {'id': order.id, 'status': order.state,
                            'total_minor': money_minor(order.amount_total, order.currency_id.decimal_places),
                            'currency': order.currency_id.name, 'minor_unit': order.currency_id.decimal_places},
                  'payment_status': 'success' if paid else 'pending',
                  'receipt_kind': 'zero_total' if paid and free else 'platform_payment' if paid else None,
                  'redirect_url': None if confirmed else self._payment_url(order)}
        if confirmed and self.session.get('sale_order_id') == order.id:
            self.website.sale_reset()
        return result

    def confirm(self, payload):
        key, revision, total, currency, note = confirm_fields(payload)
        note_hash = hashlib.sha256(note.encode('utf-8')).hexdigest()
        previous = self._attempt_order(key)
        if previous:
            if (previous.native_checkout_revision85 != revision
                    or previous.native_checkout_total_minor85 != total
                    or previous.native_checkout_currency85 != currency
                    or previous.native_checkout_note_hash85 != note_hash):
                raise CustomerContractError('checkout_attempt_changed', 409)
            return self._checkout_data(previous, key)
        order = self.order()
        # A concurrent confirm may have committed while order() waited for the
        # quote lock. Recheck the exact attempt before any empty-cart rejection.
        previous = self._attempt_order(key)
        if previous:
            if (previous.native_checkout_revision85 != revision
                    or previous.native_checkout_total_minor85 != total
                    or previous.native_checkout_currency85 != currency
                    or previous.native_checkout_note_hash85 != note_hash):
                raise CustomerContractError('checkout_attempt_changed', 409)
            return self._checkout_data(previous, key)
        if not order:
            raise CheckoutRejected85('cart_empty', key, self.uid or None, revision)
        current = self.snapshot(order)
        reject = lambda code: CheckoutRejected85(code, key, self.uid or None, current['revision'])
        if order.native_checkout_state85:
            raise CustomerContractError('checkout_outcome_required', 409)
        order._recompute_taxes()
        order._recompute_prices()
        current = self.snapshot(order)
        if (current['revision'] != revision or current['totals']['total_minor'] != total
                or current['currency']['code'] != currency):
            raise reject('checkout_cart_changed')
        if self.controller._check_cart_and_addresses(order):
            raise reject('checkout_address_or_account_required')
        if self.controller._check_shipping_method(order) or self.controller._get_shop_payment_errors(order):
            raise reject('checkout_shipping_required')
        try:
            order._check_cart_is_ready_to_be_paid()
        except ValidationError:
            raise reject('checkout_cart_not_ready') from None
        order.write({'native_checkout_key85': attempt_digest(key),
                     'native_checkout_revision85': revision,
                     'native_checkout_note_hash85': note_hash,
                     'native_checkout_total_minor85': total,
                     'native_checkout_currency85': currency,
                     'native_checkout_state85': 'dispatched'})
        self.session['sale_last_order_id'] = order.id
        if note:
            # Standard own document chatter, not an overwrite of merchant
            # terms and not a generic message/model API.
            order.message_post(body=plaintext2html(note), message_type='comment',
                               subtype_xmlid='mail.mt_comment',
                               author_id=order.partner_id.id)
        if order.currency_id.is_zero(order.amount_total):
            # Exact installed shop_payment_validate model sequence, including
            # all confirmation/email/stock hooks. Never a direct state write.
            order._validate_order()
            if order.state not in ('sale', 'done'):
                raise CustomerContractError('checkout_outcome_unresolved', 503)
            order.native_checkout_state85 = 'confirmed'
        else:
            self._payment_url(order)  # Prove original same-store route before recording handoff.
            order.native_checkout_state85 = 'payment_handoff'
        return self._checkout_data(order, key)

    def outcome(self, payload):
        exact_fields(payload, {'idempotency_key'})
        key = attempt_key(payload['idempotency_key'])
        order = self._attempt_order(key)
        if not order:
            return {'state': 'unknown', 'idempotency_key': key, 'customer_id': self.uid or None}
        if order.state == 'cancel':
            return {'state': 'cancelled', 'idempotency_key': key, 'customer_id': self.uid or None}
        return self._checkout_data(order, key)
