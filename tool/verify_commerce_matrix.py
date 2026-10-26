"""Offline cross-merchant regression checks, not live checkout certification.

Each case is a separate Flutter compilation: STORE_PLATFORM is a compile-time
constant, so one default `flutter test` cannot exercise all platform branches.
Fixtures use intercepted HTTP only; this never connects to a merchant or pays.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
COMMON = [
    "test/core/commerce/platform_binding_test.dart",
    "test/core/commerce/commerce_connection_test.dart",
    "test/core/commerce/merchant_isolation_test.dart",
    "test/core/commerce/hosted_commerce_destination297_test.dart",
    "test/features/auth/presentation/website_auth_platform_gate_test.dart",
    "test/app/hosted_commerce_routes297_test.dart",
    "test/core/app_design/category_overrides83_test.dart",
    "test/core/app_design/app_design_bundle58_test.dart",
    "test/features/home/data/models/home_layout_model_test.dart",
    "test/features/wishlist/data/shared_preferences_wishlist_repository_test.dart",
    "test/features/wishlist/application/wishlist_controller_test.dart",
    "test/shared/widgets/product_wishlist_button_test.dart",
    "test/features/product/presentation/product_detail_screen_test.dart",
    "test/features/catalog/presentation/catalog_screens_test.dart",
    "test/features/catalog/presentation/catalog_multi_select_test.dart",
]
PLATFORM_TESTS = {
    "woocommerce": [
        "test/features/account/data/customer_account_repository_impl_test.dart",
        "test/features/account/presentation/customer_account_pages_test.dart",
        "test/features/checkout/merchant_schema96_test.dart",
        "test/features/checkout/application/checkout_shipping_test.dart",
        "test/features/checkout/data/native_inline95_test.dart",
        "test/features/checkout/data/native_payment92_test.dart",
        "test/features/checkout/presentation/checkout_screen_test.dart",
        "test/features/auth/data/google_initialization_retry_test.dart",
        "test/features/auth/data/auth_repository_impl_test.dart",
        "test/features/cart/presentation/cart_controller_test.dart",
        "test/features/orders/data/customer_orders_repository_impl_test.dart",
    ],
    "shopify": [
        "test/core/commerce/shopify_currency_precision_test.dart",
        "test/core/commerce/shopify_checkout_policy297_test.dart",
        "test/features/cart/presentation/shopify_checkout_handoff297_test.dart",
        "test/features/cart/data/shopify_cart_recovery_test.dart",
    ],
    "odoo": [
        "test/features/wishlist/application/odoo_wishlist_access_test.dart",
        "test/features/account/presentation/odoo_account_help297_test.dart",
        "test/core/commerce/odoo_customer_contract_test.dart",
        "test/core/commerce/odoo_cart_contract100_test.dart",
        "test/core/commerce/odoo_checkout_transport101_test.dart",
        "test/features/checkout/odoo_native_checkout101_test.dart",
    ],
}
SENTINEL = "matrix compiled platform and merchant are explicit"


def cases(platform):
    for merchant, locale, country in (("alpha", "ar", "EG"), ("beta", "en", "US")):
        host = (f"matrix-{merchant}.myshopify.com" if platform == "shopify"
                else f"{merchant}.{platform}.example.invalid")
        path = "/shop" if platform == "woocommerce" and merchant == "beta" else ""
        yield {
            "name": f"{platform}-{merchant}", "platform": platform,
            "origin": f"https://{host}{path}", "locale": locale, "country": country,
        }


def command(flutter, case):
    return [flutter, "test", "--no-pub", "--reporter=json", *COMMON,
            *PLATFORM_TESTS[case["platform"]],
            f'--dart-define=STORE_PLATFORM={case["platform"]}',
            f'--dart-define=STORE_URL={case["origin"]}',
            f'--dart-define=STORE_LOCALE={case["locale"]}',
            f'--dart-define=STORE_COUNTRY_CODE={case["country"]}',
            f'--dart-define=EXPECTED_MATRIX_PLATFORM={case["platform"]}',
            f'--dart-define=EXPECTED_MATRIX_ORIGIN={case["origin"]}',
            "--dart-define=CMS_PREVIEW=false", "--dart-define=APP_TEST_BUILD=true"]


def summarize(stdout, returncode):
    names, passed, failed, skipped = {}, [], [], []
    done = False
    for line in stdout.splitlines():
        try:
            event = json.loads(line)
        except (ValueError, TypeError):
            continue
        if not isinstance(event, dict):
            continue
        if event.get("type") == "testStart":
            names[event["test"]["id"]] = event["test"]["name"]
        if event.get("type") == "testDone" and not event.get("hidden"):
            name = names.get(event["testID"], "unknown test")
            if event.get("skipped"):
                skipped.append(name)
            elif event.get("result") == "success":
                passed.append(name)
            else:
                failed.append(name)
        if event.get("type") == "done":
            done = event.get("success") is True
    # Do not accept an empty run, an accidentally skipped platform, or an
    # interrupted test process as success even if a wrapper returned zero.
    ok = returncode == 0 and done and SENTINEL in passed and not failed and not skipped
    return {"passed": ok, "tests_passed": len(passed),
            "failed_tests": failed, "skipped_tests": skipped,
            "platform_binding_executed": SENTINEL in passed}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=["all", *PLATFORM_TESTS], default="all")
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--report", default="build/commerce-matrix.json")
    args = parser.parse_args()
    flutter = shutil.which(args.flutter)
    if not flutter:
        parser.error("Flutter executable was not found.")
    report = Path(args.report).resolve()
    report.parent.mkdir(parents=True, exist_ok=True)
    results = []
    platforms = PLATFORM_TESTS if args.platform == "all" else [args.platform]
    for platform in platforms:
        for case in cases(platform):
            print(f'Checking {case["name"]} ({case["locale"]}, {case["country"]})', flush=True)
            try:
                run = subprocess.run(command(flutter, case), cwd=ROOT, capture_output=True,
                                     text=True, encoding="utf-8", errors="replace", timeout=240)
                result = summarize(run.stdout, run.returncode)
                if not result["passed"]:
                    log = report.with_name(f'{case["name"]}.log')
                    log.write_text(run.stdout + "\n" + run.stderr, encoding="utf-8")
                    result["failure_log"] = str(log)
            except subprocess.TimeoutExpired:
                result = {"passed": False, "error": "test_timeout"}
            results.append({**case, **result})
            print(f'{case["name"]}: {"PASS" if result["passed"] else "FAIL"} '
                  f'({result.get("tests_passed", 0)} tests)', flush=True)
            report.write_text(json.dumps({
                "scope": "offline contracts; not live payment or universal platform readiness",
                "complete": len(results) == (6 if args.platform == "all" else 2),
                "cases": results,
            }, indent=2), encoding="utf-8")
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    sys.exit(main())
