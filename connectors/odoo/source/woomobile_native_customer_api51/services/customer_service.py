"""Exact-buyer services, not a generic ORM/merchant RPC surface.

No customer ID or domain is supplied by the caller. Order reads retain Odoo's
portal ACL/rules and are additionally restricted to the exact customer, website
and company. Partner writes use only a locked, already-proved own record because
the standard portal ACL does not grant general res.partner write access.
"""

import hashlib
import json
import re
from dataclasses import dataclass
from datetime import timezone
from decimal import Decimal, ROUND_HALF_UP


class CustomerContractError(Exception):
    def __init__(self, code, status=400):
        self.code = code
        self.status = status
        super().__init__(code)


def positive_id(value):
    if isinstance(value, bool) or not isinstance(value, (int, str)):
        raise CustomerContractError('invalid_id')
    text = str(value)
    if not re.fullmatch(r'[1-9][0-9]{0,9}', text):
        raise CustomerContractError('invalid_id')
    return int(text)


def page_number(value):
    value = positive_id(value)
    if value > 10000:
        raise CustomerContractError('invalid_page')
    return value


def bounded_text(value, *, maximum=240, required=False):
    if not isinstance(value, str):
        raise CustomerContractError('invalid_field')
    value = value.strip()
    if (required and not value) or len(value) > maximum or any(
        ord(char) < 32 and char not in '\n\t' for char in value
    ):
        raise CustomerContractError('invalid_field')
    return value


PROFILE_FIELDS = frozenset({'name', 'phone', 'mobile'})
ADDRESS_FIELDS = frozenset({
    'name', 'phone', 'mobile', 'street', 'street2', 'city', 'zip',
    'country_id', 'state_id',
})


def validated_patch(payload, allowed, *, require_name=False):
    if not isinstance(payload, dict) or not payload or set(payload) - allowed:
        raise CustomerContractError('invalid_fields')
    values = {}
    for field, value in payload.items():
        if field in {'country_id', 'state_id'}:
            if value is None or value is False:
                values[field] = False
            else:
                values[field] = positive_id(value)
        else:
            values[field] = bounded_text(
                value, maximum=120 if field in {'phone', 'mobile'} else 240,
                required=field == 'name',
            )
    if require_name and not values.get('name'):
        raise CustomerContractError('name_required')
    return values


@dataclass(frozen=True)
class CustomerScope:
    uid: int
    partner_id: int
    website_id: int
    company_id: int

    def session_claim(self):
        return {
            'uid': self.uid, 'partner_id': self.partner_id,
            'website_id': self.website_id, 'company_id': self.company_id,
        }

    def matches_claim(self, claim):
        return (isinstance(claim, dict) and set(claim) == set(self.session_claim())
                and all(isinstance(value, int) and not isinstance(value, bool)
                        for value in claim.values())
                and claim == self.session_claim())

    def order_domain(self):
        return [
            ('partner_id', '=', self.partner_id),
            ('website_id', '=', self.website_id),
            ('company_id', '=', self.company_id),
            ('state', 'in', ['sale', 'done', 'cancel']),
        ]

    def address_domain(self):
        return [
            ('parent_id', '=', self.partner_id),
            ('type', 'in', ['invoice', 'delivery']),
            ('active', '=', True),
            ('company_id', 'in', [False, self.company_id]),
            ('website_id', 'in', [False, self.website_id]),
            ('user_ids', '=', False),
        ]


def scope_for(env, website):
    user = env.user
    if (not user.active or user._is_public() or not user.share
            or not user.has_group('base.group_portal')
            or user.has_group('base.group_user')):
        raise CustomerContractError('customer_session_required', 401)
    partner = user.partner_id
    if (not partner.active or partner.company_id.id not in (False, website.company_id.id)
            or partner.website_id.id not in (False, website.id)):
        raise CustomerContractError('customer_store_mismatch', 403)
    if website.company_id.id not in user.company_ids.ids:
        raise CustomerContractError('customer_company_mismatch', 403)
    return CustomerScope(user.id, partner.id, website.id, website.company_id.id)


def money_minor(value, digits):
    """Odoo is the amount authority; preserve its currency's decimal places."""
    factor = Decimal(10) ** digits
    return str(int((Decimal(str(value)) * factor).quantize(
        Decimal('1'), rounding=ROUND_HALF_UP,
    )))


def revision_digest(value):
    canonical = json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False)
    return hashlib.sha256(canonical.encode('utf-8')).hexdigest()


