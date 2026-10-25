"""Add preview interactions to the current builder without replacing concurrent edits.

Stage: python3 publish-preview-interactions.py BUILDER_ROOT HELPER_JS
Activate the reviewed result with the same arguments plus --activate.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import sys

root = Path(sys.argv[1]).resolve()
helper = Path(sys.argv[2]).read_bytes()
version = hashlib.sha256(helper).hexdigest()[:12]
backup = root.parent / ('preview-interactions-backup-' + version)
review = 'index-preview-interactions-' + version + '-review.html'
owner = (root / 'index.html').stat()

def sha(data):
    return hashlib.sha256(data).hexdigest()

def write(name, data):
    path = root / name
    assert root in path.resolve().parents
    temp = path.with_name(path.name + '.interaction-tmp')
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
    print(json.dumps({'activated': True, 'backup': str(backup)}))
    sys.exit()

index = (root / 'index.html').read_text()
central = re.search(r'assets/(?:original|customize)-central[^"?\s]+\.js', index).group()
source = (root / central).read_text()
shell = re.search(r'assets/flutter-preview-[\w-]+/index\.html', source).group()
html = (root / shell).read_text()
start = html.index('    // Capture the wheel before CanvasKit')
end = html.index('    // This build is embedded', start)
patched = html[:start] + '    // Flutter owns native wheel/touch scrolling on the current route.\n\n' + html[end:]
new_shell = shell.replace('/index.html', '/index-interactions-' + version + '.html')
new_central = 'assets/original-central-interactions-' + version + '.js'
helper_name = 'assets/preview-interactions-' + version + '.js'
assert 'preview-interactions-' not in index, 'Interactions already installed; review before updating'
assert not backup.exists()
backup.mkdir(mode=0o700)
originals = {}
for name in ['index.html', central, shell]:
    data = (root / name).read_bytes()
    target = backup / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    originals[name] = sha(data)
changes = {
    new_shell: patched.encode(),
    new_central: source.replace(shell, new_shell).encode(),
    helper_name: helper,
    review: index.replace(central, new_central).replace('</body>',
        '<script src="' + helper_name + '"></script>\n</body>').encode(),
}
assert changes[new_central].decode().replace(new_shell, shell) == source
assert changes[review].decode().replace(new_central, central).replace(
    '<script src="' + helper_name + '"></script>\n', '') == index
published = {}
for name, data in changes.items():
    assert not (root / name).exists()
    write(name, data)
    published[name] = sha(data)
(backup / 'manifest.json').write_text(json.dumps({
    'originals': originals, 'published': published, 'review': review,
    'preserved_current_builder': True
}, indent=2))
print(json.dumps({'review_ready': True, 'review': review, 'backup': str(backup)}))
