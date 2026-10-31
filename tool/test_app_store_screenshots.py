import unittest
from unittest.mock import patch
import subprocess

from app_store_screenshots import run_simulator, select_devices


class ScreenshotDevicesTest(unittest.TestCase):
    def test_commands_have_stage_specific_timeouts_and_preserve_ocr_limit(self):
        with patch('app_store_screenshots.subprocess.run') as run:
            run_simulator(['xcrun', 'simctl', 'bootstatus', 'device', '-b'], check=True)
            self.assertEqual(run.call_args.kwargs['timeout'], 240)
            run_simulator(['xcrun', 'simctl', 'launch', 'device', 'app'])
            self.assertEqual(run.call_args.kwargs['timeout'], 90)
            run_simulator(['xcrun', 'swift', 'ocr.swift'], timeout=60)
            self.assertEqual(run.call_args.kwargs['timeout'], 60)

    def test_timeout_is_failure_instead_of_silent_success(self):
        with patch('app_store_screenshots.subprocess.run', side_effect=subprocess.TimeoutExpired('launch', 90)):
            with self.assertRaises(subprocess.TimeoutExpired):
                run_simulator(['xcrun', 'simctl', 'launch', 'device', 'app'])

    def inventory(self, *names):
        return {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-26-0": [
            {"name": name, "udid": str(index), "isAvailable": True}
            for index, name in enumerate(names)]}}

    def test_selects_store_sizes_instead_of_first_available_phone(self):
        selected = select_devices(self.inventory("iPhone 17", "iPhone 16 Pro Max", "iPad Pro 13-inch (M4)"))
        self.assertEqual(selected["iphone"]["name"], "iPhone 16 Pro Max")
        self.assertEqual(selected["ipad"]["name"], "iPad Pro 13-inch (M4)")

    def test_requires_both_platform_sizes(self):
        with self.assertRaisesRegex(ValueError, "ipad"):
            select_devices(self.inventory("iPhone 17 Pro Max"))

    def test_ignores_unavailable_or_non_ios_devices(self):
        inventory = self.inventory("iPhone 16 Pro Max", "iPad Pro 13-inch (M4)")
        inventory["devices"]["com.apple.CoreSimulator.SimRuntime.iOS-26-0"][0]["isAvailable"] = False
        inventory["devices"]["com.apple.CoreSimulator.SimRuntime.tvOS-26-0"] = [
            {"name": "iPhone 17 Pro Max", "udid": "foreign", "isAvailable": True}]
        with self.assertRaisesRegex(ValueError, "iphone"):
            select_devices(inventory)


if __name__ == "__main__":
    unittest.main()