class CustomerService:
    PAGE_SIZE = 20
    REVISION_PAGE_SIZE = 200

    def __init__(self, env, scope):
        self.env = env(context=dict(env.context, allowed_company_ids=[scope.company_id],
                                    website_id=scope.website_id))
        self.scope = scope
        # The identity is server-derived and checked on every operation, not a
        # client-supplied user/partner ID carried over after session changes.
        if self.env.uid != scope.uid or self.env.user.partner_id.id != scope.partner_id:
            raise CustomerContractError('customer_session_changed', 401)

    def _own_partner(self, *, locked=False):
        if locked:
            self._lock_partner(self.scope.partner_id)
        partner = self.env['res.partner'].browse(self.scope.partner_id).exists()
        partner.check_access('read')
        if not partner or not partner.active or partner.id != self.env.user.partner_id.id:
            raise CustomerContractError('customer_session_changed', 401)
        # These protected fields are never editable in this API.
        if (partner.company_id.id not in (False, self.scope.company_id)
                or partner.website_id.id not in (False, self.scope.website_id)):
            raise CustomerContractError('customer_store_mismatch', 403)
        return partner

    def _lock_partner(self, partner_id):
        self.env.cr.execute('SELECT id FROM res_partner WHERE id = %s FOR UPDATE', [partner_id])
        # A different transaction might have re-parented/archived the row while
        # this transaction waited on its lock. Re-read the scope after locking.
        self.env['res.partner'].browse(partner_id).invalidate_recordset()

    @staticmethod
    def _address_data(partner):
        return {
            'id': partner.id, 'type': partner.type,
            **{field: partner[field] or '' for field in ADDRESS_FIELDS
               if field not in {'country_id', 'state_id'}},
            'country_id': partner.country_id.id or None,
            'country_code': partner.country_id.code or '',
            'state_id': partner.state_id.id or None,
            'state_name': partner.state_id.name or '',
        }

    def profile(self):
        partner = self._own_partner()
        return {
            'id': self.scope.uid, 'partner_id': partner.id,
            'name': partner.name or '', 'email': partner.email or '',
            'login': self.env.user.login, 'phone': partner.phone or '',
            'mobile': partner.mobile or '',
            'editable_fields': sorted(PROFILE_FIELDS),
            'address': self._address_data(partner),
        }

    def _guard_name(self, partner, values):
        if ('name' in values and values['name'] != (partner.name or '').strip()
                and not partner.sudo()._can_edit_name()):
            raise CustomerContractError('name_locked_by_documents', 409)

    def update_profile(self, payload):
        values = validated_patch(payload, PROFILE_FIELDS)
        partner = self._own_partner(locked=True)
        if not all(partner.sudo().user_ids.mapped('share')):
            raise CustomerContractError('internal_contact_not_editable', 403)
        self._guard_name(partner, values)
        # Standard portal account code also writes the exact own partner under
        # sudo. No arbitrary model, IDs, groups or commercial fields are allowed.
        partner.sudo().with_context(tracking_disable=True).write(values)
        return self.profile()

    def addresses(self):
        partner = self._own_partner()
        children = self.env['res.partner'].sudo().search(
            self.scope.address_domain(), order='id', limit=100,
        )
        return {'primary': self._address_data(partner),
                'items': [self._address_data(child) for child in children]}

    def _address(self, address_id, *, locked=False):
        address_id = positive_id(address_id)
        self._own_partner()
        if address_id == self.scope.partner_id:
            return self._own_partner(locked=locked)
        domain = self.scope.address_domain() + [('id', '=', address_id)]
        child = self.env['res.partner'].sudo().search(domain, limit=1)
        if not child:
            # Identical for absent and foreign IDs; do not leak customer records.
            raise CustomerContractError('address_not_found', 404)
        if locked:
            # Never lock an arbitrary foreign ID before proving its ownership.
            # Re-run the scope query after waiting on the owned row's lock.
            self._lock_partner(address_id)
            child = self.env['res.partner'].sudo().search(domain, limit=1)
            if not child:
                raise CustomerContractError('address_not_found', 404)
        return child

    def _validate_country(self, address, values):
        country_id = values.get('country_id', address.country_id.id or False)
        state_id = values.get('state_id', address.state_id.id or False)
        country = self.env['res.country'].browse(country_id).exists()
        state = self.env['res.country.state'].browse(state_id).exists()
        if (country_id and not country) or (state_id and not state):
            raise CustomerContractError('invalid_country_or_state')
        if state and state.country_id.id != country_id:
            raise CustomerContractError('state_country_mismatch')
        if (address and 'country_id' in values and country_id != address.country_id.id
                and not address.sudo().can_edit_vat()):
            raise CustomerContractError('country_locked_by_documents', 409)

    def update_address(self, address_id, payload):
        values = validated_patch(payload, ADDRESS_FIELDS)
        address = self._address(address_id, locked=True)
        if not all(address.sudo().user_ids.mapped('share')):
            raise CustomerContractError('internal_contact_not_editable', 403)
        self._guard_name(address, values)
        self._validate_country(address, values)
        address.sudo().with_context(tracking_disable=True).write(values)
        return self._address_data(self._address(address_id))

    def create_address(self, payload):
        if not isinstance(payload, dict) or payload.get('type') not in {'invoice', 'delivery'}:
            raise CustomerContractError('invalid_address_type')
        values = validated_patch(
            {key: value for key, value in payload.items() if key != 'type'},
            ADDRESS_FIELDS, require_name=True,
        )
        self._own_partner(locked=True)
        if self.env['res.partner'].sudo().search_count(self.scope.address_domain(), limit=100) >= 100:
            raise CustomerContractError('address_limit', 409)
        empty = self.env['res.partner'].browse()
        self._validate_country(empty, values)
        values.update({
            'parent_id': self.scope.partner_id, 'type': payload['type'],
            'company_id': self.scope.company_id, 'website_id': self.scope.website_id,
        })
        child = self.env['res.partner'].sudo().with_context(tracking_disable=True).create(values)
        return self._address_data(self._address(child.id))

    @staticmethod
    def _order_data(order, *, detail=False):
        currency = order.currency_id
        digits = currency.decimal_places
        data = {
            'id': order.id, 'name': order.name, 'state': order.state,
            'date': (order.date_order.replace(tzinfo=timezone.utc).isoformat()
                     if order.date_order else None),
            'currency': currency.name, 'currency_minor_unit': digits,
            'total_minor': money_minor(order.amount_total, digits),
            'tax_minor': money_minor(order.amount_tax, digits),
            'untaxed_minor': money_minor(order.amount_untaxed, digits),
        }
        if detail:
            data['items'] = [{
                'id': line.id, 'product_id': line.product_id.id or None,
                'name': line.name, 'quantity': str(line.product_uom_qty),
                'unit_price_minor': money_minor(line.price_unit, digits),
                'subtotal_minor': money_minor(line.price_subtotal, digits),
                'total_minor': money_minor(line.price_total, digits),
            } for line in order.order_line if not line.display_type]
        return data

    def orders(self, page=1):
        self._own_partner()
        page = page_number(page)
        orders = self.env['sale.order']  # Intentionally NOT sudo.
        domain = self.scope.order_domain()
        orders.check_access('read')
        total = orders.search_count(domain)
        rows = orders.search(domain, order='date_order desc, id desc',
                             limit=self.PAGE_SIZE, offset=(page - 1) * self.PAGE_SIZE)
        return {'items': [self._order_data(order) for order in rows],
                'page': page, 'page_size': self.PAGE_SIZE, 'total': total}

    def order(self, order_id):
        self._own_partner()
        orders = self.env['sale.order']  # No portal access-token bypass either.
        order = orders.search(self.scope.order_domain() + [('id', '=', positive_id(order_id))], limit=1)
        if not order:
            raise CustomerContractError('order_not_found', 404)
        order.check_access('read')
        return self._order_data(order, detail=True)

    def revision(self):
        # Read-after-resume polling contract; not a claim of push delivery.
        # Hash actual own values, so archive/delete and same-timestamp writes are
        # observable. No other customer's revision is ever included.
        self._own_partner()
        profile = self.profile()
        addresses = self.addresses()
        return {
            'profile': revision_digest(profile),
            'addresses': revision_digest(addresses),
            'orders': self._visible_orders_revision(),
            'customer_id': self.scope.uid,
            'delivery': 'read_after_resume_or_foreground_poll',
        }

    def _visible_orders_revision(self):
        """Digest exactly the list/detail data this customer can read.

        A count/latest-write shortcut misses same-transaction state/amount
        changes, older-order edits and sale.order.line changes. Hash the actual
        visible values, including every visible line, under the same exact-buyer
        domain AND normal portal ORM access rules. Stable ID keyset pages bound
        memory without truncating a customer's history or trusting timestamps.
        """
        orders = self.env['sale.order']  # Intentionally NOT sudo.
        orders.check_access('read')
        domain = self.scope.order_domain()
        digest = hashlib.sha256()
        digest.update(b'woomobile.customer51.visible_orders.v1\0')
        digest.update(json.dumps(self.scope.session_claim(), sort_keys=True,
                                 separators=(',', ':')).encode('utf-8'))
        previous_id = 0
        while True:
            rows = orders.search(
                domain + [('id', '>', previous_id)], order='id',
                limit=self.REVISION_PAGE_SIZE,
            )
            if not rows:
                break
            for order in rows:
                digest.update(b'\0')
                digest.update(json.dumps(
                    self._order_data(order, detail=True), sort_keys=True,
                    separators=(',', ':'), ensure_ascii=False,
                ).encode('utf-8'))
            previous_id = rows[-1].id
            if len(rows) < self.REVISION_PAGE_SIZE:
                break
        return digest.hexdigest()
