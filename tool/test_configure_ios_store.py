import plistlib
import tempfile
import unittest
from pathlib import Path
from configure_ios_store import configure


class StoreIdentityTest(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
