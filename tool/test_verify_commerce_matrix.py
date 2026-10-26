"""The test gate must reject skipped, interrupted and empty platform runs."""
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest

from verify_commerce_matrix import COMMON, PLATFORM_TESTS, SENTINEL, cases, command, run_case, summarize


def transcript(*, skipped=False, success=True, done=True):
    events = [
        {"type": "testStart", "test": {"id": 7, "name": SENTINEL}},
        {"type": "testDone", "testID": 7, "hidden": False, "skipped": skipped,
         "result": "success" if success else "error"},
    ]
    if done:
        events.append({"type": "done", "success": success})
    return "\n".join(map(json.dumps, events))


class CommerceMatrixTests(unittest.TestCase):
    def test_recent_shared_fixes_are_in_every_merchant_build(self):
        for name in ('product_wishlist_button_test.dart', 'wishlist_controller_test.dart',
                     'product_detail_screen_test.dart', 'catalog_screens_test.dart',
                     'home_layout_model_test.dart', 'category_overrides83_test.dart'):
            self.assertTrue(any(path.endswith(name) for path in COMMON), name)
        self.assertTrue(any(path.endswith('shopify_cart_recovery_test.dart')
                            for path in PLATFORM_TESTS['shopify']))

    def test_all_platforms_compile_two_distinct_merchants(self):
        for platform in ("woocommerce", "shopify", "odoo"):
            fixtures = list(cases(platform))
            self.assertEqual(len(fixtures), 2)
            self.assertNotEqual(fixtures[0]["origin"], fixtures[1]["origin"])
            for fixture in fixtures:
                args = command("flutter", fixture)
                self.assertIn(f"--dart-define=STORE_PLATFORM={platform}", args)
                self.assertIn(f'--dart-define=STORE_URL={fixture["origin"]}', args)
                self.assertIn(f"--dart-define=EXPECTED_MATRIX_PLATFORM={platform}", args)
                self.assertNotIn("--dart-define-from-file", " ".join(args))

    def test_completed_success_requires_the_binding_test(self):
        self.assertTrue(summarize(transcript(), 0)["passed"])
        for output, code in (("", 0), (transcript(skipped=True), 0),
                             (transcript(success=False), 0),
                             (transcript(done=False), 0), (transcript(), 1),
                             (transcript().replace(SENTINEL, "unrelated test"), 0)):
            with self.subTest(code=code, output=output):
                self.assertFalse(summarize(output, code)["passed"])

    def test_woo_matrix_includes_a_subdirectory_installation(self):
        fixtures = list(cases("woocommerce"))
        self.assertTrue(fixtures[1]["origin"].endswith("/shop"))
        for platform in ("shopify", "odoo"):
            for fixture in cases(platform):
                self.assertNotIn("/shop", fixture["origin"])

    def test_any_other_skipped_or_failed_test_rejects_the_case(self):
        for changes in ({"skipped": True}, {"result": "failure"}):
            event = {"type": "testDone", "testID": 8, "hidden": False,
                     "skipped": False, "result": "success"} | changes
            output = transcript() + "\n" + json.dumps(event)
            self.assertFalse(summarize(output, 0)["passed"])

    def test_success_and_failure_always_keep_stdout_and_stderr(self):
        with tempfile.TemporaryDirectory() as directory:
            for code in (0, 3):
                with self.subTest(code=code):
                    log = Path(directory) / f"case-{code}.log"
                    script = (f"import sys; print({transcript()!r}); "
                              f"print('diagnostic', file=sys.stderr); sys.exit({code})")
                    result = run_case([sys.executable, "-c", script], log,
                                      cwd=directory, timeout=5)
                    self.assertEqual(result["passed"], code == 0)
                    self.assertEqual(result["log"], str(log))
                    self.assertEqual(result["platform_binding_executed"], True)
                    self.assertIn(SENTINEL, log.read_text())
                    self.assertIn("diagnostic", log.read_text())
                    self.assertEqual("failure_log" in result, code != 0)

    def test_timeout_stops_wrapper_and_inheriting_child_and_keeps_log(self):
        # Real, short-lived Python fixtures only: never launch Flutter or touch
        # another matrix invocation. On Windows exercise the .bat wrapper too.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            marker = root / "child-heartbeat.txt"
            child = root / "child.py"
            child.write_text(
                "import pathlib, sys, time\n"
                "marker = pathlib.Path(sys.argv[1])\n"
                "for i in range(80):\n"
                "    marker.write_text(str(i))\n"
                "    print('child heartbeat', i, flush=True)\n"
                "    time.sleep(0.1)\n", encoding="utf-8")
            parent = root / "parent.py"
            parent.write_text(
                "import subprocess, sys, time\n"
                "print('parent started', flush=True)\n"
                "print('parent diagnostic', file=sys.stderr, flush=True)\n"
                "subprocess.Popen([sys.executable, sys.argv[1], sys.argv[2]])\n"
                "time.sleep(10)\n", encoding="utf-8")
            argv = [sys.executable, str(parent), str(child), str(marker)]
            if os.name == "nt":
                batch = root / "fixture.bat"
                batch.write_text("@" + " ".join(f'"{arg}"' for arg in argv) + "\n",
                                 encoding="utf-8")
                argv = [str(batch)]
            log = root / "timeout.log"
            started = time.monotonic()
            result = run_case(argv, log, cwd=root, timeout=2)
            self.assertLess(time.monotonic() - started, 8)
            self.assertFalse(result["passed"])
            self.assertEqual(result["error"], "test_timeout")
            self.assertEqual(result["failure_log"], str(log))
            self.assertIn("parent diagnostic", log.read_text())
            self.assertIn("child heartbeat", log.read_text())
            self.assertIn("timed out", log.read_text())
            heartbeat = marker.read_text()
            size = log.stat().st_size
            time.sleep(0.3)
            self.assertEqual(marker.read_text(), heartbeat, "Child survived tree termination")
            self.assertEqual(log.stat().st_size, size, "A descendant still owns the log")


if __name__ == "__main__":
    unittest.main()
