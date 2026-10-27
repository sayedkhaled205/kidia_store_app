"""Update the Kids preset reference, preserving all concurrent builder assets."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys

root, candidate, expected = Path(sys.argv[1]).resolve(), Path(sys.argv[2]), sys.argv[3]
sha = lambda b: hashlib.sha256(b).hexdigest()
candidate_bytes = candidate.read_bytes()
assert sha(candidate_bytes) == expected, 'Candidate differs from reviewed file'
index_path = root / 'index.html'
index_bytes = index_path.read_bytes()
index = index_bytes.decode()
parent_ref = re.findall(r'assets/((?:original|customize)-central[^"?]+\.js)', index)
assert len(parent_ref) == 1
parent_path = root / 'assets' / parent_ref[0]
parent_bytes = parent_path.read_bytes()
parent = parent_bytes.decode()
old_refs = set(re.findall(r'assets/(theme-snapshots[^"\x27?]+\.json)', parent))
assert len(old_refs) == 1
old_name = old_refs.pop()
old_path = root / 'assets' / old_name
old_bytes = old_path.read_bytes()
before, after = json.loads(old_bytes), json.loads(candidate_bytes)
assert before.keys() == after.keys()
assert all(before[k] == after[k] for k in before if k != 'kids_baby'), 'Another theme changed'
version = expected[:12]
new_name = 'theme-snapshots-kids-' + version + '.json'
new_parent = 'original-central-kids-' + version + '.js'
frame_refs = set(re.findall(r'((?:screen-frame|customize-screen-frame)[^"\x27?\s]+\.html)', parent))
assert len(frame_refs) == 1
frame_name = frame_refs.pop()
frame_path = root / frame_name
frame_bytes = frame_path.read_bytes()
frame_html = frame_bytes.decode()
script_refs = set(re.findall(r'assets/((?:screen-frame|customize-screen-frame)[^"\x27?]+\.js)', frame_html))
assert len(script_refs) == 1
script_name = script_refs.pop()
script_path = root / 'assets' / script_name
script_bytes = script_path.read_bytes()
script = script_bytes.decode()
preview_presets = set(re.findall(r'assets/(theme-snapshots[^"\x27?]+\.json)', script))
assert preview_presets, 'Setup preview preset reference missing'
new_frame = 'screen-frame-kids-' + version + '.html'
new_script = 'screen-frame-kids-' + version + '.js'
backup = root.parent / ('kids-theme-backup-' + version)
assert not backup.exists(), 'Already deployed or staged: inspect backup first'
backup.mkdir(mode=0o700)
for name, data in [('index.html', index_bytes), ('parent.js', parent_bytes), ('presets.json', old_bytes), ('frame.html', frame_bytes), ('frame.js', script_bytes)]:
    (backup / name).write_bytes(data)

def write(path, data):
    assert root in path.resolve().parents
    temp = path.with_name(path.name + '.kids-tmp')
    with temp.open('xb') as handle:
        handle.write(data)
    st = index_path.stat()
    os.chown(temp, st.st_uid, st.st_gid)
    os.chmod(temp, 0o644)
    temp.replace(path)

patched_parent = parent.replace(old_name, new_name).replace(frame_name, new_frame)
patched_index = index.replace(parent_ref[0], new_parent)
for preview_preset in preview_presets:
    script = script.replace(preview_preset, new_name)
write(root / 'assets' / new_name, candidate_bytes)
write(root / 'assets' / new_script, script.encode())
write(root / new_frame, frame_html.replace(script_name, new_script).encode())
write(root / 'assets' / new_parent, patched_parent.encode())
assert index_path.read_bytes() == index_bytes and parent_path.read_bytes() == parent_bytes and old_path.read_bytes() == old_bytes and frame_path.read_bytes() == frame_bytes and script_path.read_bytes() == script_bytes, 'Concurrent change detected'
write(index_path, patched_index.encode())
(backup / 'manifest.json').write_text(json.dumps({'original_index': sha(index_bytes), 'original_parent': sha(parent_bytes), 'original_presets': sha(old_bytes), 'presets': new_name, 'parent': new_parent, 'candidate_sha': expected}, indent=2))
print(json.dumps({'published': True, 'preset': new_name, 'parent': new_parent, 'backup': str(backup)}))
