"""Stage the tested shared publication expansion without replacing live edits."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
import urllib.request
import zipfile

commit = sys.argv[1]
assert re.fullmatch(r'[a-f0-9]{40}', commit)
root = Path('/home/woomobile/woomobile-api/public/mobishop-builder-v26')
work = Path('/root/woomobile-audit-20261026')
work.mkdir(exist_ok=True, mode=0o700)
sha = lambda data: hashlib.sha256(data).hexdigest()

def fetch(name):
    assert '..' not in name.split('/')
    with urllib.request.urlopen(f'https://raw.githubusercontent.com/sayedkhaled205/kidia_store_app/{commit}/{name}', timeout=60) as response:
        return response.read()

manifest = json.loads(fetch('docs/evidence/woomobile-audit-20261026/preview-manifest.json'))
index = (root / 'index.html').read_text()
central = re.search(r'assets/(?:original|customize)-central[^"?\s]+\.js', index).group()
source = (root / central).read_text()
old_bundle = root / re.search(r'assets/flutter-preview-[\w-]+/', source).group()
assert sha((old_bundle / 'main.dart.js').read_bytes()) == '560b2127c6b0d82bb659b5b00af7c53f3b6e3c4fadd6dcb06891540408465e89', 'Live Flutter source changed since review'
archive = work / 'preview.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
    for name, expected in sorted(manifest.items()):
        old = old_bundle / name
        data = old.read_bytes() if old.is_file() else b''
        if sha(data) != expected:
            data = fetch('mobishop/admin/flutter-preview/' + name)
        assert sha(data) == expected, name
        entry = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
        entry.external_attr = 0o100644 << 16
        z.writestr(entry, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
for name in ['publish-preview-runtime.py', 'repair-preview-contracts.py',
             'category-designer.js', 'preview-commerce-config.js', 'preview-interactions.js']:
    (work / name).write_bytes(fetch('tool/builder-assets/' + name))
digest = sha(archive.read_bytes())
args = [sys.executable, str(work / 'publish-preview-runtime.py'), str(root),
        str(archive), str(work / 'preview-interactions.js'), digest]
result = subprocess.run(args, check=True, text=True, capture_output=True)
record = json.loads(result.stdout)
record.update(source_commit=commit, archive_sha256=digest, assets=len(manifest))
(work / 'staged.json').write_text(json.dumps(record, indent=2))
(work / 'activate.json').write_text(json.dumps(args + ['--activate']))
print(json.dumps(record, indent=2))
