"""Deploy reviewed cart controls after staging the compatible preview.

Run on the WooMobile host with the immutable source commit and staged preview
record. Checks live hashes, tests the candidate in a rolled-back transaction,
then atomically switches versioned assets. Keeps originals for recovery.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request

commit, staged_file = sys.argv[1:3]
assert re.fullmatch(r'[a-f0-9]{40}', commit)
api = Path('/home/woomobile/woomobile-api')
root = api / 'public/mobishop-builder-v26'
work = Path('/root/cart-remote-20261027')
work.mkdir(mode=0o700, exist_ok=True)
candidate = work / ('controls-' + commit[:12])
candidate.mkdir(mode=0o700)
sha = lambda data: hashlib.sha256(data).hexdigest()
php = '/opt/cpanel/ea-php83/root/usr/bin/php'

def fetch(path):
    with urllib.request.urlopen(f'https://raw.githubusercontent.com/sayedkhaled205/kidia_store_app/{commit}/{path}', timeout=60) as response:
        return response.read()

expected = {
    'app/Services/LiveAppUiControls.php': '1fe3e359da427348af3f2c663443a76f8b30c5edc4c4ad9cd7d6542fa38bd255',
    'app/Services/live-ui-controls-v1.json': 'f511af72944275efccb4bcfd1d9cd99589b0b94e64853b408b2e69ccdaff72bd',
}
staged = json.loads(Path(staged_file).read_text())
assert staged['source_commit'] == commit
preview_record = json.loads((Path(staged['backup']) / 'manifest.json').read_text())
for name, digest in {**preview_record['originals'], **preview_record['published']}.items():
    assert sha((root / name).read_bytes()) == digest, 'Preview changed: ' + name
for name, digest in expected.items():
    assert sha((api / name).read_bytes()) == digest, 'Backend changed: ' + name
    (candidate / Path(name).name).write_bytes(fetch('tools/live_ui_controls/backend/' + name))
(candidate / 'backend-test.php').write_bytes(fetch('tools/live_ui_controls/backend-test.php'))
subprocess.run([php, '-l', str(candidate / 'LiveAppUiControls.php')], check=True)
runner = candidate / 'verify.php'
runner.write_text("<?php require __DIR__.'/LiveAppUiControls.php'; require __DIR__.'/backend-test.php';\n")
subprocess.run([php, str(runner)], check=True, cwd=api)

helper = fetch('tools/live_ui_controls/page-controls.js')
helper_name = 'assets/page-controls-' + sha(helper)[:12] + '.js'
review = (root / staged['review']).read_text()
old_helpers = re.findall(r'assets/page-controls-[a-f0-9]+\.js', review)
assert len(old_helpers) == 1
old_helper = root / old_helpers[0]
assert sha(old_helper.read_bytes()) == '591bdbbe41e61992fa4d64cd10f7b8f19ab1d0852254b1b6e5af5359204ebbcf'
updated = review.replace(old_helpers[0], helper_name)
assert updated.replace(helper_name, old_helpers[0]) == review
backup = candidate / 'backup'
backup.mkdir(mode=0o700)
paths = [api / name for name in expected] + [root / 'index.html']
originals = {str(path): path.read_bytes() for path in paths}
for path in paths:
    shutil.copy2(path, backup / path.name)

def write(path, data, owner_path=None):
    owner = (owner_path or path).stat()
    temp = path.with_name(path.name + '.cart-update-tmp')
    with temp.open('xb') as handle:
        handle.write(data)
    os.chown(temp, owner.st_uid, owner.st_gid)
    os.chmod(temp, owner.st_mode & 0o777)
    temp.replace(path)

assert not (root / helper_name).exists()
write(root / helper_name, helper, root / 'index.html')
# Recheck immediately before activation; no other chat's changes are replaced.
for path in paths:
    assert path.read_bytes() == originals[str(path)], 'Changed during review: ' + str(path)
try:
    for name in expected:
        write(api / name, (candidate / Path(name).name).read_bytes())
    write(root / 'index.html', updated.encode())
    subprocess.run([php, str(candidate / 'backend-test.php')], check=True, cwd=api)
except Exception:
    for path in paths:
        write(path, originals[str(path)])
    raise
record = {'source_commit': commit, 'backup': str(backup), 'preview': staged['bundle'],
          'page_controls': helper_name, 'originals': {p: sha(b) for p, b in originals.items()},
          'published': {str(p): sha(p.read_bytes()) for p in paths}}
(candidate / 'deployed.json').write_text(json.dumps(record, indent=2))
print(json.dumps(record, indent=2))
