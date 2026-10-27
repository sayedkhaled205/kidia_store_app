"""Stage a CSS-only Cart Settings update against the current live builder.

Arguments: builder root, canonical chrome-layout.css. Review before --activate.
Only the frame stylesheet reference and its versioned parent references change.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import sys

root = Path(sys.argv[1]).resolve()
styles = Path(sys.argv[2]).read_text(encoding='utf-8-sig')
css = re.search(r'/\* Compact cart settings:.*?/\* End compact cart settings\. \*/', styles, re.S).group().encode()
sha = lambda data: hashlib.sha256(data).hexdigest()
version = sha(css)[:12]
backup = root.parent / ('cart-settings-backup-' + version)
review = 'index-cart-settings-' + version + '-review.html'
asset = 'assets/cart-settings-' + version + '.css'
owner = (root / 'index.html').stat()


def write(name, data):
    path = root / name
    assert root in path.resolve().parents
    temp = path.with_name(path.name + '.cart-tmp')
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

index = (root / 'index.html').read_bytes()
central = re.search(r'assets/(?:original|customize)-central[^"?\s]+\.js', index.decode()).group()
source = (root / central).read_bytes()
frame = re.search(r'(?:screen-frame|customize-screen-frame)[^"?\s]+\.html', source.decode()).group()
html = (root / frame).read_bytes()
new_central = 'assets/original-central-cart-' + version + '.js'
new_frame = 'screen-frame-cart-' + version + '.html'
link = ('<link rel="stylesheet" href="' + asset + '">\n').encode()
assert html.count(b'</head>') == 1
assert b'assets/cart-settings-' not in html, 'Already patched; reconcile the current source before updating'
changes = {
    asset: css,
    new_frame: html.replace(b'</head>', link + b'</head>'),
    new_central: source.replace(frame.encode(), new_frame.encode()),
    review: index.replace(central.encode(), new_central.encode()),
}
assert changes[new_frame].replace(link, b'') == html
assert changes[new_central].replace(new_frame.encode(), frame.encode()) == source
assert changes[review].replace(new_central.encode(), central.encode()) == index
assert not backup.exists()
backup.mkdir(mode=0o700)
originals = {'index.html': index, central: source, frame: html}
for name, data in originals.items():
    path = backup / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
for name, data in changes.items():
    assert not (root / name).exists()
    write(name, data)
(backup / 'manifest.json').write_text(json.dumps({
    'originals': {name: sha(data) for name, data in originals.items()},
    'published': {name: sha(data) for name, data in changes.items()},
    'review': review, 'css_only': True,
}, indent=2))
print(json.dumps({'review_ready': True, 'review': review, 'backup': str(backup)}))
