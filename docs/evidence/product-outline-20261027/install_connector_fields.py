"""Patch only the three reviewed installed connector files, with rollback and hashes."""
from pathlib import Path
import argparse
import difflib
import hashlib
import importlib.util
import json
import os
import subprocess
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('commit')
parser.add_argument('--activate', action='store_true')
args = parser.parse_args()
root = Path('/home/kidiastore/public_html/wp-content/plugins/mobi2app-connector')
work = Path('/root/product-outline-20261027/connector-fields')
work.mkdir(exist_ok=True, mode=0o700)
sha = lambda b: hashlib.sha256(b).hexdigest()
if not args.activate:
    helper = work / 'patch.py'
    helper.write_bytes(urllib.request.urlopen('https://raw.githubusercontent.com/sayedkhaled205/kidia_store_app/' + args.commit + '/tool/builder-assets/patch-product-outline-plugin.py', timeout=60).read())
    spec = importlib.util.spec_from_file_location('outline_patch', helper)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    records = {}
    for name in mod.FILES:
        original = (root / name).read_bytes()
        changed = mod.patch(name, original.decode()).encode()
        old, new = work / 'original' / name, work / 'candidate' / name
        for p, b in [(old, original), (new, changed)]:
            p.parent.mkdir(parents=True, exist_ok=True)
            with p.open('xb') as handle:
                handle.write(b)
        subprocess.run(['/usr/local/bin/php', '-l', str(new)], check=True)
        records[name] = {'original': sha(original), 'candidate': sha(changed)}
        print(''.join(difflib.unified_diff(original.decode().splitlines(True), changed.decode().splitlines(True), fromfile=name, tofile=name, n=1)))
    (work / 'manifest.json').write_text(json.dumps({'commit':args.commit, 'files':records}, indent=2))
else:
    record = json.loads((work / 'manifest.json').read_text())
    assert record['commit'] == args.commit
    for name, hashes in record['files'].items():
        assert sha((root / name).read_bytes()) == hashes['original'], 'Concurrent change: ' + name
        assert sha((work / 'candidate' / name).read_bytes()) == hashes['candidate']
    for name, hashes in record['files'].items():
        target = root / name
        owner = target.stat()
        pending = target.with_suffix('.outline-tmp')
        with pending.open('xb') as handle:
            handle.write((work / 'candidate' / name).read_bytes())
        os.chown(pending, owner.st_uid, owner.st_gid)
        os.chmod(pending, owner.st_mode & 0o777)
        pending.replace(target)
        assert sha(target.read_bytes()) == hashes['candidate']
    print('Three outline connector files activated; original files retained in private backup.')
