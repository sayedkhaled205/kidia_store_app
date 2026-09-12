"""Render the configured store logo into existing Android and iOS icon slots."""
import argparse
import io
import ipaddress
import json
import os
from pathlib import Path
import socket
import urllib.parse
import urllib.request
import warnings

from PIL import Image, ImageOps

MAX_BYTES = 8 * 1024 * 1024
Image.MAX_IMAGE_PIXELS = 16_000_000


def origin(url):
    parsed = urllib.parse.urlsplit(url)
    if (parsed.scheme != 'https' or not parsed.hostname or parsed.username
            or parsed.password or parsed.port not in (None, 443)):
        raise ValueError('The app icon requires an HTTPS URL without credentials.')
    return parsed.hostname.lower()


def validate_url(url, store_url):
    host = origin(url)
    if host != origin(store_url):
        raise ValueError('Upload the app icon to the connected store media library.')
    addresses = socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)
    if not addresses or any(not ipaddress.ip_address(a[4][0]).is_global for a in addresses):
        raise ValueError('The app icon must be served from a public address.')


def fetch_icon(url, store_url):
    validate_url(url, store_url)

    class StoreRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            validate_url(newurl, store_url)
            return super().redirect_request(req, fp, code, msg, headers, newurl)

    opener = urllib.request.build_opener(StoreRedirect())
    request = urllib.request.Request(url, headers={'User-Agent': 'MobiShop-App-Builder'})
    with opener.open(request, timeout=30) as response:
        if int(response.headers.get('Content-Length', '0')) > MAX_BYTES:
            raise ValueError('The app icon exceeds 8 MB.')
        data = response.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise ValueError('The app icon exceeds 8 MB.')
    return data


def render_icons(data, root):
    if len(data) > MAX_BYTES:
        raise ValueError('The app icon exceeds 8 MB.')
    with warnings.catch_warnings():
        warnings.simplefilter('error', Image.DecompressionBombWarning)
        with Image.open(io.BytesIO(data)) as source:
            if source.format not in ('PNG', 'JPEG', 'WEBP') or getattr(source, 'n_frames', 1) != 1:
                raise ValueError('Choose a static PNG, JPEG or WebP app icon.')
            if min(source.size) < 128:
                raise ValueError('The app icon must be at least 128 pixels on each side.')
            logo = ImageOps.exif_transpose(source).convert('RGBA')

    def save(path, size):
        # Preserve the whole logo. iOS icons must be opaque; the OS applies its mask.
        scaled = ImageOps.contain(logo, (size, size), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (size, size), 'white')
        canvas.alpha_composite(scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2))
        path.parent.mkdir(parents=True, exist_ok=True)
        canvas.convert('RGB').save(path, format='PNG')

    android = root / 'android/app/src/main/res'
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        save(android / ('mipmap-' + density) / 'ic_launcher.png', size)
    ios = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    slots = json.loads((ios / 'Contents.json').read_text())['images']
    for slot in slots:
        if not slot.get('filename'):
            continue
        name = slot['filename']
        if Path(name).name != name:
            raise ValueError('Invalid icon slot filename.')
        width, height = map(float, slot['size'].split('x'))
        if width != height:
            raise ValueError('App icon slots must be square.')
        save(ios / name, round(width * float(slot['scale'].removesuffix('x'))))
    print('Generated Android and iOS icons from the selected store logo.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, help='Local fixture or reviewed logo file.')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    if args.input:
        data = args.input.read_bytes()
    else:
        url = os.environ.get('APP_ICON_URL', '').strip()
        if not url:
            if os.environ.get('MOBISHOP_REQUIRE_RELEASE_SIGNING') == 'true':
                raise ValueError('A store submission build requires a configured app icon.')
            print('No app icon configured; retaining template icons for this test build.')
            return
        data = fetch_icon(url, os.environ.get('STORE_URL', ''))
    render_icons(data, args.root.resolve())


if __name__ == '__main__':
    main()
