"""Public provider identity must survive each build without copying server secrets."""
import json
import plistlib
import re
import tempfile
import unittest
from pathlib import Path

from configure_ios_store import configure
from native_auth_build import facebook_settings, from_environment
from prepare_native_auth_build import prepare


class FacebookBuildTest(unittest.TestCase):
    def setUp(self):
        self.facebook = {'app_id': '123456789', 'client_token': 'public-fixture-token'}
        self.config = {'version': 1, 'enabled': True, 'methods': {'facebook_native': True},
                       'facebook': dict(self.facebook, app_secret='never-copy-secret')}
        self.env = {'STORE_URL': 'https://shop.example', 'ANDROID_APPLICATION_ID': 'com.customer.store'}

    def test_android_snapshot_and_identity_are_bound(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'auth.json'
            urls = []
            def fetch(url):
                urls.append(url)
                return self.config
            prepare(self.env, output, fetch)
            env = dict(self.env, NATIVE_AUTH_CONFIG_FILE=str(output))
            self.assertEqual(facebook_settings(from_environment(env)), self.facebook)
            self.assertEqual(urls, ['https://shop.example/wp-json/mobishop/v1/auth/native/config?platform=android'])
            self.assertNotIn('never-copy-secret', output.read_text())
            with self.assertRaises(ValueError):
                from_environment(dict(env, ANDROID_APPLICATION_ID='com.other.store'))

    def test_combined_build_accepts_one_ready_platform_and_rejects_disagreement(self):
        with tempfile.TemporaryDirectory() as folder:
            env = dict(self.env, IOS_BUNDLE_ID='com.customer.ios')
            output = Path(folder) / 'auth.json'
            result = prepare(env, output, lambda url: self.config if url.endswith('android') else
                             {'version': 1, 'enabled': True, 'methods': {}})
            self.assertEqual(result['config']['facebook'], self.facebook)
            with self.assertRaises(ValueError):
                prepare(env, output, lambda url: self.config if url.endswith('android') else
                        dict(self.config, facebook=dict(self.facebook, app_id='987654321')))

    def test_disabled_or_invalid_provider_does_not_leak_settings(self):
        self.assertIsNone(facebook_settings(None))
        self.assertIsNone(facebook_settings(dict(self.config, methods={'facebook_native': False})))
        for field, value in [('app_id', 'bad-id'), ('app_id', 123), ('client_token', 'short'), ('client_token', 'x\n' * 20)]:
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                facebook_settings(dict(self.config, facebook=dict(self.facebook, **{field: value})))

    def configure_fixture(self, folder, info):
        root = Path(folder)
        project = root / 'ios/Runner.xcodeproj/project.pbxproj'
        project.parent.mkdir(parents=True)
        project.write_text('PRODUCT_BUNDLE_IDENTIFIER = com.example.mobishopStoreApp;\n' * 3)
        target = root / 'ios/Runner/Info.plist'
        target.parent.mkdir()
        target.write_bytes(plistlib.dumps(info))
        return root, target

    def test_ios_adds_provider_and_preserves_other_callbacks_without_tracking(self):
        with tempfile.TemporaryDirectory() as folder:
            root, target = self.configure_fixture(folder, {'CFBundleURLTypes': [{'CFBundleURLSchemes': ['mobishop-store-app']}],
                                                          'LSApplicationQueriesSchemes': ['existing']})
            configure(root, 'com.customer.store', None, 'Store', signing_required=False, native_auth=self.config)
            result = plistlib.loads(target.read_bytes())
            self.assertEqual(result['FacebookAppID'], '123456789')
            self.assertEqual(result['FacebookClientToken'], 'public-fixture-token')
            self.assertFalse(result['FacebookAutoLogAppEventsEnabled'])
            self.assertFalse(result['FacebookAdvertiserIDCollectionEnabled'])
            self.assertIn('existing', result['LSApplicationQueriesSchemes'])
            self.assertIn('fbauth2', result['LSApplicationQueriesSchemes'])
            self.assertEqual(result['CFBundleURLTypes'][0]['CFBundleURLSchemes'], ['mobishop-store-app'])
            self.assertEqual(result['CFBundleURLTypes'][1]['CFBundleURLSchemes'], ['fb123456789'])
            self.assertNotIn('never-copy-secret', str(result))

    def test_ios_rejects_mismatched_or_malformed_existing_settings_without_writes(self):
        for bad in ({'FacebookAppID': '999'}, {'FacebookClientToken': 'other'},
                    {'CFBundleURLTypes': 'invalid'}, {'CFBundleURLTypes': ['invalid']},
                    {'CFBundleURLTypes': [{'CFBundleURLSchemes': [7]}]},
                    {'CFBundleURLTypes': [{'CFBundleURLSchemes': ['fb999']}]},
                    {'LSApplicationQueriesSchemes': 'invalid'}):
            with self.subTest(bad=bad), tempfile.TemporaryDirectory() as folder:
                root, target = self.configure_fixture(folder, bad)
                before = target.read_bytes()
                with self.assertRaises(ValueError):
                    configure(root, 'com.customer.store', None, 'Store', signing_required=False, native_auth=self.config)
                self.assertEqual(target.read_bytes(), before)

    def test_every_native_build_freezes_config_before_defines(self):
        source = (Path(__file__).resolve().parents[1] / 'codemagic.yaml').read_text(encoding='utf8')
        count = 0
        for workflow in re.split(r'(?m)^  (?=\S)', source):
            if 'python3 tool/native_build_defines81.py --output' not in workflow:
                continue
            count += 1
            self.assertIn('python3 tool/prepare_native_auth_build.py', workflow)
            self.assertLess(workflow.index('python3 tool/prepare_native_auth_build.py'), workflow.index('python3 tool/native_build_defines81.py --output'))
        self.assertGreaterEqual(count, 7)


if __name__ == '__main__':
    unittest.main()
