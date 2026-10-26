"""Stage/activate a scoped color-picker fix, preserving all current builder assets."""
from pathlib import Path
import hashlib
import json
import os
import re
import sys

root = Path(sys.argv[1]).resolve()
helper = Path(sys.argv[2]).read_bytes()
sha = lambda data: hashlib.sha256(data).hexdigest()
version = sha(helper)[:12]
backup = root.parent / ('color-picker-backup-' + version)
review = 'index-color-picker-' + version + '-review.html'
asset = 'assets/color-picker-' + version + '.js'
owner = (root / 'index.html').stat()

def write(name, data):
    path = root / name
    assert root in path.resolve().parents
    temp = path.with_name(path.name + '.color-tmp')
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
    write('index.html', (root / review).read_bytes())
    print(json.dumps({'activated':True,'backup':str(backup)}))
    sys.exit()

original = (root / 'index.html').read_bytes()
index = original.decode()
assert 'assets/color-picker-' not in index, 'Already installed; review before updating'
assert index.count('</body>') == 1
patched = index.replace('</body>', '<script src="' + asset + '"></script>\n</body>')
assert patched.replace('<script src="' + asset + '"></script>\n', '') == index
assert not backup.exists()
backup.mkdir(mode=0o700)
(backup / 'index.html').write_bytes(original)
changes = {asset:helper, review:patched.encode()}
for name,data in changes.items():
    assert not (root / name).exists()
    write(name,data)
(backup / 'manifest.json').write_text(json.dumps({
    'originals':{'index.html':sha(original)},
    'published':{name:sha(data) for name,data in changes.items()},
    'review':review, 'preserved_current_builder':True
},indent=2))
print(json.dumps({'review_ready':True,'review':review,'backup':str(backup)}))
