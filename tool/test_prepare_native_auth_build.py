import json
import re
import plistlib
from pathlib import Path
import tempfile
import unittest

from native_auth_build import from_environment
from prepare_native_auth_build import NoRedirect, prepare
from configure_ios_store import configure
from verify_ios_signing import identity, validate_entitlements, SigningError


class NativeAuthSnapshotTest(unittest.TestCase):
    def test_frozen_snapshot_reaches_ios_phone_callback(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.config['firebase']['appId'] = '1:123456:ios:abc123'
            self.config['methods']['apple'] = False
            self.config['methods']['phone_otp'] = True
            output = root / 'auth.json'
            def fetch(url):
                if 'ios_phone_callback_version=1' in url:
                    return self.config
                return dict(self.config, firebase=None)
            prepare(self.env, output, fetch)
            config = from_environment(dict(self.env, NATIVE_AUTH_CONFIG_FILE=str(output)))
            project = root / 'ios/Runner.xcodeproj/project.pbxproj'
            project.parent.mkdir(parents=True)
            project.write_text('PRODUCT_BUNDLE_IDENTIFIER = com.example.mobishopStoreApp;\n' * 3)
            info = root / 'ios/Runner/Info.plist'
            info.parent.mkdir()
            info.write_bytes(plistlib.dumps({}))
            (info.parent / 'Runner.entitlements').write_bytes(plistlib.dumps({}))
            configure(root, self.env['IOS_BUNDLE_ID'], self.env['APPLE_TEAM_ID'], 'Store', native_auth=config)
            schemes = [s for e in plistlib.loads(info.read_bytes())['CFBundleURLTypes'] for s in e['CFBundleURLSchemes']]
            self.assertIn('app-1-123456-ios-abc123', schemes)
            self.assertNotIn('public-client-key', output.read_text())
            self.assertNotIn('must-not-be-copied', output.read_text())

    def setUp(self):
        self.env = dict(STORE_URL='https://shop.example/wp', STORE_PLATFORM='woocommerce',
                        IOS_BUNDLE_ID='com.customer.store', APPLE_TEAM_ID='AB12345678',
                        IOS_SIGNING_PROFILE_UUID='12345678-1234-1234-1234-123456789012',
                        IOS_SIGNING_CERTIFICATE_SHA256='a' * 64)
        self.config = dict(version=1, enabled=True, methods={'apple': True, 'google': True},
                           google={'ios_client_id': 'ios.apps.googleusercontent.com',
                                   'server_client_id': 'server.apps.googleusercontent.com'},
                           firebase={'iosBundleId': 'com.customer.store', 'projectId': 'auth-project',
                                     'apiKey': 'public-client-key'},
                           provider_secret='must-not-be-copied')

    def test_callback_identity_is_frozen_before_sms_activation_without_apple(self):
        with tempfile.TemporaryDirectory() as directory:
            self.config.update(methods={'apple': False, 'phone_otp': False}, firebase=None,
                               ios_phone_callback={'appId': '1:123456:ios:abc123', 'iosBundleId': 'com.customer.store'})
            value = prepare(self.env, Path(directory) / 'auth.json', lambda _: self.config)
            self.assertEqual(value['config']['firebase']['appId'], '1:123456:ios:abc123')
            self.assertFalse(value['config']['methods']['apple'])

    def test_apple_is_frozen_before_signing_and_public_fields_only(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'auth.json'
            urls = []
            def fetch(url):
                urls.append(url)
                return self.config
            prepare(self.env, output, fetch)
            self.assertEqual(urls, ['https://shop.example/wp/wp-json/mobishop/v1/auth/native/config?platform=ios&ios_phone_callback_version=1'])
            frozen = dict(self.env, NATIVE_AUTH_CONFIG_FILE=str(output))
            self.config['methods']['apple'] = False
            config = from_environment(frozen)
            self.assertTrue(config['methods']['apple'])
            self.assertEqual(config['google']['ios_client_id'], 'ios.apps.googleusercontent.com')
            self.assertNotIn('provider_secret', output.read_text())
            self.assertNotIn('public-client-key', output.read_text())
            expected = identity(frozen)
            self.assertTrue(expected['apple_signin_required'])
            with self.assertRaisesRegex(SigningError, 'Sign in with Apple'):
                validate_entitlements({}, expected)

    def test_snapshot_rejects_other_store_folder_platform_and_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'auth.json'
            prepare(self.env, output, lambda _: self.config)
            for changes in ({'STORE_URL': 'https://shop.example/other'},
                            {'STORE_URL': 'https://other.example/wp'},
                            {'STORE_PLATFORM': 'odoo'}, {'IOS_BUNDLE_ID': 'com.other.store'}):
                with self.subTest(changes=changes), self.assertRaises(ValueError):
                    from_environment(dict(self.env, NATIVE_AUTH_CONFIG_FILE=str(output), **changes))

    def test_other_platforms_never_call_woocommerce_routes(self):
        with tempfile.TemporaryDirectory() as directory:
            for platform in ('shopify', 'odoo'):
                value = prepare(dict(self.env, STORE_PLATFORM=platform, STORE_URL='https://shop.example'),
                                Path(directory) / 'auth.json', lambda _: self.fail('Unexpected network call'))
                self.assertFalse(value['config']['methods']['apple'])

    def test_explicit_config_is_supported_without_network(self):
        with tempfile.TemporaryDirectory() as directory:
            value = prepare(dict(self.env, NATIVE_AUTH_CONFIG_JSON=json.dumps(self.config)),
                            Path(directory) / 'auth.json', lambda _: self.fail('Unexpected network call'))
            self.assertTrue(value['config']['methods']['apple'])

    def test_invalid_or_unreachable_provider_does_not_silently_disable_apple(self):
        invalid = [None, [], {'version': 1, 'enabled': True, 'methods': {'apple': 'true'}},
                   {'version': 1, 'enabled': True},
                   {'version': 1, 'enabled': True, 'methods': {'google': True}},
                   dict(self.config, firebase={'iosBundleId': 'com.other.store'})]
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'auth.json'
            for config in invalid:
                with self.subTest(config=config), self.assertRaises((ValueError, TypeError)):
                    prepare(self.env, output, lambda _: config)
                self.assertFalse(output.exists())
            def offline(_):
                raise TimeoutError('fixture unreachable')
            with self.assertRaises(TimeoutError):
                prepare(self.env, output, offline)
            with self.assertRaises(ValueError):
                NoRedirect().redirect_request(None, None, None, None, 'https://other.example')

    def test_legacy_without_native_providers_and_required_apple(self):
        with tempfile.TemporaryDirectory() as directory:
            legacy = {'version': 1, 'enabled': False, 'methods': {}}
            output = Path(directory) / 'auth.json'
            self.assertFalse(prepare(self.env, output, lambda _: legacy)['config']['methods']['apple'])
            with self.assertRaises(ValueError):
                prepare(dict(self.env, APPLE_SIGN_IN_REQUIRED='true'), output, lambda _: legacy)

    def test_explicit_auth_plist_supplies_missing_google_client(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            plist = root / 'auth.plist'
            plist.write_bytes(plistlib.dumps({'BUNDLE_ID': 'com.customer.store',
                                            'CLIENT_ID': 'ios.apps.googleusercontent.com',
                                            'PROJECT_ID': 'auth-project'}))
            self.config['google'].pop('ios_client_id')
            value = prepare(dict(self.env, NATIVE_AUTH_GOOGLE_SERVICES_PLIST=str(plist)),
                            root / 'auth.json', lambda _: self.config)
            self.assertEqual(value['config']['google']['ios_client_id'], 'ios.apps.googleusercontent.com')

    def test_all_ios_build_workflows_prepare_before_signing(self):
        text = (Path(__file__).resolve().parents[1] / 'codemagic.yaml').read_text(encoding='utf-8')
        sections = re.split(r'(?m)^  (?=\S)', text)
        count = 0
        for section in sections:
            if 'python3 tool/configure_ios_store.py' not in section:
                continue
            count += 1
            self.assertIn('python3 tool/prepare_native_auth_build.py', section)
            self.assertLess(section.index('python3 tool/prepare_native_auth_build.py'),
                            section.index('python3 tool/configure_ios_store.py'))
        self.assertEqual(count, 6)


if __name__ == '__main__':
    unittest.main()
