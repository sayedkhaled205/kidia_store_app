import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import build_woocommerce_connector as builder


class ConnectorPackagingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest, cls.files = builder.load_sources()

    def test_actual_candidate_roundtrips_every_file(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = builder.write_package(self.manifest, self.files, Path(directory))
            with zipfile.ZipFile(archive) as package:
                self.assertEqual(len(package.namelist()), len(self.files))
                self.assertEqual(package.read('mobi2app-connector/api/class-website-auth-endpoint.php'), self.files['api/class-website-auth-endpoint.php'])
                self.assertTrue(all(info.external_attr >> 16 == 0o100644 for info in package.infolist()))
                self.assertTrue(all(name.startswith('mobi2app-connector/') for name in package.namelist()))
            release = json.loads((Path(directory)/'connector-release.json').read_text())
            self.assertEqual(release['version'], self.manifest['version'])
            self.assertEqual(release['files'], len(self.files))

    def test_missing_bridge_fails_even_if_inventory_were_updated(self):
        files = dict(self.files)
        del files['api/class-website-auth-endpoint.php']
        with self.assertRaisesRegex(ValueError, 'Required connector module missing'):
            builder.verify_features(files, self.manifest)

    def test_missing_bridge_registration_fails(self):
        files = dict(self.files)
        key = 'api/class-customer-auth-endpoint.php'
        files[key] = files[key].replace(b'$website->register()', b'/* removed */')
        with self.assertRaisesRegex(ValueError, 'registration missing'):
            builder.verify_features(files, self.manifest)

    def test_missing_saved_address_adapter_cannot_silently_ship(self):
        files = dict(self.files)
        del files['integrations/kidia-address-book.php']
        with self.assertRaisesRegex(ValueError, 'Required connector module missing'):
            builder.verify_features(files, self.manifest)

    def test_central_modules_must_ship_together(self):
        for missing in ['includes/central/bootstrap.php', 'includes/central/store-data.php', 'includes/central/kidia-push-admin-bridge.php', 'includes/central/kidia-builder-application-bridge.php']:
            with self.subTest(missing=missing):
                files = dict(self.files)
                del files[missing]
                with self.assertRaises(ValueError):
                    builder.verify_features(files, self.manifest)

    def test_central_bootstrap_must_keep_admin_authorization(self):
        files = dict(self.files)
        key = 'includes/central/bootstrap.php'
        files[key] = files[key].replace(b"current_user_can('manage_woocommerce')", b'true')
        with self.assertRaises(ValueError):
            builder.verify_features(files, self.manifest)

    def test_checkout_setup_and_owned_payment_refresh_must_ship(self):
        for missing in ['includes/class-native-checkout-setup50.php', 'includes/class-native-checkout-bootstrap50.php', 'api/class-native-checkout-safety50.php', 'api/class-customer-orders-endpoint.php']:
            with self.subTest(missing=missing):
                files = dict(self.files)
                del files[missing]
                with self.assertRaises(ValueError):
                    builder.verify_features(files, self.manifest)

    def test_checkout_setup_must_remain_authorized_and_automatic(self):
        for key, marker in [
            ('includes/class-native-checkout-setup50.php', b"current_user_can( 'manage_woocommerce' )"),
            ('includes/central/bootstrap.php', b'MobiShop_Native_Checkout_Setup50::prepare()'),
        ]:
            with self.subTest(key=key):
                files = dict(self.files)
                files[key] = files[key].replace(marker, b'/* removed */')
                with self.assertRaises(ValueError):
                    builder.verify_features(files, self.manifest)

    def test_version_must_match_both_metadata_files(self):
        manifest = copy.deepcopy(self.manifest)
        manifest['version'] = '9.9.9'
        with self.assertRaises(ValueError):
            builder.verify_features(self.files, manifest)

    def test_wrong_slug_and_legacy_bootstrap_cannot_ship(self):
        manifest = dict(self.manifest, slug='mobishop')
        with self.assertRaises(ValueError):
            builder.verify_features(self.files, manifest)
        files = dict(self.files, **{'mobishop.php': b'legacy'})
        with self.assertRaises(ValueError):
            builder.verify_features(files, self.manifest)

    def test_path_traversal_and_windows_absolute_paths_rejected(self):
        for path in ['.', '../outside', '/etc/passwd', 'C:/outside', 'a\\b', 'a/../b']:
            with self.subTest(path=path), self.assertRaises(ValueError):
                builder.relative_path(path)

    def test_private_and_development_files_cannot_enter_release(self):
        for path in ['.env.production', 'keys/signing.p8', 'tests/fixture.php', '.git/config', 'private.zip']:
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'cannot ship'):
                builder.verify_features(dict(self.files, **{path: b'fixture'}), self.manifest)

    def test_private_key_and_token_patterns_cannot_enter_release(self):
        for data in [b'-----BEGIN PRIVATE KEY-----', b'ghp_'+b'x'*32]:
            with self.subTest(data_type=len(data)), self.assertRaisesRegex(ValueError, 'pattern cannot ship'):
                builder.verify_features(dict(self.files, **{'api/accidental-credential.php': data}), self.manifest)

    def test_source_drift_fails_before_packaging(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'connectors/woocommerce/source').mkdir(parents=True)
            (root/'connectors/woocommerce/source/file.php').write_bytes(b'changed source')
            manifest = dict(self.manifest, files={'file.php': {'source':'connectors/woocommerce/source/file.php','source_sha256':'0'*64,'sha256':'0'*64}})
            (root/builder.MANIFEST).write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'differs from reviewed'):
                builder.load_sources(root)

    def test_linux_and_windows_checkout_produce_identical_release_bytes(self):
        import hashlib
        original = b'line one\r\nline two\r\n'
        normalized = original.replace(b'\r\n', b'\n')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'connectors/woocommerce').mkdir(parents=True)
            (root/'mobishop').mkdir()
            manifest = dict(self.manifest, files={'shared.txt': {
                'source':'mobishop/shared.txt', 'newline':'crlf',
                'source_sha256':hashlib.sha256(normalized).hexdigest(),
                'sha256':hashlib.sha256(original).hexdigest(),
            }})
            (root/builder.MANIFEST).write_text(json.dumps(manifest))
            for checkout_bytes in (original, normalized):
                (root/'mobishop/shared.txt').write_bytes(checkout_bytes)
                with patch.object(builder, 'verify_features'):
                    _, files = builder.load_sources(root)
                self.assertEqual(files['shared.txt'], original)


if __name__ == '__main__':
    unittest.main()
