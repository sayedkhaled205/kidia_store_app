import plistlib
import tempfile
import unittest
from pathlib import Path
from configure_ios_store import configure, _google_auth_settings, _apply_google_auth


class StoreIdentityTest(unittest.TestCase):
    def test_shipping_template_declares_exempt_encryption_and_configure_preserves_it(self):
        template = Path(__file__).resolve().parents[1] / "ios/Runner/Info.plist"
        data = plistlib.loads(template.read_bytes())
        self.assertIs(data.get("ITSAppUsesNonExemptEncryption"), False)
        for declaration in (False, True):
            with self.subTest(declaration=declaration), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                project = root / "ios/Runner.xcodeproj/project.pbxproj"
                project.parent.mkdir(parents=True)
                project.write_text("PRODUCT_BUNDLE_IDENTIFIER = com.example.mobishopStoreApp;\n" * 3)
                info = root / "ios/Runner/Info.plist"
                info.parent.mkdir()
                info.write_bytes(plistlib.dumps({**data, "ITSAppUsesNonExemptEncryption": declaration}))
                configure(root, "com.example.kidia", "AB12345678", "Kidia")
                self.assertIs(plistlib.loads(info.read_bytes())["ITSAppUsesNonExemptEncryption"], declaration)

    def test_identity_and_reject_partial_rewrite(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project = root / "ios/Runner.xcodeproj/project.pbxproj"
            project.parent.mkdir(parents=True)
            project.write_text("PRODUCT_BUNDLE_IDENTIFIER = com.example.mobishopStoreApp;\n" * 3)
            info = root / "ios/Runner/Info.plist"
            info.parent.mkdir()
            info.write_bytes(plistlib.dumps({"CFBundleVersion": "$(FLUTTER_BUILD_NUMBER)", "UIBackgroundModes": ["remote-notification"]}))
            configure(root, "com.example.kidia", "AB12345678", "كيديا ستور")
            self.assertEqual(project.read_text().count("DEVELOPMENT_TEAM = AB12345678;"), 3)
            result = plistlib.loads(info.read_bytes())
            self.assertEqual(result["CFBundleDisplayName"], "كيديا ستور")
            self.assertEqual(result["UIBackgroundModes"], ["remote-notification"])
            self.assertEqual(result["CFBundleVersion"], "$(FLUTTER_BUILD_NUMBER)")
            before = project.read_bytes()
            with self.assertRaises(ValueError):
                configure(root, "com.example.kidia", "AB12345678", "كيديا")
            self.assertEqual(project.read_bytes(), before)

    def test_invalid_identity(self):
        for bundle, team, name in [("bad;identity", "AB12345678", "Kidia"), ("com.example.kidia", "invalid", "Kidia"), ("com.example.kidia", "AB12345678", "")]:
            with self.assertRaises(ValueError):
                configure(Path("nonexistent"), bundle, team, name)

    def test_simulator_identity_has_no_signing_team(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project = root / "ios/Runner.xcodeproj/project.pbxproj"
            project.parent.mkdir(parents=True)
            project.write_text("PRODUCT_BUNDLE_IDENTIFIER = com.example.mobishopStoreApp;\n" * 3)
            info = root / "ios/Runner/Info.plist"
            info.parent.mkdir()
            info.write_bytes(plistlib.dumps({"CFBundleVersion": "$(FLUTTER_BUILD_NUMBER)"}))
            configure(root, "com.customer.simulator", None, "Customer store", signing_required=False)
            self.assertEqual(project.read_text().count("PRODUCT_BUNDLE_IDENTIFIER = com.customer.simulator;"), 3)
            self.assertNotIn("DEVELOPMENT_TEAM", project.read_text())
            self.assertEqual(plistlib.loads(info.read_bytes())["CFBundleDisplayName"], "Customer store")

    def test_unsigned_mode_cannot_accept_team(self):
        with self.assertRaises(ValueError):
            configure(Path("nonexistent"), "com.customer.store", "AB12345678", "Store", signing_required=False)
        with self.assertRaises(ValueError):
            configure(Path("nonexistent"), "com.customer.store", None, "Store")

    def test_explicit_native_google_adds_callback_preserving_existing_schemes(self):
        info = {"CFBundleURLTypes": [{"CFBundleURLSchemes": ["mobishop-store-app"]}]}
        auth = {"google": {"ios_client_id": "123-ios.apps.googleusercontent.com", "server_client_id": "123-web.apps.googleusercontent.com", "ios_bundle_id": "com.customer.store"}}
        _apply_google_auth(info, _google_auth_settings("com.customer.store", auth))
        self.assertEqual(info["GIDClientID"], "123-ios.apps.googleusercontent.com")
        self.assertEqual(info["GIDServerClientID"], "123-web.apps.googleusercontent.com")
        self.assertEqual(info["CFBundleURLTypes"][0]["CFBundleURLSchemes"], ["mobishop-store-app"])
        self.assertEqual(info["CFBundleURLTypes"][1]["CFBundleURLSchemes"], ["com.googleusercontent.apps.123-ios"])
        _apply_google_auth(info, _google_auth_settings("com.customer.store", auth))
        self.assertEqual(len(info["CFBundleURLTypes"]), 2)

    def test_explicit_auth_plist_has_matching_bundle_and_project(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "GoogleService-Info.plist"
            data = {"BUNDLE_ID": "com.customer.store", "PROJECT_ID": "merchant-auth", "CLIENT_ID": "123-ios.apps.googleusercontent.com", "REVERSED_CLIENT_ID": "com.googleusercontent.apps.123-ios"}
            path.write_bytes(plistlib.dumps(data))
            settings = _google_auth_settings("com.customer.store", {"firebase": {"projectId": "merchant-auth"}}, path)
            self.assertEqual(settings["scheme"], "com.googleusercontent.apps.123-ios")
            for bad in ({"BUNDLE_ID": "com.other.store"}, {"PROJECT_ID": "push-only-project"}, {"REVERSED_CLIENT_ID": "com.googleusercontent.apps.foreign"}):
                path.write_bytes(plistlib.dumps({**data, **bad}))
                with self.assertRaises(ValueError):
                    _google_auth_settings("com.customer.store", {"firebase": {"projectId": "merchant-auth"}}, path)

    def test_no_auth_input_does_not_infer_google_from_push(self):
        self.assertIsNone(_google_auth_settings("com.customer.store", {"firebase": {"projectId": "managed-push", "appId": "1:123:ios:push"}}))
        self.assertIsNone(_google_auth_settings("com.customer.store"))

    def test_rejects_unsafe_or_mismatched_google_configuration(self):
        for google in (
            {"server_client_id": "123-web.apps.googleusercontent.com"},
            {"ios_client_id": "https://evil.example"},
            {"ios_client_id": "123-ios.apps.googleusercontent.com", "ios_bundle_id": "com.other.store"},
            {"ios_client_id": "123-ios.apps.googleusercontent.com", "server_client_id": "invalid"},
        ):
            with self.assertRaises(ValueError):
                _google_auth_settings("com.customer.store", {"google": google})
        settings = _google_auth_settings("com.customer.store", {"google": {"ios_client_id": "123-ios.apps.googleusercontent.com"}})
        with self.assertRaises(ValueError):
            _apply_google_auth({"GIDClientID": "another.apps.googleusercontent.com"}, settings)
        with self.assertRaises(ValueError):
            _apply_google_auth({"CFBundleURLTypes": [{"CFBundleURLSchemes": ["com.googleusercontent.apps.foreign"]}]}, settings)

    def test_google_failure_does_not_partially_change_project_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project = root / "ios/Runner.xcodeproj/project.pbxproj"
            project.parent.mkdir(parents=True)
            project.write_text("PRODUCT_BUNDLE_IDENTIFIER = com.example.mobishopStoreApp;\n" * 3)
            info = root / "ios/Runner/Info.plist"
            info.parent.mkdir()
            info.write_bytes(plistlib.dumps({"CFBundleVersion": "$(FLUTTER_BUILD_NUMBER)"}))
            before_project, before_info = project.read_bytes(), info.read_bytes()
            with self.assertRaises(ValueError):
                configure(root, "com.customer.store", "AB12345678", "Store", native_auth={"google": {"ios_client_id": "invalid"}})
            self.assertEqual(project.read_bytes(), before_project)
            self.assertEqual(info.read_bytes(), before_info)


if __name__ == "__main__":
    unittest.main()
