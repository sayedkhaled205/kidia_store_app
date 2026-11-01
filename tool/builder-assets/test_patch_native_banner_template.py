import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('banner_patch', Path(__file__).with_name('patch-native-banner-template.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class BannerTemplateTests(unittest.TestCase):
    def test_controls_preserve_legacy_and_support_is_image_only(self):
        link = '<p class="mobishop-builder-field mobishop-repeatable-field--button-link"><label>Button Link</label><input type="url" placeholder="https://example.com" name="blocks[987654321][settings][items][__ITEM_INDEX__][button_link]" value=""></p>'
        select = '<select name="blocks[2][settings][action_type]"><option value="external">External URL</option></select>'
        source = '<div data-type="hero_slider">' + link + '</div><div data-type="image_banner">' + select + '</div><div data-type="promo_strip">' + select.replace('[2]', '[3]') + '</div>'
        patched, stats = module.patch_home(source)
        self.assertEqual(stats, {'hero_controls_added': 1, 'support_options_added': 1})
        self.assertIn(link, patched)
        self.assertIn('[items][__ITEM_INDEX__][action_type]', patched)
        self.assertIn('[items][__ITEM_INDEX__][action_value]', patched)
        self.assertEqual(patched.count('value="support"'), 1)
        self.assertNotIn('value="support"', patched.split('data-type="promo_strip"')[1])
        self.assertEqual(module.patch_home(patched)[0], patched)
    def test_unknown_template_fails_closed(self):
        with self.assertRaises(ValueError):
            module.patch_home('<p>Unknown version</p>')
    def test_other_block_template_may_share_hero_field_prefix(self):
        prefix = 'blocks[987654321][settings][items][0]'
        other = '<div data-type="quick_links"><select name="' + prefix + '[action_type]"></select></div>'
        hero = '<div data-type="hero_slider"><p class="mobishop-builder-field mobishop-repeatable-field--button-link"><input name="' + prefix + '[button_link]" value=""></p></div>'
        banner = '<div data-type="image_banner"><select name="blocks[987654321][settings][action_type]"></select></div>'
        patched, stats = module.patch_home(other + hero + banner)
        self.assertEqual(stats['hero_controls_added'], 1)
        self.assertEqual(patched.count('name="' + prefix + '[action_type]"'), 2)
        self.assertEqual(module.patch_home(patched)[0], patched)

if __name__ == '__main__':
    unittest.main()
