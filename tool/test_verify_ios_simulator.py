import base64
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from verify_ios_simulator import fatal_signals, storefront_evidence, verify


class SimulatorLaunchTest(unittest.TestCase):
    device = "12345678-1234-1234-1234-123456789012"
    bundle = "com.customer.store"

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.artifacts = Path(self.temp.name)
        self.logs = "flutter: The Dart VM service is listening on http://127.0.0.1/\n"
        self.errors = ""
        self.lines = ["New arrivals", "Home", "Account"]
        self.commands = []

    def runner(self, command, **kwargs):
        self.commands.append(command)
        if command[:3] == ["xcrun", "simctl", "launch"]:
            for flag, content in (("--stdout=", self.logs), ("--stderr=", self.errors)):
                Path(next(part[len(flag):] for part in command if part.startswith(flag))).write_text(content, encoding="utf-8")
            return subprocess.CompletedProcess(command, 0, self.bundle + ": 12345\n", "")
        if command[0] == "ps":
            return subprocess.CompletedProcess(command, 0, "/CoreSimulator/Devices/" + self.device + "/data/Runner.app/Runner\n", "")
        if command[:3] == ["xcrun", "simctl", "io"]:
            Path(command[-1]).write_bytes(b"\x89PNG\r\n\x1a\nfixture")
            return subprocess.CompletedProcess(command, 0, "", "")
        if command[:2] == ["xcrun", "swift"]:
            self.assertEqual(kwargs["timeout"], 60)
            Path(command[-1]).write_text(json.dumps({"lines": self.lines}), encoding="utf-8")
            return subprocess.CompletedProcess(command, 0, "", "")
        self.fail("Unexpected command: " + str(command))

    def check(self, runner=None, sleeper=lambda _: None, encoded_design=""):
        return verify(self.device, self.bundle, self.artifacts, runner or self.runner, sleeper, encoded_design)

    def test_running_process_logs_and_screen_are_verified(self):
        waits = []
        result = self.check(sleeper=waits.append)
        self.assertEqual(waits, [3, 3, 3, 3])
        self.assertEqual(result["status"], "startup_no_detected_fatal_errors")
        self.assertTrue(result["flutter_output_captured"])
        self.assertTrue(result["screenshot_inspected"])
        self.assertIn("live login", result["limitations"])

    def test_immediate_exit_is_failure_but_retains_screenshot(self):
        def runner(command, **kwargs):
            return subprocess.CompletedProcess(command, 1, "", "") if command[0] == "ps" else self.runner(command, **kwargs)
        with self.assertRaisesRegex(ValueError, "exited"):
            self.check(runner)
        self.assertTrue((self.artifacts / "launch.png").is_file())

    def test_later_crash_is_failure(self):
        checks = []
        def runner(command, **kwargs):
            if command[0] == "ps":
                checks.append(command)
                if len(checks) == 3:
                    return subprocess.CompletedProcess(command, 1, "", "")
            return self.runner(command, **kwargs)
        with self.assertRaisesRegex(ValueError, "exited"):
            self.check(runner)
        self.assertEqual(len(checks), 3)

    def test_other_simulator_process_is_failure(self):
        def runner(command, **kwargs):
            return subprocess.CompletedProcess(command, 0, "/other/Runner.app/Runner", "") if command[0] == "ps" else self.runner(command, **kwargs)
        with self.assertRaisesRegex(ValueError, "failed"):
            self.check(runner)

    def test_simctl_error_is_failure(self):
        with self.assertRaisesRegex(ValueError, "could not launch"):
            self.check(lambda command, **kwargs: subprocess.CompletedProcess(command, 1, "", "Cannot launch"))

    def test_fatal_stdout_is_failure_while_process_is_alive(self):
        self.logs += "EXCEPTION CAUGHT BY WIDGETS LIBRARY: ProviderException\nInvalid APP_DESIGN_BUNDLE"
        with self.assertRaisesRegex(ValueError, "application logs.*invalid_saved_design"):
            self.check()
        self.assertTrue((self.artifacts / "launch.png").is_file())

    def test_fatal_stderr_is_failure(self):
        self.errors = "[ERROR:flutter/runtime/dart_vm_initializer.cc] Unhandled Exception"
        with self.assertRaisesRegex(ValueError, "application logs"):
            self.check()

    def test_actual_failed_design_screen_is_failure_despite_clean_logs_and_alive_pid(self):
        self.lines = ["ProviderException: A provider threw an exception.", "Invalid APP_DESIGN_BUNDLE:", "use a public saved design bound to this platform", "BOTTOM OVERFLOWED BY 627 PIXELS"]
        with self.assertRaisesRegex(ValueError, "error screen.*invalid_saved_design"):
            self.check()

    def test_multiline_ocr_error_signal_is_detected(self):
        self.assertIn("invalid_saved_design", fatal_signals("Invalid APP\nDESIGN BUNDLE"))
        self.assertIn("provider_exception", fatal_signals("Provider\nException"))

    def test_healthy_storefront_does_not_require_optional_flutter_debug_output(self):
        self.logs = ""
        self.errors = "Warning: Unable to create restoration in progress marker file"
        result = self.check()
        self.assertFalse(result["flutter_output_captured"])
        self.assertTrue(result["screenshot_inspected"])
        self.assertEqual(result["storefront_labels_matched"], 2)

    def test_permission_dialog_alone_does_not_pass_on_pid(self):
        self.logs = ""
        self.lines = ["Store would like to send you notifications", "Notifications may include alerts", "Don't Allow", "Allow"]
        with self.assertRaisesRegex(ValueError, "insufficient storefront evidence"):
            self.check()

    def test_error_screen_still_rejected_with_no_flutter_output(self):
        self.logs = ""
        self.lines = ["ProviderException", "Invalid APP_DESIGN_BUNDLE", "Home", "Account"]
        with self.assertRaisesRegex(ValueError, "error screen"):
            self.check()

    def test_actual_fixed_home_labels_are_recognized_behind_normal_permission_dialog(self):
        self.logs = ""
        self.lines = ["03:25", "kidia", "Search products", "Kids Style", "Nursery", "Toys", "Newborn",
                      "Would Like to Send You Notifications", "Don't Allow", "Allow", "Shop now", "NEW ARRIVAL"]
        design = {"home": {"blocks": [{"type": "quick_links", "data": {"items": [{"label": "Kids Style"}, {"label": "Nursery"}, {"label": "Toys"}, {"label": "Newborn"}]}},
                                     {"type": "hero_slider", "data": {"items": [{"button_label": "Shop now"}]}},
                                     {"type": "product_carousel", "data": {"title": "NEW ARRIVAL"}}]}}
        encoded = base64.b64encode(json.dumps(design).encode()).decode()
        result = self.check(encoded_design=encoded)
        self.assertGreaterEqual(result["storefront_labels_matched"], 6)

    def test_no_storefront_marker_means_inconclusive_failure_even_with_debug_banner(self):
        self.lines = ["03:25", "Settings", "Camera", "Calendar", "Photos"]
        with self.assertRaisesRegex(ValueError, "insufficient storefront evidence"):
            self.check()

    def test_disabled_block_labels_and_permission_buttons_do_not_count(self):
        design = {"home": {"blocks": [{"enabled": False, "data": {"label": "Ghost collection"}},
                                     {"data": {"label": "Allow", "button_label": "Don't Allow"}}]}}
        encoded = base64.b64encode(json.dumps(design).encode()).decode()
        self.assertEqual(storefront_evidence(["Ghost collection", "Allow", "Don't Allow"], encoded), [])

    def test_missing_or_failed_screenshot_is_failure(self):
        def runner(command, **kwargs):
            return subprocess.CompletedProcess(command, 1, "", "Capture error") if command[:3] == ["xcrun", "simctl", "io"] else self.runner(command, **kwargs)
        with self.assertRaisesRegex(ValueError, "screenshot"):
            self.check(runner)

    def test_ocr_tool_failure_does_not_pass(self):
        def runner(command, **kwargs):
            return subprocess.CompletedProcess(command, 1, "", "Vision failed") if command[:2] == ["xcrun", "swift"] else self.runner(command, **kwargs)
        with self.assertRaisesRegex(ValueError, "inspection failed"):
            self.check(runner)

    def test_empty_ocr_evidence_does_not_pass(self):
        self.lines = []
        with self.assertRaisesRegex(ValueError, "no usable evidence"):
            self.check()

    def test_previous_success_evidence_cannot_mask_missing_current_output(self):
        (self.artifacts / "launch-screen-text.json").write_text('{"lines":["Home"]}', encoding="utf-8")
        def runner(command, **kwargs):
            return subprocess.CompletedProcess(command, 0, "", "") if command[:2] == ["xcrun", "swift"] else self.runner(command, **kwargs)
        with self.assertRaisesRegex(ValueError, "inspection failed"):
            self.check(runner)


if __name__ == "__main__":
    unittest.main()
