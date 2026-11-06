"""Select an actual 13-inch iPad simulator and validate its raw PNG captures."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

CAPTURES = ['01-home', '02-categories', '03-products',
            '04-product-details', '05-product-gallery']
SIZES = {(2064, 2752), (2048, 2732)}


def select(data):
    for runtime, devices in data['devices'].items():
        for device in devices:
            name = device['name']
            if ('.iOS-' in runtime and device.get('isAvailable')
                    and name.startswith('iPad Pro') and '13' in name):
                return dict(device, runtime=runtime)
    raise ValueError('No available 13-inch iPad Pro simulator')


def png_size(content):
    if content[:8] != b'\x89PNG\r\n\x1a\n' or content[12:16] != b'IHDR':
        raise ValueError('Not a native PNG capture')
    size = struct.unpack('>II', content[16:24])
    if size not in SIZES:
        raise ValueError('Capture is not an accepted portrait 13-inch iPad size')
    return size


def main():
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['select', 'verify'])
    p.add_argument('path', type=Path)
    args = p.parse_args()
    if args.action == 'select':
        device = select(json.loads(args.path.read_text()))
        Path('build/ipad-store-screenshots').mkdir(parents=True, exist_ok=True)
        Path('build/ipad-store-screenshots/device.json').write_text(json.dumps(device))
        print(device['udid'])
        return
    rows = []
    for name in CAPTURES:
        file = args.path / (name + '.png')
        content = file.read_bytes()
        width, height = png_size(content)
        rows.append(dict(file=file.name, width=width, height=height,
                         sha256=hashlib.sha256(content).hexdigest()))
    report = json.loads((args.path / 'capture-report.json').read_text())
    assert report.get('data') == 'live public endpoints', 'Not a live capture run'
    assert report.get('orders') == report.get('payments') == 0
    result = dict(source='c24d4eed1dc4148d5590c1572c1bc778f21e2476',
                  method='xcrun simctl io screenshot; original PNGs, no resizing',
                  device=json.loads((args.path / 'device.json').read_text()), files=rows)
    (args.path / 'manifest.json').write_text(json.dumps(result, indent=2))
    print('Five original iPad screenshots validated')


if __name__ == '__main__':
    main()
