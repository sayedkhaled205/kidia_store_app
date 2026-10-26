"""Activate the reviewed preview and its compatible optional color schema."""
from pathlib import Path
import hashlib
import json
import os
import subprocess

work = Path('/root/product-outline-20261027')
root = Path('/home/woomobile/woomobile-api/public/mobishop-builder-v26')
schema = Path('/home/woomobile/woomobile-api/app/Services/SavedBuilderNativeDesign.php')
sha = lambda data: hashlib.sha256(data).hexdigest()
record = json.loads((work / 'staged.json').read_text())
manifest = json.loads((Path(record['backup']) / 'manifest.json').read_text())
for name, expected in {**manifest['originals'], **manifest['published']}.items():
    assert sha((root / name).read_bytes()) == expected, 'Changed since review: ' + name
assert schema.read_bytes() == (work / 'schema-original.php').read_bytes(), 'Schema changed since review'
owner = schema.stat()
pending = schema.with_suffix('.outline-tmp')
with pending.open('xb') as handle:
    handle.write((work / 'schema-candidate.php').read_bytes())
os.chown(pending, owner.st_uid, owner.st_gid)
os.chmod(pending, owner.st_mode & 0o777)
pending.replace(schema)
subprocess.run(json.loads((work / 'activate.json').read_text()), check=True)
print('Optional outline schema and reviewed preview activated')
