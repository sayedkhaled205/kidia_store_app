"""Direct Native endpoints using Odoo's own cookie session and CSRF checks.

POST requests use application/x-www-form-urlencoded fields `payload` (JSON) and
`csrf_token`, NOT JSON-RPC. Keeping csrf=True lets Odoo reject missing/invalid
tokens before executing the controller, including login/logout. There is no
CORS wildcard, API-key support, public-user-to-customer substitution, or generic
model/field/domain RPC. These account51 routes do not create orders. The separate
cart85 transport is disabled until its own website feature gate is enabled.
"""

import json
from urllib.parse import urlsplit

from odoo import http
from odoo.exceptions import AccessDenied, AccessError, MissingError, ValidationError
from odoo.http import request
from odoo.addons.woomobile_application_builder.controllers.mobile_api import _licensed

from ..services.customer_service import (
    CustomerContractError, CustomerService, bounded_text, scope_for,
)
from ..services.cart_contract85 import CART_VERSION, enabled_for85


PREFIX = '/api/mobile/v1/customer'
CLAIM = 'woomobile_native_customer_api51_scope'
PENDING = 'woomobile_native_customer_api51_pending_mfa'
VERSION = '51.1'


def response(data, status=200):
    return request.make_json_response(
        {'ok': status < 400, 'platform': 'odoo', 'contract_version': VERSION, **data},
        status=status,
        headers=[('Cache-Control', 'no-store, private, max-age=0'),
                 ('Pragma', 'no-cache'), ('X-Content-Type-Options', 'nosniff'),
                 ('Vary', 'Cookie')],
    )


def website_context():
    # No caller-selected database/website/company and no signed merchant proof.
    if not request.db or request.httprequest.scheme != 'https':
        raise CustomerContractError('secure_store_connection_required', 403)
    if request.httprequest.headers.get('Authorization'):
        raise CustomerContractError('use_customer_session_cookie', 401)
    params = request.env['ir.config_parameter'].sudo()
    website = request.env['website'].sudo().get_current_website()
    configured = website.domain or params.get_param('web.base.url', '')
    expected = urlsplit(configured if '://' in configured else 'https://' + configured)
    actual = urlsplit(request.httprequest.host_url)
    if (not expected.hostname or not actual.hostname
            or expected.hostname.lower() != actual.hostname.lower()
            or actual.port not in (None, 443)):
        raise CustomerContractError('store_host_mismatch', 403)
    if params.get_param('woomobile.native_customer_api51.enabled.%s' % website.id, '0') != '1':
        raise CustomerContractError('customer_contract_not_enabled', 503)
    # Reuse the installed connector's signed, installation-bound license check.
    # An unavailable/invalid verifier must NOT be replaced by a boolean flag.
    try:
        licensed = _licensed(params)
    except Exception:
        licensed = False
    if not licensed:
        raise CustomerContractError('connector_license_required', 503)
    return website


def body_payload(kwargs):
    if (request.httprequest.mimetype != 'application/x-www-form-urlencoded'
            or request.httprequest.args
            or set(kwargs) != {'payload'}):
        raise CustomerContractError('form_payload_required')
    raw = kwargs['payload']
    if not isinstance(raw, str) or len(raw.encode('utf-8')) > 16000:
        raise CustomerContractError('payload_too_large', 413)
    try:
        payload = json.loads(raw)
    except (ValueError, TypeError):
        raise CustomerContractError('invalid_payload') from None
    if not isinstance(payload, dict):
        raise CustomerContractError('invalid_payload')
    return payload


def customer_service(website):
    scope = scope_for(request.env, website)
    if not request.session.uid or request.session.uid != scope.uid:
        raise CustomerContractError('customer_session_required', 401)
    if not scope.matches_claim(request.session.get(CLAIM)):
        raise CustomerContractError('customer_store_session_required', 401)
    return CustomerService(request.env, scope)


def guarded(operation, *, transactional=True):
    try:
        website = website_context()
        # Any validation failure after a partner write rolls it back; returning
        # a JSON error must not accidentally commit a partially updated address.
        if transactional:
            with request.env.cr.savepoint():
                return operation(website)
        return operation(website)
    except CustomerContractError as error:
        return response({'error': {'code': error.code}}, error.status)
    except (AccessDenied, AccessError, MissingError):
        return response({'error': {'code': 'customer_access_denied'}}, 403)
    except ValidationError:
        return response({'error': {'code': 'customer_validation_failed'}}, 400)


