"""Self-check for the exact-device selection gate and PNG size gate."""
import struct
import unittest

from ipad_capture_artifacts import TARGET_SIZE, png_size, select


def _png(width, height):
    return b'\x89PNG\r\n\x1a\n' + b'\x00' * 4 + b'IHDR' + struct.pack('>II', width, height)


class SelectTests(unittest.TestCase):
    def test_rejects_wrong_model_on_right_runtime(self):
        data = {
            'devices': {
                'com.apple.CoreSimulator.SimRuntime.iOS-26-5': [
                    {'name': 'iPad Pro 13-inch (M4)', 'isAvailable': True, 'udid': 'a'},
                ]
            }
        }
        with self.assertRaises(ValueError):
            select(data)

    def test_rejects_right_model_on_wrong_runtime(self):
        data = {
            'devices': {
                'com.apple.CoreSimulator.SimRuntime.iOS-17-0': [
                    {'name': 'iPad Pro 13-inch (M5)', 'isAvailable': True, 'udid': 'a'},
                ]
            }
        }
        with self.assertRaises(ValueError):
            select(data)

    def test_rejects_unavailable_device(self):
        data = {
            'devices': {
                'com.apple.CoreSimulator.SimRuntime.iOS-26-5': [
                    {'name': 'iPad Pro 13-inch (M5)', 'isAvailable': False, 'udid': 'a'},
                ]
            }
        }
        with self.assertRaises(ValueError):
            select(data)

    def test_selects_exact_available_device(self):
        data = {
            'devices': {
                'com.apple.CoreSimulator.SimRuntime.iOS-26-5': [
                    {'name': 'iPad Pro 13-inch (M4)', 'isAvailable': True, 'udid': 'wrong'},
                    {'name': 'iPad Pro 13-inch (M5)', 'isAvailable': True, 'udid': 'right'},
                ]
            }
        }
        device = select(data)
        self.assertEqual(device['udid'], 'right')
        self.assertEqual(device['runtime'], 'com.apple.CoreSimulator.SimRuntime.iOS-26-5')
        self.assertEqual(device['expected_portrait_size'], list(TARGET_SIZE))


class PngSizeTests(unittest.TestCase):
    def test_accepts_exact_target_size(self):
        self.assertEqual(png_size(_png(*TARGET_SIZE)), TARGET_SIZE)

    def test_rejects_other_ipad_size(self):
        with self.assertRaises(ValueError):
            png_size(_png(2048, 2732))

    def test_rejects_non_png_bytes(self):
        with self.assertRaises(ValueError):
            png_size(b'not a png' + b'\x00' * 20)


if __name__ == '__main__':
    unittest.main()
