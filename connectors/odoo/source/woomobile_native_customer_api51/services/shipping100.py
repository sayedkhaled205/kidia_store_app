"""Website-owned carrier quotes for the native checkout transport.

Carrier availability, prices, taxes and selected delivery lines come from Odoo's
normal hooks. A client never supplies a carrier price, tax, partner or order ID.
"""

from decimal import Decimal, InvalidOperation

from .customer_service import CustomerContractError, money_minor


SHIPPING_VERSION100 = '100.1'


def _valid_rate100(rate):
    if not isinstance(rate, dict) or rate.get('success') is not True:
        return False
    price = rate.get('price')
    if isinstance(price, bool) or not isinstance(price, (int, float, Decimal)):
        return False
    try:
        amount = Decimal(str(price))
        return amount.is_finite() and amount >= 0
    except (InvalidOperation, ValueError):
        return False


def carrier_quote100(carrier, order, rate):
    """Use the same fiscal-position/tax computation as website_sale Delivery."""
    if not _valid_rate100(rate):
        return None
    taxes = carrier.product_id.taxes_id.filtered(lambda tax: tax.company_id == order.company_id)
    taxes = order.fiscal_position_id.map_tax(taxes)
    amounts = taxes.compute_all(
        rate['price'], currency=order.currency_id, quantity=1.0,
        product=carrier.product_id, partner=order.partner_shipping_id,
    )
    excluded, included = amounts['total_excluded'], amounts['total_included']
    digits = order.currency_id.decimal_places
    return {
        'carrier_id': carrier.id,
        'name': carrier.name,
        'price_minor': money_minor(excluded, digits),
        'tax_minor': money_minor(included - excluded, digits),
        'display_price_minor': money_minor(
            excluded if order.website_id.show_line_subtotals_tax_selection == 'tax_excluded'
            else included, digits,
        ),
        'selected': order.carrier_id.id == carrier.id and bool(order._is_delivery_ready()),
        'estimated': carrier.invoice_policy == 'real',
    }


def shipping_quotes100(order):
    if not order or not order._has_deliverable_products():
        return []
    result = []
    carriers = order._get_delivery_methods()
    if len(carriers) > 100:
        raise CustomerContractError('shipping_configuration_too_large', 422)
    for carrier in carriers:
        # This invokes the installed merchant carrier, including custom carriers.
        rate = carrier.rate_shipment(order.with_context(
            express_checkout_partial_delivery_address=False,
        ))
        quote = carrier_quote100(carrier, order, rate)
        if quote is not None:
            result.append(quote)
    return result


def assert_shipping_mutable100(order):
    if not order:
        return
    if any(tx.state not in ('draft', 'cancel', 'error') for tx in order.transaction_ids):
        # Same payment lock as the normal website set_delivery_method route.
        raise CustomerContractError('checkout_outcome_required', 409)


def select_shipping100(order, carrier_id):
    if not order or not order._has_deliverable_products():
        raise CustomerContractError('shipping_not_required', 409)
    assert_shipping_mutable100(order)
    carrier = order._get_delivery_methods().filtered(lambda value: value.id == carrier_id)
    if not carrier:
        raise CustomerContractError('shipping_method_unavailable', 409)
    rate = carrier.rate_shipment(order.with_context(
        express_checkout_partial_delivery_address=False,
    ))
    if not _valid_rate100(rate):
        raise CustomerContractError('shipping_rate_unavailable', 409)
    order._set_delivery_method(carrier, rate=rate)
    if order.carrier_id != carrier or not order._is_delivery_ready():
        raise CustomerContractError('shipping_selection_incomplete', 409)
