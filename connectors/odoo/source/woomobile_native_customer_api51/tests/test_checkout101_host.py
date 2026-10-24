"""Pure parser boundary coverage; real merchant inheritance is tested in ORM."""
import importlib.util
from pathlib import Path
import sys
import types
import unittest

SERVICES = Path(__file__).resolve().parents[1] / 'services'
package = types.ModuleType('_checkout101_host')
package.__path__ = [str(SERVICES)]
sys.modules[package.__name__] = package


def load(name):
    spec = importlib.util.spec_from_file_location(package.__name__ + '.' + name, SERVICES / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


customer = load('customer_service')
parser = load('checkout101')


class Checkout101HostTests(unittest.TestCase):
    def parse(self, body, mandatory=()):
        return parser.parse_address_form101('<form action="/shop/address/submit">' + body + '</form>', mandatory)

    def test_custom_label_and_original_required_are_preserved(self):
        result = self.parse('<label for="state">محافظة</label><select id="state" name="state_id"><option value="0"/><option value="65" selected="selected">القاهرة</option></select>', ('state_id',))
        self.assertEqual(result[0]['label'], 'محافظة')
        self.assertTrue(result[0]['required'])
        self.assertEqual(result[0]['value'], '65')

    def test_hidden_authority_never_escapes(self):
        result = self.parse('<label for="n">Name</label><input id="n" name="name"/><input type="hidden" name="csrf_token" value="private"/><input type="hidden" name="partner_id" value="88"/>')
        self.assertEqual([field['name'] for field in result], ['name'])

    def test_localized_address_action_is_projected(self):
        for locale in ('en', 'ar', 'pt_BR', 'zh-HK'):
            markup = ('<form action="/' + locale + '/shop/address/submit">'
                      '<label for="n">Name</label><input id="n" name="name"/></form>')
            with self.subTest(locale=locale):
                self.assertEqual(parser.parse_address_form101(markup, ('name',))[0]['name'], 'name')

    def test_localization_cannot_widen_the_submit_endpoint(self):
        for action in ('https://other.example/en/shop/address/submit', '//other.example/shop/address/submit',
                       '/en/shop/address/submit?callback=other', '/en/shop/address/submit#x',
                       '/custom/shop/address/submit', '/en/shop/address/submit/extra'):
            with self.subTest(action=action), self.assertRaises(customer.CustomerContractError):
                parser.parse_address_form101('<form action="' + action + '">'
                    '<label for="n">Name</label><input id="n" name="name"/></form>', ())

    def test_unknown_visible_field_cannot_be_silently_dropped(self):
        with self.assertRaises(customer.CustomerContractError):
            self.parse('<label for="x">Door</label><input name="x_door" id="x" required="required"/>')

    def test_hidden_required_field_is_rejected(self):
        with self.assertRaises(customer.CustomerContractError):
            self.parse('<label for="n">Name</label><input id="n" name="name"/><div class="d-none"><input name="city"/></div>', ('city',))

    def test_empty_state_list_waits_for_required_country_selection(self):
        body = ('<label for="c">Country</label><select id="c" name="country_id">'
                '<option value=""/><option value="65">Country</option></select>'
                '<div style="display:none"><select name="state_id"><option value=""/></select></div>')
        self.assertEqual([f['name'] for f in self.parse(body, ('country_id', 'state_id'))], ['country_id'])
        with self.assertRaises(customer.CustomerContractError):
            self.parse(body.replace('value="65"', 'value="65" selected="selected"'), ('country_id', 'state_id'))

    def test_initial_country_does_not_hide_other_required_customizations(self):
        body = ('<label for="c">Country</label><select id="c" name="country_id"><option value=""/></select>'
                '<div hidden="hidden"><select name="state_id"/></div>')
        with self.assertRaises(customer.CustomerContractError):
            self.parse(body, ('country_id', 'state_id', 'city'))

    def test_duplicate_field_or_country_identity_is_rejected(self):
        for body in ('<label for="n">Name</label><input id="n" name="name"/><input id="n" name="name"/>',
                     '<label for="c">Country</label><select id="c" name="country_id"><option value="1">One</option><option value="1">Two</option></select>'):
            with self.subTest(body=body), self.assertRaises(customer.CustomerContractError):
                self.parse(body)

    def test_missing_or_duplicate_form_is_not_a_default_form(self):
        for markup in ('<div>Login required</div>', '<form action="/shop/address/submit"/><form action="/shop/address/submit"/>'):
            with self.subTest(markup=markup), self.assertRaises(customer.CustomerContractError):
                parser.parse_address_form101(markup, ())


if __name__ == '__main__':
    unittest.main()
