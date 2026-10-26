"""Stage/activate only the live-design dialog, preserving concurrent builder edits.

Arguments: builder root, reviewed helper JS, expected current helper SHA256.
Inspect the generated review page before repeating with --activate.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import sys

root = Path(sys.argv[1]).resolve()
helper = Path(sys.argv[2]).read_bytes()
expected = sys.argv[3]
sha = lambda data: hashlib.sha256(data).hexdigest()
version = sha(helper)[:12]
backup = root.parent / ('publish-dialog-backup-' + version)
review = 'index-publish-dialog-' + version + '-review.html'
asset = 'assets/live-design-publish-' + version + '.js'
owner = (root / 'index.html').stat()

def write(name, data):
    path = root / name
    assert root in path.resolve().parents
    temp = path.with_name(path.name + '.publish-dialog-tmp')
    with temp.open('xb') as handle:
        handle.write(data)
    if hasattr(os, 'chown'):
        os.chown(temp, owner.st_uid, owner.st_gid)
    os.chmod(temp, 0o644)
    temp.replace(path)

if '--activate' in sys.argv:
    record = json.loads((backup / 'manifest.json').read_text())
    for name, digest in {**record['originals'], **record['published']}.items():
        assert sha((root / name).read_bytes()) == digest, 'Changed since review: ' + name
    assert sha(helper) == record['helper_sha256']
    write('index.html', (root / review).read_bytes())
    print(json.dumps({'activated': True, 'backup': str(backup)}))
    sys.exit()

original = (root / 'index.html').read_bytes()
index = original.decode()
matches = re.findall(r'assets/live-design-publish-[\w-]+\.js', index)
assert len(matches) == 1, 'Expected one publish dialog script'
previous = matches[0]
old_helper = (root / previous).read_bytes()
assert sha(old_helper) == expected, 'Publish dialog changed; reconcile before staging'
patched = index.replace(previous, asset)
assert patched.replace(asset, previous) == index
assert not backup.exists()
backup.mkdir(mode=0o700)
(backup / 'index.html').write_bytes(original)
(backup / 'previous-helper.js').write_bytes(old_helper)
changes = {asset: helper, review: patched.encode()}
for name, data in changes.items():
    assert not (root / name).exists()
    write(name, data)
(backup / 'manifest.json').write_text(json.dumps({
    'originals': {'index.html': sha(original), previous: sha(old_helper)},
    'published': {name: sha(data) for name, data in changes.items()},
    'helper_sha256': sha(helper), 'review': review
}, indent=2))
print(json.dumps({'review': review, 'backup': str(backup), 'asset': asset}))
