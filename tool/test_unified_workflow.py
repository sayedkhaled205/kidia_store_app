"""Validate the deployable dual-platform workflow (requires PyYAML)."""
from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]


class UnifiedWorkflowTests(unittest.TestCase):
    def test_each_native_build_runs_explicit_platform_contracts(self):
        workflows = yaml.safe_load((ROOT / 'codemagic.yaml').read_text(encoding='utf-8'))['workflows']
        for name, workflow in workflows.items():
            steps = workflow['scripts']
            checks = [i for i, step in enumerate(steps) if step['name'] == 'Verify merchant and platform contracts']
            self.assertEqual(len(checks), 1, name)
            script = steps[checks[0]]['script']
            self.assertIn('tool/verify_commerce_matrix.py', script)
            self.assertIn('test_native_build_defines81.py', script)
            self.assertIn('--platform "${STORE_PLATFORM:-woocommerce}"', script)
            for i, step in enumerate(steps):
                if 'flutter build ' in step['script']:
                    self.assertLess(checks[0], i, name)

    def test_actual_customer_design_is_checked_before_every_native_build(self):
        workflows = yaml.safe_load((ROOT / 'codemagic.yaml').read_text(encoding='utf-8'))['workflows']
        for name, workflow in workflows.items():
            steps = workflow['scripts']
            checks = [i for i, step in enumerate(steps) if step['name'] == 'Validate actual compiled customer design']
            self.assertEqual(len(checks), 1, name)
            preflight = steps[checks[0]]['script']
            self.assertIn('flutter test test/core/app_design/compiled_design_preflight297_test.dart', preflight)
            self.assertIn('python3 tool/native_build_defines81.py', preflight)
            if name != 'kidia-ios-testflight':
                self.assertIn('--dart-define=REQUIRE_SAVED_DESIGN=true', preflight)
            for i, step in enumerate(steps):
                if 'flutter build ' not in step['script']:
                    continue
                self.assertLess(checks[0], i, name)
                for value in ('--dart-define-from-file="${CM_BUILD_DIR:?}/.mobishop-native-defines.json"', '--dart-define="STORE_URL=$STORE_URL"'):
                    self.assertIn(value, preflight)
                    self.assertIn(value, step['script'])

    def test_simulator_success_requires_log_and_screen_validation(self):
        workflow = yaml.safe_load((ROOT / 'codemagic.yaml').read_text(encoding='utf-8'))['workflows']['mobishop-ios-simulator-check']
        launch = next(step['script'] for step in workflow['scripts'] if step['name'] == 'Capture actual App Store screenshots on iPhone and iPad')
        self.assertIn('set -euo pipefail', launch)
        # Retain the simulator binary for diagnosis even if the health gate fails.
        self.assertLess(launch.index('ditto -c -k'), launch.index('tool/app_store_screenshots.py'))
        self.assertEqual(launch.strip().splitlines()[-1], 'python3 tool/app_store_screenshots.py')
        capture = (ROOT / 'tool/app_store_screenshots.py').read_text(encoding='utf-8')
        self.assertIn('from verify_ios_simulator import verify', capture)
        self.assertIn('report = verify(identifier, os.environ["IOS_BUNDLE_ID"], folder,', capture)
        for family in ('iphone', 'ipad'):
            self.assertIn('build/ios/simulator-artifacts/' + family + '/*', workflow['artifacts'])

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

    def test_android_qa_is_explicit_and_dual_releases_cannot_downgrade(self):
        workflows = yaml.safe_load((ROOT / 'codemagic.yaml').read_text(encoding='utf-8'))['workflows']
        for name in ('mobishop-release', 'mobishop-dual-release', 'mobishop-customer-dual-release'):
            workflow = workflows[name]
            expected = 'qa' if name == 'mobishop-release' else 'release'
            self.assertEqual(workflow['environment']['vars']['MOBISHOP_ANDROID_BUILD_MODE'], expected)
            steps = workflow['scripts']
            preflight = next(step['script'] for step in steps if step['name'] == 'Verify Android build mode and registered signer')
            self.assertIn('tool/verify_android_signing.py --prepare', preflight)
            if expected == 'release':
                self.assertIn('test "${MOBISHOP_ANDROID_BUILD_MODE:?}" = release', preflight)
                self.assertEqual(workflow['environment']['vars']['MOBISHOP_REQUIRE_RELEASE_SIGNING'], 'true')
            package = next(step['script'] for step in steps if step['name'] == 'Package application build files')
            self.assertIn('--apk "$APK_PATH" --aab "$AAB_PATH"', package)
            self.assertIn('"$PACKAGE_DIR/android-build-verification.json"', package)
            self.assertLess(package.index('tool/verify_android_signing.py'), package.index('ditto -c -k'))
            self.assertEqual(steps[-1]['name'], 'Mark build successful')


if __name__ == '__main__':
    unittest.main()
