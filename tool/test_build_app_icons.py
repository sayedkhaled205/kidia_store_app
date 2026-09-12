import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image
from build_app_icons import render_icons, validate_url


def fixture(size=(512, 256), format='PNG'):
    out = io.BytesIO()
    Image.new('RGBA', size, (13, 71, 149, 255)).save(out, format=format)
    return out.getvalue()


class IconTests(unittest.TestCase):
    def test_all_native_slots_preserve_logo_and_are_opaque(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            relative = Path('ios/Runner/Assets.xcassets/AppIcon.appiconset')
            (root / relative).mkdir(parents=True)
            shutil.copy(Path(__file__).resolve().parents[1] / relative / 'Contents.json', root / relative)
            render_icons(fixture(), root)
            icons = list(root.rglob('*.png'))
            self.assertEqual(len(icons), 20)
            for path in icons:
                with Image.open(path) as icon:
                    self.assertEqual(icon.mode, 'RGB')
                    self.assertEqual(icon.width, icon.height)
                    self.assertEqual(icon.getpixel((0, 0)), (255, 255, 255))
                    self.assertEqual(icon.getpixel((icon.width // 2, icon.height // 2)), (13, 71, 149))
            with Image.open(root / relative / 'Icon-App-1024x1024@1x.png') as icon:
                self.assertEqual(icon.size, (1024, 1024))
            with Image.open(root / 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png') as icon:
                self.assertEqual(icon.size, (192, 192))

    def test_invalid_images_fail_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            for data in [b'not an image', fixture((32, 32)), fixture(format='GIF'), b'x' * (8 * 1024 * 1024 + 1)]:
                with self.assertRaises((ValueError, OSError)):
                    render_icons(data, Path(directory))
            self.assertEqual(list(Path(directory).iterdir()), [])

    @patch('build_app_icons.socket.getaddrinfo')
    def test_only_public_same_store_https_is_accepted(self, resolve):
        resolve.return_value = [(2, 1, 6, '', ('93.184.216.34', 443))]
        store = 'https://store.example'
        validate_url(store + '/logo.png', store)
        for url in ['http://store.example/logo.png', 'https://other.example/logo.png', 'https://user:password@store.example/logo.png', 'https://store.example:8443/logo.png']:
            with self.assertRaises(ValueError):
                validate_url(url, store)
        resolve.return_value = [(2, 1, 6, '', ('127.0.0.1', 443))]
        with self.assertRaises(ValueError):
            validate_url(store + '/logo.png', store)


if __name__ == '__main__':
    unittest.main()
