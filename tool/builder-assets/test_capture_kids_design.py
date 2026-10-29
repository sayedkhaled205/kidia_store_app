import importlib.util
import base64
import json
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('capture', Path(__file__).with_name('capture-kids-design.py'))
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


class AppearanceTests(unittest.TestCase):
    def test_kids_preset_keeps_children_with_products(self):
        preset = json.loads(Path(__file__).with_name('kids-appearance-20261027.json').read_text(encoding='utf-8'))
        self.assertEqual(preset['category']['general']['navigation_mode'], 'products_with_children')

    def test_capture_preserves_order_tabs_identity_and_other_themes(self):
        kids = {'identity': {}, 'splash': {'image_url': 'old-logo', 'store_name': 'Old'}, 'category': {'general': {}}, 'pages': {'product': {'header': {'settings': {'logo_url': 'old-logo'}}, 'footer': {'settings': {}}, 'elements': [{'id': 'tabs', 'settings': {'after_summary': True}}]}}, 'home': [{'id': 'second', 'settings': {}}, {'id': 'first', 'settings': {}}]}
        home = [{'id': 'first', 'settings': {}, 'order': 0}, {'id': 'second', 'settings': {}, 'order': 1}]
        screens = {'product-builder': {'entries': [['layout[elements][0][id]', 'tabs'], ['layout[elements][0][settings][after_summary]', '0'], ['layout[footer][settings][button_height]', '47']]}, 'home-builder': {'entries': [['blocks_payload_encoding', 'base64'], ['blocks_payload', base64.b64encode(json.dumps(home).encode()).decode()]]}, 'category-builder': {'entries': [['category_general[name_highlight_enabled]', '1']]}, 'splash': {'entries': []}}
        before = {'kids_baby': kids, 'another': {'arabic': 'العربية'}}
        result = capture.capture(before, screens)
        self.assertEqual(result['another'], before['another'])
        self.assertEqual([b['id'] for b in result['kids_baby']['home']], ['first', 'second'])
        self.assertFalse(result['kids_baby']['pages']['product']['elements'][0]['settings']['after_summary'])
        self.assertEqual(result['kids_baby']['pages']['product']['footer']['settings']['button_height'], 47)
        self.assertEqual(result['kids_baby']['splash']['image_url'], '')
        self.assertEqual(result['kids_baby']['pages']['product']['header']['settings']['logo_url'], '')
        self.assertEqual(capture.capture(result, screens), result)
        self.assertTrue(before['kids_baby']['pages']['product']['elements'][0]['settings']['after_summary'])

    def test_controls_keep_types_and_do_not_copy_store_data(self):
        target = {'logo_url': 'template.svg', 'source': 'latest', 'show_name': True}
        capture.appearance(target, {'logo_url': 'merchant.svg', 'source': 'selected', 'product_ids': '123', 'support_email': 'private@example.test', 'button_height': '47', 'card_outline_width': '0.5', 'show_name': '0', 'name_highlight_enabled': '1', 'name_highlight_color': '#eff8f5'})
        self.assertEqual(target, {'logo_url': 'template.svg', 'source': 'latest', 'show_name': False, 'button_height': 47, 'card_outline_width': 0.5, 'name_highlight_enabled': 1, 'name_highlight_color': '#eff8f5'})

    def test_form_uses_last_checkbox_and_parses_element_arrays(self):
        result = capture.form([['layout[elements][0][id]', 'reviews'], ['layout[elements][0][enabled]', '1'], ['layout[elements][0][enabled]', '0'], ['nonce', 'excluded']])
        self.assertEqual(result, {'layout': {'elements': [{'id': 'reviews', 'enabled': '0'}]}})

    def test_composer_data_is_bounded(self):
        with self.assertRaises(AssertionError):
            capture.appearance({}, {'layout_json': '{"rows":[{"columns":[{"items":["https://merchant.example"]}]}]}'})

    def test_changes_are_idempotent(self):
        current = {'height': '62', 'icon_label_gap': '2', 'name_highlight_enabled': '1'}
        first = {}; capture.appearance(first, current)
        second = first.copy(); capture.appearance(second, current)
        self.assertEqual(first, second)

    def test_shared_card_choice_is_captured_as_appearance(self):
        target = {'share_style_across_app': True}
        capture.appearance(target, {'share_style_across_app': '0'})
        self.assertFalse(target['share_style_across_app'])


if __name__ == '__main__':
    unittest.main()
