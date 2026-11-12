"""Validate the deployable dual-platform workflow (requires PyYAML)."""
from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]


class UnifiedWorkflowTests(unittest.TestCase):
    def test_managed_dependency_recovery_does_not_retry_ipa_compilation(self):
        workflow = yaml.safe_load((ROOT / 'codemagic.yaml').read_text(encoding='utf-8'))['workflows']['kidia-managed-dual-release']
        steps = workflow['scripts']
        prepare = next(i for i, step in enumerate(steps) if step['name'] == 'Prepare iOS dependencies with bounded network recovery')
        ipa = next(i for i, step in enumerate(steps) if step['name'] == 'Build signed iOS IPA')
        self.assertLess(prepare, ipa)
        self.assertIn('flutter build ios --release --config-only', steps[prepare]['script'])
        self.assertNotIn('retry_dependency_download', steps[ipa]['script'])
        for value in ('--build-number="${BUILD_VERSION_CODE:?}"', '--dart-define-from-file="${CM_BUILD_DIR:?}/.mobishop-native-defines.json"'):
            self.assertIn(value, steps[prepare]['script'])
            self.assertIn(value, steps[ipa]['script'])

    def test_each_native_build_runs_explicit_platform_contracts(self):
        workflows = yaml.safe_load((ROOT / 'codemagic.yaml').read_text(encoding='utf-8'))['workflows']
        for name, workflow in workflows.items():
            steps = workflow['scripts']
            if not any('flutter build ' in step['script'] for step in steps):
                continue  # Upload-only workflows verify an existing signed artifact.
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
            if not any('flutter build ' in step['script'] for step in steps):
                continue
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

    def test_existing_ipa_upload_verifies_artifact_without_rebuilding_or_submitting(self):
        workflow = yaml.safe_load((ROOT / 'codemagic.yaml').read_text(encoding='utf-8'))['workflows']['kidia-testflight-existing-ipa']
        scripts = '\n'.join(step['script'] for step in workflow['scripts'])
        self.assertNotIn('flutter build ', scripts)
        self.assertIn('set -euo pipefail', scripts)
        self.assertIn('python3 tool/test_verify_ios_signing.py', scripts)
        self.assertIn('python3 tool/test_prepare_app_store_upload.py', scripts)
        self.assertIn('python3 tool/prepare_app_store_upload.py', scripts)
        self.assertEqual(workflow['artifacts'], ['build/verified-testflight/app.ipa'])
        publisher = workflow['publishing']['app_store_connect']
        self.assertIs(publisher['submit_to_testflight'], False)
        self.assertIs(publisher['submit_to_app_store'], False)

    def test_simulator_success_requires_log_and_screen_validation(self):
        workflow = yaml.safe_load((ROOT / 'codemagic.yaml').read_text(encoding='utf-8'))['workflows']['mobishop-ios-simulator-check']
        launch = next(step['script'] for step in workflow['scripts'] if step['name'] == 'Launch on iPhone simulator')
        self.assertIn('set -euo pipefail', launch)
        # Retain the simulator binary for diagnosis even if the health gate fails.
        self.assertLess(launch.index('ditto -c -k'), launch.index('tool/verify_ios_simulator.py'))
        self.assertIn('python3 tool/verify_ios_simulator.py --device "$SIMULATOR_ID" --report build/ios/simulator-artifacts/launch-check.json', launch)
        flows = next(step['script'] for step in workflow['scripts'] if step['name'] == 'Exercise customer flows on the iOS engine')
        self.assertIn('set -euo pipefail', flows)
        self.assertIn('flutter test integration_test/ios_customer_flows_test.dart', flows)
        self.assertIn('-d "${IOS_TEST_DEVICE:?}"', flows)
        # Synthetic fixtures assume their own layout; only the launch check
        # above must use the live merchant's compiled design and services.
        self.assertNotIn('--dart-define', flows)
        final_gate = workflow['scripts'][-1]
        self.assertEqual(final_gate['name'], 'Validate simulator results')
        self.assertIn('startup_no_detected_fatal_errors', final_gate['script'])
        for name in ('launch.png', 'launch-check.json', 'launch-stdout.log', 'launch-stderr.log', 'launch-screen-text.json'):
            self.assertIn('build/ios/simulator-artifacts/' + name, workflow['artifacts'])

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
        self.assertEqual(dual['environment']['ios_signing']['provisioning_profiles'], [{'profile': 'kidia_app_store_apple_profile', 'environment_variable': 'REGISTERED_IOS_PROFILE'}])
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

    def test_every_ipa_checks_registered_profile_and_exported_signature(self):
        workflows = yaml.safe_load((ROOT / 'codemagic.yaml').read_text(encoding='utf-8'))['workflows']
        for name, workflow in workflows.items():
            steps = workflow['scripts']
            builds = [i for i, step in enumerate(steps) if 'flutter build ipa ' in step['script']]
            if not builds:
                continue
            before = '\n'.join(step['script'] for step in steps[:builds[0]])
            after = '\n'.join(step['script'] for step in steps[builds[-1] + 1:])
            self.assertTrue('tool/verify_ios_signing.py --profile ' in before or 'tool/verify_ios_signing.py --install' in before, name)
            self.assertIn('tool/verify_ios_signing.py --ipa ', after, name)

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
