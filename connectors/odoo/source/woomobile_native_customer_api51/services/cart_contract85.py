"""Bounded Native inputs; Odoo, not this module, calculates commerce amounts.

These helpers do not claim that an installed HTTP contract has been accepted.
The cart controller is separately gated until its matched Native client deploys.
"""

import hashlib
import json
import re
from decimal import Decimal, InvalidOperation

from .customer_service import CustomerContractError, positive_id


CART_VERSION = '85.1'
MAX_QUANTITY = 2147483647
ADDRESS_FIELDS = frozenset({
    'first_name', 'last_name', 'company', 'address_1', 'address_2', 'city',
    'state', 'postcode', 'country', 'email', 'phone',
})


def enabled_for85(website):
    return ('native_cart_lease85' in website.env['sale.order']._fields
            and website.env['ir.config_parameter'].sudo().get_param(
                'woomobile.native_cart85.enabled.%s' % website.id, '0',
            ) == '1')


def exact_fields(payload, fields):
    if not isinstance(payload, dict) or set(payload) != set(fields):
        raise CustomerContractError('invalid_cart_fields')
    return payload


def quantity(value, *, allow_zero=False):
    if isinstance(value, bool) or not isinstance(value, int):
        raise CustomerContractError('invalid_cart_quantity')
    if value < (0 if allow_zero else 1) or value > MAX_QUANTITY:
        raise CustomerContractError('invalid_cart_quantity')
    return value


def add_fields(payload):
    exact_fields(payload, {'product_id', 'quantity'})
    return positive_id(payload['product_id']), quantity(payload['quantity'])


def update_fields(payload):
    exact_fields(payload, {'quantity'})
    return quantity(payload['quantity'], allow_zero=True)


def attempt_key(value):
    # The same key is replayable for outcome recovery only. It never selects an
    # order without the private server session lease and exact buyer scope.
    if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9._:-]{16,128}', value):
        raise CustomerContractError('invalid_checkout_attempt')
    return value


def attempt_digest(value):
    return hashlib.sha256(attempt_key(value).encode('ascii')).hexdigest()


def confirm_fields(payload):
    exact_fields(payload, {
        'idempotency_key', 'cart_revision', 'confirmed_total_minor', 'currency', 'customer_note',
    })
    key = attempt_key(payload['idempotency_key'])
    revision = payload['cart_revision']
    total = payload['confirmed_total_minor']
    currency = payload['currency']
    if not isinstance(revision, str) or not re.fullmatch(r'[a-f0-9]{64}', revision):
        raise CustomerContractError('invalid_cart_revision')
    if not isinstance(total, str) or not re.fullmatch(r'0|[1-9][0-9]{0,17}', total):
        raise CustomerContractError('invalid_checkout_total')
    if not isinstance(currency, str) or not re.fullmatch(r'[A-Z]{3}', currency):
        raise CustomerContractError('invalid_checkout_currency')
    from .customer_service import bounded_text
    note = bounded_text(payload['customer_note'], maximum=4000)
    return key, revision, total, currency, note


def cart_revision(snapshot, *, order_id):
    # Includes the genuine quote identity without exposing its ID as authority
    # to the caller. Identical visible carts from different quotes do not share
    # an accepted checkout fingerprint.
    value = {'order_id': order_id, 'cart': snapshot}
    return hashlib.sha256(json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(',', ':'),
    ).encode('utf-8')).hexdigest()


def integral_quantity(value):
    # Native cart domain currently represents integer quantities. Do not round
    # an existing fractional Odoo quotation into a different commercial order.
    try:
        number = Decimal(str(value))
    except (InvalidOperation, ValueError):
        raise CustomerContractError('fractional_cart_not_supported', 422) from None
    if not number.is_finite() or number != number.to_integral_value():
        raise CustomerContractError('fractional_cart_not_supported', 422)
    return quantity(int(number), allow_zero=True)