class WooMobileNativeCustomer51(http.Controller):
    @http.route(PREFIX + '/session', type='http', auth='public', website=True, multilang=False,
                methods=['GET'], sitemap=False, readonly=True)
    def session(self, **kwargs):
        def operation(website):
            if kwargs:
                raise CustomerContractError('unexpected_parameters')
            authenticated = False
            profile = None
            if request.session.uid:
                # An MFA pre-session may only become a customer scope after
                # Odoo's own MFA flow finalized it. Never finalize it here.
                pending = request.session.get(PENDING)
                if pending == {'uid': request.session.uid, 'website_id': website.id,
                               'company_id': website.company_id.id}:
                    scope = scope_for(request.env, website)
                    request.session[CLAIM] = scope.session_claim()
                    request.session.pop(PENDING, None)
                service = customer_service(website)
                authenticated = True
                profile = service.profile()
            cart_enabled = enabled_for85(website)
            capabilities = {'profile': True, 'addresses': True, 'orders': True,
                            'register': False, 'cart': cart_enabled,
                            'checkout': cart_enabled, 'push': False}
            if cart_enabled:
                capabilities.update(free_checkout=True, payment_handoff=True)
            return response({
                'auth': {'protocol': 'odoo_session_cookie',
                         'authenticated': authenticated,
                         'csrf_token': request.csrf_token(time_limit=3600)},
                'customer': profile,
                'capabilities': capabilities,
                **({'cart_contract_version': CART_VERSION,
                    'checkout_form_contract_version': '101.1',
                    'shipping_contract_version': '100.1'} if cart_enabled else {}),
            })
        return guarded(operation)

    @http.route(PREFIX + '/login', type='http', auth='public', website=True, multilang=False,
                methods=['POST'], csrf=True, sitemap=False, max_content_length=20000)
    def login(self, **kwargs):
        def operation(website):
            payload = body_payload(kwargs)
            if set(payload) != {'login', 'password'}:
                raise CustomerContractError('invalid_login_fields')
            if request.session.uid:
                raise CustomerContractError('sign_out_before_sign_in', 409)
            login = bounded_text(payload['login'], maximum=254, required=True)
            if any(ord(character) < 32 for character in login):
                raise CustomerContractError('invalid_credentials', 401)
            password = payload['password']
            if not isinstance(password, str) or not password or len(password) > 4096:
                raise CustomerContractError('invalid_credentials', 401)
            try:
                auth_info = request.session.authenticate(
                    request.db, {'login': login, 'password': password, 'type': 'password'},
                )
            except AccessDenied:
                # Failed reauthentication must not leave an older MFA pre-user
                # or customer claim waiting in this unauthenticated session.
                request.session.logout(keep_db=True)
                return response({'error': {'code': 'invalid_credentials'}}, 401)
            if auth_info['uid'] != request.session.uid:
                request.session.pop(CLAIM, None)
                request.session[PENDING] = {
                    'uid': auth_info['uid'], 'website_id': website.id,
                    'company_id': website.company_id.id,
                }
                return response({'error': {'code': 'mfa_required'},
                                 'complete_on_store': '/web/login'}, 401)
            try:
                scope = scope_for(request.env, website)
            except CustomerContractError:
                request.session.logout(keep_db=True)
                raise
            request.session[CLAIM] = scope.session_claim()
            request.session.pop(PENDING, None)
            # Odoo rotates the cookie after authentication. The client obtains
            # a new CSRF token through GET /session using the new Set-Cookie.
            return response({'customer': CustomerService(request.env, scope).profile(),
                             'refresh_csrf': True})
        # Session.authenticate commits its native authentication transaction in
        # Odoo 18. Do not put a savepoint around it: that commit drops savepoints.
        return guarded(operation, transactional=False)

    @http.route(PREFIX + '/logout', type='http', auth='public', website=True, multilang=False,
                methods=['POST'], csrf=True, sitemap=False, max_content_length=20000)
    def logout(self, **kwargs):
        def operation(website):
            if body_payload(kwargs):
                raise CustomerContractError('unexpected_fields')
            customer_service(website)
            request.session.logout(keep_db=True)
            return response({'signed_out': True})
        return guarded(operation)

    @http.route(PREFIX + '/profile', type='http', auth='public', website=True, multilang=False,
                methods=['GET', 'POST'], csrf=True, sitemap=False, max_content_length=20000)
    def profile(self, **kwargs):
        def operation(website):
            service = customer_service(website)
            if request.httprequest.method == 'POST':
                data = service.update_profile(body_payload(kwargs))
            else:
                if kwargs:
                    raise CustomerContractError('unexpected_parameters')
                data = service.profile()
            return response({'customer': data})
        return guarded(operation)

    @http.route(PREFIX + '/addresses', type='http', auth='public', website=True, multilang=False,
                methods=['GET', 'POST'], csrf=True, sitemap=False, max_content_length=20000)
    def addresses(self, **kwargs):
        def operation(website):
            service = customer_service(website)
            if request.httprequest.method == 'POST':
                return response({'address': service.create_address(body_payload(kwargs))}, 201)
            if kwargs:
                raise CustomerContractError('unexpected_parameters')
            return response(service.addresses())
        return guarded(operation)

    @http.route(PREFIX + '/addresses/<int:address_id>', type='http', auth='public', website=True, multilang=False,
                methods=['POST'], csrf=True, sitemap=False, max_content_length=20000)
    def address(self, address_id, **kwargs):
        return guarded(lambda website: response({'address': customer_service(website).update_address(
            address_id, body_payload(kwargs),
        )}))

    @http.route(PREFIX + '/orders', type='http', auth='public', website=True, multilang=False,
                methods=['GET'], sitemap=False, readonly=True)
    def orders(self, **kwargs):
        def operation(website):
            if set(kwargs) - {'page'}:
                raise CustomerContractError('unexpected_parameters')
            return response(customer_service(website).orders(kwargs.get('page', 1)))
        return guarded(operation)

    @http.route(PREFIX + '/orders/<int:order_id>', type='http', auth='public', website=True, multilang=False,
                methods=['GET'], sitemap=False, readonly=True)
    def order(self, order_id, **kwargs):
        def operation(website):
            if kwargs:
                raise CustomerContractError('unexpected_parameters')
            return response({'order': customer_service(website).order(order_id)})
        return guarded(operation)

    @http.route(PREFIX + '/revision', type='http', auth='public', website=True, multilang=False,
                methods=['GET'], sitemap=False, readonly=True)
    def revision(self, **kwargs):
        def operation(website):
            if kwargs:
                raise CustomerContractError('unexpected_parameters')
            return response({'revision': customer_service(website).revision()})
        return guarded(operation)
