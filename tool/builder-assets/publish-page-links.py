"""Stage an immutable preview and Copy page link control; activate after review.

Usage: python3 publish-page-links.py ROOT ZIP HELPER SHA256 [--activate]
"""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import sys
import zipfile

root = Path(sys.argv[1]).resolve()
archive = Path(sys.argv[2])
helper = Path(sys.argv[3]).read_bytes()
image_helper = Path(__file__).with_name('image-field-previews.js').read_bytes()
digest = sys.argv[4]
sha = lambda data: hashlib.sha256(data).hexdigest()
version = sha((digest + sha(helper) + sha(image_helper)).encode())[:12]
backup = root.parent / ('page-links-backup-' + version)
review = 'index-page-links-' + version + '-review.html'
owner = (root / 'index.html').stat()

def write(name, data):
    path = root / name
    assert root in path.resolve().parents
    temp = path.with_name(path.name + '.page-links-tmp')
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
assert old_bundle in frame_source
new_bundle = 'assets/flutter-preview-page-links-' + version + '/'
new_central = 'assets/original-central-page-links-' + version + '.js'
new_frame = 'screen-frame-page-links-' + version + '.html'
new_frame_js = 'assets/screen-frame-page-links-' + version + '.js'
new_helper = 'assets/preview-page-links-' + version + '.js'
new_images = 'assets/image-field-previews-' + version + '.js'
assert not backup.exists() and not (root / new_bundle).exists()
backup.mkdir(mode=0o700)
originals = {}
for name in ['index.html', central, frame, frame_js]:
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
review_source = index.replace(central, new_central).replace('</body>', '<script src="' + new_helper + '"></script></body>')
assert new_helper in review_source
changes = {
    new_central: source.replace(old_bundle, new_bundle).replace(frame, new_frame).encode(),
    new_frame: html.replace(frame_js, new_frame_js).replace('</body>', '<script src="' + new_images + '"></script></body>').encode(),
    new_frame_js: frame_source.replace(old_bundle, new_bundle).encode(),
    new_helper: helper,
    new_images: image_helper,
    review: review_source.encode(),
}
for name, data in changes.items():
    assert not (root / name).exists()
    write(name, data)
    published[name] = sha(data)
(backup / 'manifest.json').write_text(json.dumps({'originals': originals, 'published': published, 'review': review}, indent=2))
print(json.dumps({'review': review, 'backup': str(backup), 'bundle': new_bundle}))
