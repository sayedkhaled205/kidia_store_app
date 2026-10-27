"""Publish the tested card-form serialization helper without replacing live edits."""
from pathlib import Path
import hashlib
import importlib.util
import json
import os
import re
import sys

root, helper = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).read_text()
spec = importlib.util.spec_from_file_location('kids_deploy', Path(__file__).with_name('deploy-kids-product-polish.py'))
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)
sha = lambda b: hashlib.sha256(b).hexdigest()
version = sha(helper.encode())[:12]
backup = root.parents[2] / ('card-form-backup-' + version)
assert not backup.exists()
backup.mkdir(mode=0o700)
originals = {}

def read(name):
    data = (root / name).read_bytes()
    originals[name] = sha(data)
    path = backup / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data.decode()

index = read('index.html')
central_ref = re.search(r'assets/(?:original|customize)-central[^"?\s]+\.js', index)[0]
central = read(central_ref)
frame_ref = re.search(r'(?:screen-frame|customize-screen-frame)[^"?\s]+\.html', central)[0]
frame = read(frame_ref)
script_ref = re.search(r'assets/(?:screen-frame|customize-screen-frame)[^"?\s]+\.js', frame)[0]
script = read(script_ref)
start = script.index('/* Product card outlines share')
ending = "})(typeof window === 'undefined' ? globalThis : window);"
end = script.index(ending, start) + len(ending)
script = deploy.patch_form_serialization(script[:start] + helper.strip() + script[end:])
new_central = 'assets/original-central-card-form-' + version + '.js'
new_frame = 'screen-frame-card-form-' + version + '.html'
new_script = 'assets/screen-frame-card-form-' + version + '.js'
owner = (root / 'index.html').stat()

def write(name, data):
    target = root / name
    tmp = target.with_name(target.name + '.card-form-tmp')
    with tmp.open('xb') as handle:
        handle.write(data)
    os.chown(tmp, owner.st_uid, owner.st_gid)
    os.chmod(tmp, 0o644)
    tmp.replace(target)

for name, value in [(new_central, central.replace(frame_ref, new_frame)), (new_frame, frame.replace(script_ref, new_script)), (new_script, script)]:
    assert not (root / name).exists()
    write(name, value.encode())
for name, expected in originals.items():
    assert sha((root / name).read_bytes()) == expected, 'Concurrent edit: ' + name
write('index.html', index.replace(central_ref, new_central).encode())
(backup / 'manifest.json').write_text(json.dumps({'originals': originals, 'central': new_central, 'frame': new_frame, 'script': new_script}, indent=2))
print(json.dumps({'activated': True, 'backup': str(backup), 'frame': new_frame}))
