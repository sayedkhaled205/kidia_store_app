"""Publish the auth preview with the latest shared Kids branding changes."""
from pathlib import Path
import re, zipfile, hashlib, shutil, datetime, os

root = Path('/home/woomobile/woomobile-api/public/mobishop-builder-v26')
archive = Path('/home/kidiastore/builder288-upload/auth-preview308b.zip')
assert hashlib.sha256(archive.read_bytes()).hexdigest() == '34cf37fd95247f2e8870fc844589118b6c82febfe520af4f2b91168ebb759596'
index = (root / 'index.html').read_text()
central = re.search(r'assets/original-central[^"\s]+?\.js', index).group(0)
source = (root / central).read_text()
assert 'mobishop-preview-auth-config-request' in source
old, new = 'assets/flutter-preview-auth308/', 'assets/flutter-preview-auth308b/'
frame, frame_js = 'screen-frame-auth308.html', 'assets/screen-frame-auth308.js'
html, frame_source = (root / frame).read_text(), (root / frame_js).read_text()
assert old in source and old in frame_source
assert frame in source and frame_js in html
target = root / new.rstrip('/')
assert not target.exists()
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for name in z.namelist():
        assert target.resolve() in (target / name).resolve().parents
    z.extractall(target)
new_frame, new_js = 'screen-frame-auth308b.html', 'assets/screen-frame-auth308b.js'
new_central = 'assets/original-central-auth308b.js'
source = source.replace(old, new).replace(frame, new_frame)
frame_source = frame_source.replace(old, new)
html = html.replace(frame_js, new_js).replace('?v=auth308', '?v=auth308b')
index = re.sub('(' + re.escape(central) + r')(?:\?[^"\']*)?', lambda m: new_central + '?v=auth308b', index)
changes = {new_central: source, new_js: frame_source, new_frame: html, 'index.html': index}
backup = root.parent.parent / ('auth-preview-backup-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
backup.mkdir(mode=0o700)
st = (root / 'index.html').stat()
for p in [target, *target.rglob('*')]:
    os.chown(p, st.st_uid, st.st_gid)
    os.chmod(p, 0o755 if p.is_dir() else 0o644)
for name, data in changes.items():
    path, saved = root / name, backup / name
    saved.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        shutil.copy2(path, saved)
    temp = path.with_name(path.name + '.auth-tmp')
    temp.write_text(data)
    os.chown(temp, st.st_uid, st.st_gid)
    os.chmod(temp, 0o644)
    temp.replace(path)
print('AUTH_PREVIEW_DEPLOYED', new, 'backup', backup)
