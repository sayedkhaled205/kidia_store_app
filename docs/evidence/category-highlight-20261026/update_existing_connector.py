"""Apply the same two reviewed category-schema files to an existing connector.

This narrow update retains locally installed integrations and all store data.
Both files must match the pre-feature source before either is changed.
"""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys
import urllib.request

root = Path(sys.argv[1]).resolve()
backup = Path(sys.argv[2]).resolve()
assert root.is_dir() and (root / 'mobi2app-connector.php').is_file()
assert not backup.exists()
base = 'c5746acece99d79d7dd3637110b1632a07f34b33'
commit = 'b46da96ca1c990e02f11f4acbcb477341cfaf1fa'
names = ['includes/class-mobishop-category-page-store.php', 'api/class-category-page-endpoint.php']
sha = lambda data: hashlib.sha256(data).hexdigest()
def fetch(revision, name):
    with urllib.request.urlopen(f'https://raw.githubusercontent.com/sayedkhaled205/kidia_store_app/{revision}/{name}', timeout=60) as response:
        return response.read()
old = json.loads(fetch(base, 'connectors/woocommerce/source-manifest.json'))
new = json.loads(fetch(commit, 'connectors/woocommerce/source-manifest.json'))
before, after = {}, {}
for name in names:
    path = root / name
    assert path.resolve().is_relative_to(root)
    before[name] = path.read_bytes()
    assert sha(before[name].replace(b'\r\n', b'\n')) == old['files'][name]['source_sha256'], name
    after[name] = fetch(commit, new['files'][name]['source'])
    assert sha(after[name]) == new['files'][name]['source_sha256'], name
backup.mkdir(mode=0o700, parents=True)
for name in names:
    target = backup / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / name, target)
    candidate = target.with_suffix('.candidate.php')
    candidate.write_bytes(after[name])
    subprocess.run(['/opt/cpanel/ea-php83/root/usr/bin/php', '-l', str(candidate)], check=True)
assert all((root / n).read_bytes() == before[n] for n in names), 'Concurrent connector edit'
for name in names:
    path = root / name
    tmp = path.with_name(path.name + '.highlight-staged')
    with tmp.open('xb') as f:
        f.write(after[name])
    stat = path.stat()
    os.chown(tmp, stat.st_uid, stat.st_gid)
    os.chmod(tmp, stat.st_mode & 0o777)
    tmp.replace(path)
record = dict(source_commit=commit, files={n:sha(after[n]) for n in names}, settings_changed=False)
(backup / 'result.json').write_text(json.dumps(record, indent=2))
print(json.dumps(record))
