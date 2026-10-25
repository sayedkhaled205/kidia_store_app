"""Refresh only the connected auth helper; retain the live builder and bundle.

Run on the builder host with --root, --helper and --review. Inspect the review
page, then use --activate with the same inputs. A changed live index aborts.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil


def digest(data):
    return hashlib.sha256(data).hexdigest()


def publish(root, helper_path, activate=False):
    root = root.resolve(strict=True)
    helper = helper_path.read_text(encoding='utf-8').replace('\r\n', '\n').rstrip() + '\n'
    assert "cache: 'no-store'" in helper and "url.searchParams.set('_preview'" in helper
    marker = ")(typeof window !== 'undefined' ? window : globalThis);"
    assert helper.count(marker) == 1
    version = digest(helper.encode())[:12]
    index_path = root / 'index.html'
    review_name = f'index-auth-{version}-review.html'
    backup = root.parent / f'preview-auth-backup-{version}'
    if activate:
        record = json.loads((backup / 'manifest.json').read_text())
        review = (root / review_name).read_bytes()
        assert record['helper_sha256'] == digest(helper.encode())
        assert record['review_sha256'] == digest(review)
        assert record['index_sha256'] == digest(index_path.read_bytes()), 'Live index changed; review again.'
        assert record['central_sha256'] == digest((root / record['new_central']).read_bytes())
        assert record['bundle_sha256'] == digest((root / record['bundle_path']).read_bytes())
        write_owned(index_path, review, index_path.stat())
        return {'activated': True, 'review': review_name, 'backup': str(backup)}
    index_bytes = index_path.read_bytes()
    index = index_bytes.decode()
    match = re.search(r'assets/(?:original|customize)-central[^"?\s]+\.js', index)
    assert match, 'Connected builder entry missing.'
    central = match.group()
    source_path = root / central
    assert source_path.resolve().is_relative_to(root)
    source = source_path.read_bytes().decode()
    assert source.startswith('(function (scope) {') and marker in source
    assert 'scope.KidiaPreviewAuth = api' in source.split(marker, 1)[0]
    assert 'mobishop-preview-auth-config-request' in source
    preview = re.search(r'assets/flutter-preview-[\w-]+/', source).group()
    bundle_path = root / preview / 'main.dart.js'
    assert bundle_path.resolve().is_relative_to(root)
    bundle = bundle_path.read_bytes()
    assert b'mobishop-preview-auth-config-request' in bundle, 'Bundle lacks the connected auth bridge.'
    # Keep every existing customization after the helper byte-for-byte.
    suffix = source.split(marker, 1)[1]
    updated = helper.rstrip() + suffix
    new_central = f'assets/original-central-auth-{version}.js'
    reviewed = index.replace(central, new_central)
    assert not backup.exists() and not (root / new_central).exists()
    owner = index_path.stat()
    backup.mkdir(mode=0o700)
    shutil.copy2(index_path, backup / 'index.html')
    shutil.copy2(source_path, backup / 'central.js')
    record = {'index_sha256': digest(index_bytes), 'review_sha256': digest(reviewed.encode()),
              'helper_sha256': digest(helper.encode()), 'bundle_sha256': digest(bundle),
              'central_sha256': digest(updated.encode()), 'bundle_path': str(bundle_path.relative_to(root)),
              'old_central': central, 'new_central': new_central}
    (backup / 'manifest.json').write_text(json.dumps(record, indent=2))
    write_owned(root / new_central, updated.encode(), owner)
    write_owned(root / review_name, reviewed.encode(), owner)
    return {'activated': False, 'review': review_name, 'backup': str(backup), **record}


def write_owned(path, data, owner):
    temporary = path.with_name(path.name + '.auth-tmp')
    with temporary.open('xb') as handle:
        handle.write(data)
    if hasattr(os, 'chown'):
        os.chown(temporary, owner.st_uid, owner.st_gid)
    os.chmod(temporary, 0o644)
    temporary.replace(path)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--helper', type=Path, required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--review', action='store_true')
    mode.add_argument('--activate', action='store_true')
    args = parser.parse_args()
    print(json.dumps(publish(args.root, args.helper, args.activate), indent=2))
