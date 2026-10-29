"""Stage/activate the search navigation fix without changing live builder settings."""
from pathlib import Path
import hashlib, json, os, re, shutil, sys

repo = Path(sys.argv[1]).resolve()
root = Path('/home/woomobile/woomobile-api/public/mobishop-builder-v26')
preview = repo / 'mobishop/admin/flutter-preview'
sha = lambda data: hashlib.sha256(data).hexdigest()
version = sha((preview / 'main.dart.js').read_bytes())[:12]
backup = Path('/home/woomobile/search-navigation-backup-' + version)
manifest = backup / 'manifest.json'

def write(path, data):
    owner = (root / 'index.html').stat()
    temp = path.with_name(path.name + '.search-tmp')
    with temp.open('xb') as handle:
        handle.write(data)
    os.chown(temp, owner.st_uid, owner.st_gid)
    os.chmod(temp, 0o644)
    temp.replace(path)

if '--activate' in sys.argv or '--rollback' in sys.argv:
    m = json.loads(manifest.read_text())
    rollback = '--rollback' in sys.argv
    assert sha((root / 'index.html').read_bytes()) == m['after' if rollback else 'before']
    if not rollback:
        for path, digest in {**m['checks'], **m['staged']}.items():
            assert sha(Path(path).read_bytes()) == digest, 'Concurrent change: ' + path
    write(root / 'index.html', (backup / ('index.old' if rollback else 'index.new')).read_bytes())
    print(json.dumps({'activated': not rollback, 'backup': str(backup), 'bundle': m['bundle']}))
    sys.exit()

assert not backup.exists(), 'Inspect the existing stage before retrying'
old = (root / 'index.html').read_bytes()
index = old.decode()
parent_name = re.search(r'assets/(?:original|customize)-central[^"?\s]+\.js', index).group()
parent = (root / parent_name).read_text()
frame_name = re.search(r'(?:screen-frame|customize-screen-frame)[^"?\s]+\.html', parent).group()
frame = (root / frame_name).read_text()
child_name = re.search(r'assets/(?:screen-frame|customize-screen-frame)[^"?\s]+\.js', frame).group()
child = (root / child_name).read_text()
old_bundle = re.search(r'assets/flutter-preview-[\w-]+/', parent).group()
assert old_bundle == 'assets/flutter-preview-product-options-d815b316e004/', 'Review newer preview first'
assert '<base href="./">' in (preview / 'index.html').read_text()
assert '__mobishopStartFlutterPreview' in (preview / 'flutter_bootstrap.js').read_text()
backup.mkdir(mode=0o700)
bundle = 'assets/flutter-preview-search-' + version + '/'
new_parent = 'assets/original-central-search-' + version + '.js'
new_frame = 'screen-frame-search-' + version + '.html'
new_child = 'assets/screen-frame-search-' + version + '.js'
m = {'bundle': bundle, 'checks': {str(root / p): sha((root / p).read_bytes()) for p in [parent_name, frame_name, child_name]}, 'staged': {}}
shutil.copytree(preview, root / bundle)
owner = (root / 'index.html').stat()
for path in [root / bundle, *(root / bundle).rglob('*')]:
    os.chown(path, owner.st_uid, owner.st_gid)
    os.chmod(path, 0o755 if path.is_dir() else 0o644)
    if path.is_file():
        m['staged'][str(path)] = sha(path.read_bytes())
for name, data in {
    new_parent: parent.replace(old_bundle, bundle).replace(frame_name, new_frame).encode(),
    new_frame: frame.replace(child_name, new_child).encode(),
    new_child: child.replace(old_bundle, bundle).encode(),
}.items():
    assert not (root / name).exists()
    write(root / name, data)
    m['staged'][str(root / name)] = sha(data)
new = index.replace(parent_name, new_parent).encode()
(backup / 'index.old').write_bytes(old)
(backup / 'index.new').write_bytes(new)
review = 'index-search-' + version + '-review.html'
write(root / review, new)
m['staged'][str(root / review)] = sha(new)
m.update(before=sha(old), after=sha(new), review=review)
manifest.write_text(json.dumps(m, indent=2))
print(json.dumps({'staged': True, 'review': review, 'bundle': bundle, 'backup': str(backup)}))
