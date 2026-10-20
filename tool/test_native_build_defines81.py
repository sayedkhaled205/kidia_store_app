"""Focused, offline Native generator contract; no Flutter builds or network."""
import base64
import copy
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

from native_build_defines81 import native_defines


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = json.loads((ROOT / "test/core/app_design/app_design_provider_fixture58.json").read_text(encoding="utf-8"))


def foreign(platform="odoo"):
    bundle = copy.deepcopy(FIXTURE)
    store = "https://odoo.example.invalid" if platform == "odoo" else "https://design-fixture.myshopify.com"
    bundle.update(platform=platform, store_origin=store)
    encoded = base64.b64encode(json.dumps(bundle, ensure_ascii=False).encode()).decode()
    return {"STORE_PLATFORM": platform, "STORE_URL": store, "STORE_LOCALE": "ar", "APP_DESIGN_BUNDLE": encoded}, bundle


class NativeBuildDefines81Tests(unittest.TestCase):
    def test_only_explicit_qa_artifacts_join_test_notification_audience(self):
        environment = {"STORE_URL": "https://woo.example/"}
        self.assertIs(native_defines(environment | {"MOBISHOP_ANDROID_BUILD_MODE": "qa"})["APP_TEST_BUILD"], True)
        for mode in ("release", "", "unknown"):
            self.assertNotIn("APP_TEST_BUILD", native_defines(environment | {"MOBISHOP_ANDROID_BUILD_MODE": mode}))

    def test_existing_woo_defaults_and_no_private_environment_leak(self):
        actual = native_defines({"STORE_URL": "https://woo.example/store/", "MOBISHOP_CALLBACK_TOKEN": "private",
                                 "SHOPIFY_ADMIN_TOKEN": "shpat_private", "UNRELATED_SECRET": "private"})
        self.assertEqual(actual, {"STORE_PLATFORM": "woocommerce"})

    def test_odoo_and_shopify_preserve_saved_bundle_and_selectors_exactly(self):
        for platform in ("odoo", "shopify"):
            environment, bundle = foreign(platform)
            result = native_defines(environment)
            self.assertEqual(result["STORE_PLATFORM"], platform)
            self.assertEqual(result["APP_DESIGN_BUNDLE"], environment["APP_DESIGN_BUNDLE"])
            self.assertEqual(json.loads(base64.b64decode(result["APP_DESIGN_BUNDLE"])), bundle)
        # Selector83 is additive: pass the saved latest/parent selectors through.
        environment, bundle = foreign()
        for block in bundle["home"]["blocks"]:
            if block["type"] == "product_grid":
                block["catalog_query"].update(mode="latest", sort="newest")
            elif block["type"] == "category_grid":
                block["catalog_query"].update(mode="parent", parent_id=0, hide_empty=False)
        encoded = base64.b64encode(json.dumps(bundle).encode()).decode()
        self.assertEqual(native_defines(environment | {"APP_DESIGN_BUNDLE": encoded})["APP_DESIGN_BUNDLE"], encoded)

    def test_unknown_platform_missing_bundle_and_wrong_binding_fail_closed(self):
        environment, _ = foreign()
        for changes in ({"STORE_PLATFORM": ""}, {"STORE_PLATFORM": "magento"}, {"APP_DESIGN_BUNDLE": ""},
                        {"APP_DESIGN_BUNDLE": "not-base64"}, {"STORE_URL": "https://other.example.invalid"},
                        {"STORE_PLATFORM": "shopify", "STORE_URL": "https://design-fixture.myshopify.com"},
                        {"STORE_URL": "https://user:private@odoo.example.invalid"}):
            with self.subTest(changes=tuple(changes)), self.assertRaises(ValueError):
                native_defines(environment | changes)

    def test_public_shopify_configuration_is_explicit_and_private_tokens_rejected(self):
        environment, _ = foreign("shopify")
        settings = {"SHOPIFY_STOREFRONT_API_VERSION": "2026-10", "SHOPIFY_PUBLIC_STOREFRONT_TOKEN": 'public"fixture',
                    "SHOPIFY_LANGUAGE_CODE": "ar", "STORE_COUNTRY_CODE": "eg"}
        actual = native_defines(environment | settings)
        self.assertEqual(actual["SHOPIFY_LANGUAGE_CODE"], "AR")
        self.assertEqual(actual["STORE_COUNTRY_CODE"], "EG")
        self.assertEqual(actual["SHOPIFY_PUBLIC_STOREFRONT_TOKEN"], 'public"fixture')
        for token in ("shpat_private", "shpca_private", "shpss_private", "shpua_private", "Bearer private", "cs_private", "bad\ntoken"):
            with self.subTest(token=token.split("_")[0]), self.assertRaises(ValueError):
                native_defines(environment | {"SHOPIFY_PUBLIC_STOREFRONT_TOKEN": token})
        for changes in ({"SHOPIFY_STOREFRONT_API_VERSION": "unstable"}, {"STORE_COUNTRY_CODE": "EGP"},
                        {"SHOPIFY_LANGUAGE_CODE": "bad-language"}, {"STORE_URL": "https://custom.example.invalid"}):
            with self.subTest(changes=tuple(changes)), self.assertRaises(ValueError):
                native_defines(environment | changes)

    def test_bundle_rejects_private_fields_serialized_secrets_and_sensitive_asset_query(self):
        environment, bundle = foreign()
        for hidden in ({"admin_token": "private"}, {"layout_json": '{"session":"private"}'},
                       {"image_url": "https://cdn.example/image.png?consumer_key=private"},
                       {"label": "shpat_private"}, {"customer_email": "private"}):
            changed = copy.deepcopy(bundle)
            changed["pages"]["home"]["settings"].update(hidden)
            encoded = base64.b64encode(json.dumps(changed).encode()).decode()
            with self.subTest(hidden=tuple(hidden)), self.assertRaises(ValueError) as failure:
                native_defines(environment | {"APP_DESIGN_BUNDLE": encoded})
            self.assertNotIn("private", str(failure.exception))

    def test_bundle_never_removes_records_or_broadens_unsupported_selectors(self):
        environment, bundle = foreign()
        catalog = next(block for block in bundle["home"]["blocks"] if "catalog_query" in block)
        for change in (lambda block: block["data"].update(items=[{"name": "saved record"}]),
                       lambda block: block["catalog_query"].update(unsupported_filter="value"),
                       lambda block: block.pop("catalog_query")):
            changed = copy.deepcopy(bundle)
            block = next(block for block in changed["home"]["blocks"] if block["id"] == catalog["id"])
            change(block)
            encoded = base64.b64encode(json.dumps(changed).encode()).decode()
            with self.assertRaises(ValueError):
                native_defines(environment | {"APP_DESIGN_BUNDLE": encoded})

    def test_cli_writes_safe_json_and_fails_without_echoing_inputs(self):
        environment, _ = foreign("shopify")
        environment["SHOPIFY_PUBLIC_STOREFRONT_TOKEN"] = 'public"fixture'
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "defines.json"
            success = subprocess.run([sys.executable, str(ROOT / "tool/native_build_defines81.py"), "--output", str(output)],
                                     env=environment, capture_output=True, text=True)
            self.assertEqual(success.returncode, 0, success.stderr)
            self.assertEqual(json.loads(output.read_text(encoding="utf-8")), native_defines(environment))
            failure = subprocess.run([sys.executable, str(ROOT / "tool/native_build_defines81.py"), "--output", str(output)],
                                     env=environment | {"APP_DESIGN_BUNDLE": "private-input-sentinel"}, capture_output=True, text=True)
            self.assertNotEqual(failure.returncode, 0)
            self.assertNotIn("private-input-sentinel", failure.stdout + failure.stderr)

    def test_every_native_build_uses_the_same_preflight_and_json_file(self):
        workflow = (ROOT / "codemagic.yaml").read_text(encoding="utf-8")
        builds = [step for step in re.split(r"(?m)^      - name:", workflow) if "flutter build " in step]
        self.assertEqual(len(builds), 10)
        for step in builds:
            preflight = 'python3 tool/native_build_defines81.py --output "${CM_BUILD_DIR:?}/.mobishop-native-defines.json"'
            if 'flutter build ios --simulator' in step:
                simulator = workflow.split('  mobishop-ios-simulator-check:', 1)[1]
                self.assertIn(preflight, simulator)
                self.assertLess(simulator.index(preflight), simulator.index('flutter build ios'))
            else:
                self.assertIn(preflight, step)
                self.assertLess(step.index("python3 tool/native_build_defines81.py"), step.index("flutter build "))
            self.assertIn('--dart-define-from-file="${CM_BUILD_DIR:?}/.mobishop-native-defines.json"', step)
            self.assertIn('--dart-define="STORE_URL=$STORE_URL"', step)


if __name__ == "__main__":
    unittest.main()
