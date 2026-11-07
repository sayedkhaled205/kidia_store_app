"""Select the exact iPad Pro 13-inch (M5)/iOS 26.5 simulator and validate raw PNG captures."""
import argparse
import base64
import re
from urllib.parse import urlsplit
import hashlib
import json
import os
from pathlib import Path
import struct

CAPTURES = ['01-home', '02-categories', '03-products',
            '04-product-details', '05-product-gallery']
# Exact destination only: iPad Pro 13-inch (M5) on the iOS 26.5 runtime,
# portrait 2064x2752. No fallback to other iPads, models or sizes.
TARGET_DEVICE_NAME = 'iPad Pro 13-inch (M5)'
TARGET_RUNTIME_SUBSTRING = 'iOS-26-5'
TARGET_SIZE = (2064, 2752)
SOURCE_BASELINE = '69f353ad1baddb77d5630c47443cf34c23441448'


def select(data):
    for runtime, devices in data['devices'].items():
        if runtime != 'com.apple.CoreSimulator.SimRuntime.iOS-26-5':
            continue
        for device in devices:
            if device.get('isAvailable') and device['name'] == TARGET_DEVICE_NAME:
                return {
                    'name': device['name'],
                    'udid': device['udid'],
                    'runtime': runtime,
                    'deviceTypeIdentifier': device.get('deviceTypeIdentifier'),
                    'state': device.get('state'),
                    'expected_portrait_size': list(TARGET_SIZE),
                }
    raise ValueError(
        f'Exact {TARGET_DEVICE_NAME} simulator on {TARGET_RUNTIME_SUBSTRING} '
        'is not available; refusing to fall back to another iPad or size'
    )


def png_size(content):
    if content[:8] != b'\x89PNG\r\n\x1a\n' or content[12:16] != b'IHDR':
        raise ValueError('Not a native PNG capture')
    size = struct.unpack('>II', content[16:24])
    if size != TARGET_SIZE:
        raise ValueError(
            f'Capture is {size}, not the required portrait {TARGET_SIZE} '
            f'({TARGET_DEVICE_NAME}) original size'
        )
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
    assert len({row['sha256'] for row in rows}) == len(CAPTURES), 'Repeated screens are not deliverable'
    report = json.loads((args.path / 'capture-report.json').read_text())
    assert report.get('data') == 'live public endpoints', 'Not a live capture run'
    assert report.get('orders') == report.get('payments') == 0
    assert report.get('account_submissions') == 0

    # Fresh snapshot only: never reuse a prior revision/hash and never invent one.
    revision = os.environ['QA_DESIGN_REVISION']
    assert revision == '96', f'QA_DESIGN_REVISION must be 96 (fresh snapshot); found {revision}'
    encoded = os.environ['APP_DESIGN_BUNDLE']
    design = json.loads(base64.b64decode(encoded, validate=True))
    origin = design['store_origin']
    parsed = urlsplit(origin)
    assert parsed.scheme == 'https' and parsed.hostname == 'kidiastore.com'
    assert not parsed.username and not parsed.password and not parsed.query and not parsed.fragment
    assert origin.rstrip('/') == os.environ['STORE_URL'].rstrip('/')
    design_hash = hashlib.sha256(encoded.encode()).hexdigest()
    assert re.fullmatch('[a-f0-9]{64}', os.environ['QA_DESIGN_SHA256'])
    assert design_hash == os.environ['QA_DESIGN_SHA256'], 'Revision96 design hash mismatch'
    assert report.get('source') == SOURCE_BASELINE
    assert report.get('home_hero_loaded') is True
    for name in CAPTURES:
        assert report[name]['stable_frames'] >= 3
    device = json.loads((args.path / 'device.json').read_text())
    assert device['name'] == TARGET_DEVICE_NAME
    assert device['runtime'] == 'com.apple.CoreSimulator.SimRuntime.iOS-26-5'

    result = dict(
        source=SOURCE_BASELINE,
        qa_overlay_commit=os.environ.get('CM_COMMIT') or os.environ.get('FCI_COMMIT'),
        ci_build_id=os.environ.get('CM_BUILD_ID') or os.environ.get('FCI_BUILD_ID'),
        published_design_revision=int(revision),
        published_design_sha256=design_hash,
        design_bundle_origin=origin,
        method='Flutter integration_test iOS native UIWindow capture at each route; original PNG bytes, no resizing',
        device=device,
        toolchain={"flutter": "3.47.8", "xcode": "26.5"},
        public_design_update_url=os.environ.get("APP_DESIGN_UPDATE_URL", ""),
        files=rows,
    )
    (args.path / 'manifest.json').write_text(json.dumps(result, indent=2))
    print('Five original iPad screenshots validated')


if __name__ == '__main__':
    main()
