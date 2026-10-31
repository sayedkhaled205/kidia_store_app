import unittest

from app_store_screenshots import select_devices


class ScreenshotDevicesTest(unittest.TestCase):
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
