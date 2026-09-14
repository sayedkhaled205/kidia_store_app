"""Validate the deployable dual-platform workflow (requires PyYAML)."""
from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]


class UnifiedWorkflowTests(unittest.TestCase):
    def test_signed_outputs_are_required_before_success(self):
        workflows = yaml.safe_load((ROOT / 'codemagic.yaml').read_text(encoding='utf-8'))['workflows']
        dual = workflows['mobishop-dual-release']
        steps = dual['scripts']
        scripts = '\n'.join(step['script'] for step in steps)
        for command in ('flutter build apk --release', 'flutter build appbundle --release', 'flutter build ipa --release', 'codesign --verify --deep --strict'):
            self.assertIn(command, scripts)
        package = next(s['script'] for s in steps if s['name'] == 'Package application build files')
        for name in ('APK', 'AAB', 'IPA'):
            self.assertIn(f'test -s "${name}_PATH"', package)
        self.assertIn('"$PACKAGE_DIR/app-release.ipa"', package)
        self.assertEqual(steps[-1]['name'], 'Mark build successful')
        self.assertEqual(dual['environment']['ios_signing']['provisioning_profiles'], ['kidia_app_store_profile'])
        self.assertIn('testFlightInternalTestingOnly', scripts)
        # Artifact building does not publish to the public store or notify testers.
        self.assertNotIn('app_store_connect', dual['publishing'])
        self.assertIn('MOBISHOP_CALLBACK_TOKEN', dual['publishing']['scripts'][0]['script'])
        self.assertNotIn('flutter build ipa', '\n'.join(s['script'] for s in workflows['mobishop-release']['scripts']))

    def test_request_identity_is_not_silently_replaced_by_staging_defaults(self):
        dual = yaml.safe_load((ROOT / 'codemagic.yaml').read_text(encoding='utf-8'))['workflows']['mobishop-dual-release']
        variables = dual['environment']['vars']
        self.assertNotIn('STORE_URL', variables)
        self.assertNotIn('STORE_NAME', variables)
        scripts = '\n'.join(s['script'] for s in dual['scripts'])
        self.assertIn('${IOS_BUNDLE_ID:?}', scripts)
        self.assertIn('${BUILD_VERSION_NAME:?}', scripts)
        self.assertIn('python3 tool/configure_ios_store.py', scripts)


if __name__ == '__main__':
    unittest.main()
