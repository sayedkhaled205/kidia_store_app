"""Gated direct Native cart/checkout transport; ordinary Odoo Cookie and CSRF."""

from odoo import http
from odoo.exceptions import AccessDenied, AccessError, MissingError, UserError, ValidationError
from odoo.http import request

from odoo.addons.website_sale.controllers.main import WebsiteSale

from .customer_api import body_payload, customer_service, response, website_context
from ..services.cart_contract85 import CART_VERSION, enabled_for85
from ..services.cart_service85 import CartService85, CheckoutRejected85
from ..services.customer_service import CustomerContractError


PREFIX = '/api/mobile/v1/customer'


def cart_response85(data, uid=None, status=200):
    return response({'cart_contract_version': CART_VERSION, 'customer_id': uid, **data}, status)


class WooMobileNativeCart85(WebsiteSale):
    def _guard85(self, operation):
        uid = None
        try:
            website = website_context()  # Existing exact host + license + feature51 checks.
            if not enabled_for85(website):
                raise CustomerContractError('cart_contract_not_enabled', 503)
            scope = customer_service(website).scope if request.session.uid else None
            if not scope and not request.env.user._is_public():
                raise CustomerContractError('customer_session_required', 401)
            uid = scope.uid if scope else None
            with request.env.cr.savepoint():
                service = CartService85(request, website, controller=self, customer_scope=scope)
                return cart_response85(operation(service), uid)
        except CheckoutRejected85 as error:
            # This proof is raised solely before the original validation/order
            # dispatch. Never infer a known rejection from an arbitrary 4xx/5xx.
            return cart_response85({'error': {'code': error.code}, 'checkout': error.proof},
                                   uid, error.status)
        except CustomerContractError as error:
            return cart_response85({'error': {'code': error.code}}, uid, error.status)
        except (AccessDenied, AccessError, MissingError):
            return cart_response85({'error': {'code': 'cart_access_denied'}}, uid, 403)
        except ValidationError:
            return cart_response85({'error': {'code': 'cart_validation_failed'}}, uid, 400)
        except UserError:
            return cart_response85({'error': {'code': 'cart_operation_rejected'}}, uid, 409)

    @http.route(PREFIX + '/cart', type='http', auth='public', website=True, multilang=False,
                methods=['GET'], sitemap=False)
    def native_cart85(self, **kwargs):
        def operation(service):
            if kwargs:
                raise CustomerContractError('unexpected_parameters')
            return {'cart': service.cart()}
        return self._guard85(operation)

    @http.route(PREFIX + '/cart/items', type='http', auth='public', website=True, multilang=False,
                methods=['POST'], csrf=True, sitemap=False, max_content_length=20000)
    def native_cart_add85(self, **kwargs):
        def operation(service):
            cart, warning = service.add(body_payload(kwargs))
            return {'cart': cart, 'warning': warning}
        return self._guard85(operation)

    @http.route(PREFIX + '/cart/items/<int:line_id>', type='http', auth='public', website=True,
                multilang=False, methods=['POST'], csrf=True, sitemap=False, max_content_length=20000)
    def native_cart_update85(self, line_id, **kwargs):
        def operation(service):
            cart, warning = service.update(line_id, body_payload(kwargs))
            return {'cart': cart, 'warning': warning}
        return self._guard85(operation)

    @http.route(PREFIX + '/checkout/address', type='http', auth='public', website=True,
                multilang=False, methods=['POST'], csrf=True, sitemap=False, max_content_length=20000)
    def native_checkout_address85(self, **kwargs):
        return self._guard85(lambda service: {'cart': service.addresses(body_payload(kwargs))})

    @http.route(PREFIX + '/checkout/shipping/quote', type='http', auth='public', website=True,
                multilang=False, methods=['POST'], csrf=True, sitemap=False, max_content_length=20000)
    def native_shipping_quote100(self, **kwargs):
        return self._guard85(lambda service: service.shipping_quote100(body_payload(kwargs)))

    @http.route(PREFIX + '/checkout/shipping/select', type='http', auth='public', website=True,
                multilang=False, methods=['POST'], csrf=True, sitemap=False, max_content_length=20000)
    def native_shipping_select100(self, **kwargs):
        return self._guard85(lambda service: service.shipping_select100(body_payload(kwargs)))

    @http.route(PREFIX + '/checkout/address/form', type='http', auth='public', website=True,
                multilang=False, methods=['POST'], csrf=True, sitemap=False, max_content_length=20000)
    def native_address_form101(self, **kwargs):
        return self._guard85(lambda service: service.address_metadata101(body_payload(kwargs)))

    @http.route(PREFIX + '/checkout/address/save', type='http', auth='public', website=True,
                multilang=False, methods=['POST'], csrf=True, sitemap=False, max_content_length=20000)
    def native_address_save101(self, **kwargs):
        return self._guard85(lambda service: service.save_address101(body_payload(kwargs)))

    @http.route(PREFIX + '/checkout/confirm', type='http', auth='public', website=True,
                multilang=False, methods=['POST'], csrf=True, sitemap=False, max_content_length=20000)
    def native_checkout_confirm85(self, **kwargs):
        return self._guard85(lambda service: {'checkout': service.confirm(body_payload(kwargs))})

    @http.route(PREFIX + '/checkout/outcome', type='http', auth='public', website=True,
                multilang=False, methods=['POST'], csrf=True, sitemap=False, max_content_length=20000)
    def native_checkout_outcome85(self, **kwargs):
        return self._guard85(lambda service: {'checkout': service.outcome(body_payload(kwargs))})
