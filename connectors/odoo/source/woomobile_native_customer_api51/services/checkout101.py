"""Project the merchant's rendered address form into bounded native fields.

Only public form metadata is returned. Hidden controls, tokens, callbacks and
client-selected order/partner identities are never part of this contract.
"""
import re

from lxml import html

from .customer_service import CustomerContractError

CHECKOUT_FORM_VERSION101 = '101.1'
ADDRESS_NAMES101 = frozenset({
    'name', 'email', 'phone', 'street', 'street2', 'city', 'zip',
    'country_id', 'state_id', 'company_name', 'vat',
})


def _text101(value, limit=240):
    value = ' '.join(str(value or '').split())
    if len(value) > limit:
        raise CustomerContractError('checkout_form_not_supported', 422)
    return value


def _hidden101(node):
    return any(
        'hidden' in parent.attrib
        or 'd-none' in parent.get('class', '').split()
        or re.search(r'display\s*:\s*none', parent.get('style', ''), re.I)
        for parent in [node, *node.iterancestors()]
    )


def parse_address_form101(markup, mandatory):
    encoded = str(markup).encode('utf-8')
    if len(encoded) > 2000000:
        raise CustomerContractError('checkout_form_not_supported', 422)
    doc = html.fromstring(encoded, parser=html.HTMLParser(encoding='utf-8'))
    # QWeb localizes form actions (e.g. /en/shop/address/submit) even when
    # metadata is requested from a non-multilang API route. Keep the original
    # local endpoint boundary; never accept hosts, queries or arbitrary paths.
    forms = [form for form in doc.xpath('//form[@action]') if re.fullmatch(
        r'/(?:[A-Za-z]{2,3}(?:[_-][A-Za-z0-9]{2,8})?/)?shop/address/submit',
        form.get('action', ''),
    )]
    if len(forms) != 1:
        raise CustomerContractError('checkout_form_not_supported', 422)
    form = forms[0]
    required = set(mandatory)
    for control in form.xpath('.//input[@type="hidden"][@name="required_fields"]'):
        required.update(value for value in control.get('value', '').split(',') if value)
    fields, seen = [], set()
    for control in form.xpath('.//input[@name] | .//select[@name] | .//textarea[@name]'):
        kind = control.get('type', 'text') if control.tag == 'input' else control.tag
        if kind in ('hidden', 'submit', 'button') or _hidden101(control):
            continue
        name = control.get('name')
        if name not in ADDRESS_NAMES101 or name in seen or kind not in ('text', 'email', 'tel', 'select'):
            raise CustomerContractError('checkout_form_not_supported', 422)
        seen.add(name)
        labels = form.xpath('.//label[@for=$id]', id=control.get('id', ''))
        label = _text101(labels[0].text_content() if labels else control.get('placeholder', ''))
        if not label:
            raise CustomerContractError('checkout_form_not_supported', 422)
        choices = []
        value = control.get('value', '')
        if kind == 'select':
            for option in control.xpath('./option | ./optgroup/option'):
                key = option.get('value', '')
                if key and key != '0':
                    if not re.fullmatch(r'[1-9][0-9]{0,9}', key):
                        raise CustomerContractError('checkout_form_not_supported', 422)
                    choices.append({'value': key, 'label': _text101(option.text_content())})
                    if 'selected' in option.attrib:
                        value = key
            if len(choices) > 1000 or len({item['value'] for item in choices}) != len(choices):
                raise CustomerContractError('checkout_form_not_supported', 422)
        fields.append({
            'name': name, 'label': label, 'kind': kind,
            'required': name in required or 'required' in control.attrib,
            'readonly': 'readonly' in control.attrib or 'disabled' in control.attrib,
            'value': _text101(value, 254), 'choices': choices,
        })
    missing = required - seen
    country = next((field for field in fields if field['name'] == 'country_id'), None)
    states = form.xpath('.//select[@name="state_id"]')
    if (country and country['kind'] == 'select' and country['required']
            and not country['value'] and len(states) == 1 and _hidden101(states[0])
            and not states[0].xpath('.//option[@value!=""][@value!="0"]')):
        # Original QWeb hides an empty state list until the shopper chooses
        # a country. The next country-specific projection must supply states;
        # do not invent a default country or ignore other required fields.
        missing.discard('state_id')
    if not fields or len(fields) > 20 or missing:
        # Do not silently drop a merchant's required customization.
        raise CustomerContractError('checkout_form_not_supported', 422)
    return fields
