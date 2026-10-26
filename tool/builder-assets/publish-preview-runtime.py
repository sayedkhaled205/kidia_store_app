"""Publish a tested Flutter bundle and interaction helper, retaining live edits.

Arguments: builder root, bundle zip, helper JS, expected archive SHA256.
Run once to stage, review the returned URL, then repeat with --activate.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import sys
import zipfile
import importlib.util

repair_path = Path(__file__).with_name('repair-preview-contracts.py')
spec = importlib.util.spec_from_file_location('preview_contracts', repair_path)
contracts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contracts)

root = Path(sys.argv[1]).resolve()
archive = Path(sys.argv[2])
helper = Path(sys.argv[3]).read_bytes()
digest = sys.argv[4]
sha = lambda data: hashlib.sha256(data).hexdigest()
repair_digest = sha(repair_path.read_bytes() + repair_path.with_name('category-designer.js').read_bytes() + repair_path.with_name('product-outline.js').read_bytes())
version = sha((digest + sha(helper) + repair_digest).encode())[:12]
backup = root.parent / ('preview-runtime-backup-' + version)
review = 'index-preview-runtime-' + version + '-review.html'
owner = (root / 'index.html').stat()

def write(name, data):
    path = root / name
    assert root in path.resolve().parents
    temp = path.with_name(path.name + '.preview-tmp')
    with temp.open('xb') as handle:
        handle.write(data)
    os.chown(temp, owner.st_uid, owner.st_gid)
    os.chmod(temp, 0o644)
    temp.replace(path)

if '--activate' in sys.argv:
    record = json.loads((backup / 'manifest.json').read_text())
    for name, expected in {**record['originals'], **record['published']}.items():
        assert sha((root / name).read_bytes()) == expected, 'Changed since review: ' + name
    write('index.html', (root / review).read_bytes())
    print(json.dumps({'activated': True, 'backup': str(backup)}))
    sys.exit()

assert sha(archive.read_bytes()) == digest
index = (root / 'index.html').read_text()
central = re.search(r'assets/(?:original|customize)-central[^"?\s]+\.js', index).group()
source = (root / central).read_text()
frame = re.search(r'(?:screen-frame|customize-screen-frame)[^"?\s]+\.html', source).group()
html = (root / frame).read_text()
frame_js = re.search(r'assets/(?:screen-frame|customize-screen-frame)[^"?\s]+\.js', html).group()
frame_source = (root / frame_js).read_text()
old_bundle = re.search(r'assets/flutter-preview-[\w-]+/', source).group()
old_shell = re.search(re.escape(old_bundle) + r'index[^?\s\x27\x22]*\.html', source).group()
old_helper = re.search(r'assets/preview-interactions-[\w-]+\.js', index).group()
new_bundle = 'assets/flutter-preview-interactions-' + version + '/'
new_central = 'assets/original-central-interactions-' + version + '.js'
new_frame = 'screen-frame-interactions-' + version + '.html'
new_frame_js = 'assets/screen-frame-interactions-' + version + '.js'
new_helper = 'assets/preview-interactions-' + version + '.js'
assert old_bundle in frame_source
assert not backup.exists() and not (root / new_bundle).exists()
backup.mkdir(mode=0o700)
originals = {}
for name in ['index.html', central, frame, frame_js, old_helper]:
    target = backup / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / name, target)
    originals[name] = sha((root / name).read_bytes())
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None
    for item in bundle.infolist():
        assert (root / new_bundle).resolve() in (root / new_bundle / item.filename).resolve().parents
        assert (item.external_attr >> 16) & 0o170000 != 0o120000
    bundle.extractall(root / new_bundle)
published = {}
for path in [root / new_bundle, *(root / new_bundle).rglob('*')]:
    os.chown(path, owner.st_uid, owner.st_gid)
    os.chmod(path, 0o755 if path.is_dir() else 0o644)
    if path.is_file():
        published[path.relative_to(root).as_posix()] = sha(path.read_bytes())
patched_source = contracts.repair_central(source).replace(old_shell, new_bundle + 'index.html').replace(old_bundle, new_bundle).replace(frame, new_frame)
changes = {
    new_central: patched_source.encode(),
    new_frame: html.replace(frame_js, new_frame_js).encode(),
    new_frame_js: contracts.repair_frame(frame_source).replace(old_bundle, new_bundle).encode(),
    new_helper: helper,
    review: index.replace(central, new_central).replace(old_helper, new_helper).encode(),
}
assert changes[review].decode().replace(new_central, central).replace(new_helper, old_helper) == index
assert changes[new_frame_js].decode().replace(new_bundle, old_bundle) == contracts.repair_frame(frame_source)
for name, data in changes.items():
    assert not (root / name).exists()
    write(name, data)
    published[name] = sha(data)
(backup / 'manifest.json').write_text(json.dumps({'originals': originals, 'published': published, 'review': review}, indent=2))
print(json.dumps({'review': review, 'backup': str(backup), 'bundle': new_bundle}))
