"""Stage 112 presentation controls and their preview; activate/rollback with CAS.

Run on the inspected WHM host: python3 deploy-live-controls112.py REPO [--activate|--rollback].
No merchant settings, nginx configuration or installed binaries are changed.
"""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess, sys

repo = Path(sys.argv[1]).resolve()
api = Path('/home/woomobile/woomobile-api')
root = api / 'public/mobishop-builder-v26'
preview = repo / 'mobishop/admin/flutter-preview'
sha = lambda value: hashlib.sha256(value).hexdigest()
schema = repo / 'tools/live_ui_controls/backend/app/Services/live-ui-controls-v1.json'
controls = repo / 'tools/live_ui_controls/page-controls.js'
version = sha((preview/'main.dart.js').read_bytes()+schema.read_bytes()+controls.read_bytes())[:12]
backup = Path('/home/woomobile/live-controls112-backup-'+version)
manifest = backup/'manifest.json'
owner = (root/'index.html').stat()

def digest(path): return sha(path.read_bytes())
def write(path, data):
    tmp = path.with_name(path.name+'.controls112-tmp')
    with tmp.open('xb') as stream: stream.write(data)
    os.chown(tmp, owner.st_uid, owner.st_gid); os.chmod(tmp, 0o644); tmp.replace(path)

if '--activate' in sys.argv or '--rollback' in sys.argv:
    m = json.loads(manifest.read_text()); rollback = '--rollback' in sys.argv
    for name, rec in m['changes'].items():
        assert digest(Path(name)) == rec['after' if rollback else 'before'], 'Concurrent change: '+name
    if not rollback:
        for name, checksum in {**m['checks'], **m['staged']}.items():
            assert digest(Path(name)) == checksum, 'Concurrent dependency: '+name
    for name, rec in m['changes'].items():
        write(Path(name), (backup/rec['old' if rollback else 'new']).read_bytes())
    print(json.dumps({'activated': not rollback, 'backup':str(backup), 'bundle':m['bundle']})); sys.exit()

assert not backup.exists(), 'Review existing stage'
assert len(json.loads(schema.read_text())) == 112
index = (root/'index.html').read_text()
central = re.search(r'assets/original-central[^"?\s]+\.js', index).group()
parent = (root/central).read_text()
frame = re.search(r'screen-frame[^"?\s]+\.html', parent).group()
frame_html = (root/frame).read_text()
child_name = re.search(r'assets/screen-frame[^"?\s]+\.js', frame_html).group()
child = (root/child_name).read_text()
old_bundle = re.search(r'assets/flutter-preview-[\w-]+/', parent).group()
assert old_bundle == 'assets/flutter-preview-catalog-filters-75c126348f51/', 'Review newer preview first'
old_guard = "['home-builder','account-builder','checkout-builder'].includes(request.screen)"
new_guard = "['home-builder','account-builder','checkout-builder','catalog-builder','product-builder'].includes(request.screen)"
assert parent.count(old_guard) == 1 and 'await window.MobiShopPageControls.save(sender);' in parent
assert 'MobiShopPageControls.decoratePreview(packet)' in parent
assert '<base href="./">' in (preview/'index.html').read_text()
assert '__mobishopStartFlutterPreview' in (preview/'flutter_bootstrap.js').read_text()
live_schema = api/'app/Services/live-ui-controls-v1.json'
before_schema = json.loads(live_schema.read_text()); after_schema = json.loads(schema.read_text())
assert len(before_schema) == 73 and all(after_schema[k] == v for k,v in before_schema.items()), 'Existing controls changed'

# Candidate classes must be exactly the already-deployed implementations.
for relative in ['app/Services/LiveAppUiControls.php','app/Http/Controllers/Portal/LiveAppDesignController.php']:
    assert (api/relative).read_text() == (repo/'tools/live_ui_controls/backend'/relative).read_text(), 'Review live class drift: '+relative
php = '/opt/cpanel/ea-php83/root/usr/bin/php'
subprocess.run([php,str(repo/'tools/live_ui_controls/normalization-test.php')],check=True)
subprocess.run([php,str(repo/'tools/live_ui_controls/backend-test.php'),str(repo/'tools/live_ui_controls/backend')],check=True)
backup.mkdir(mode=0o700)
bundle = 'assets/flutter-preview-live-controls112-'+version+'/'
m = {'bundle':bundle,'changes':{},'checks':{str(root/p):digest(root/p) for p in [central,frame,child_name]},'staged':{}}
for relative in ['app/Services/LiveAppUiControls.php','app/Http/Controllers/Portal/LiveAppDesignController.php']:
    m['checks'][str(api/relative)] = digest(api/relative)
shutil.copytree(preview, root/bundle)
for path in [root/bundle, *(root/bundle).rglob('*')]:
    os.chown(path,owner.st_uid,owner.st_gid); os.chmod(path,0o755 if path.is_dir() else 0o644)
    if path.is_file(): m['staged'][str(path)] = digest(path)
new_central = 'assets/original-central-live-controls112-'+version+'.js'
new_frame = 'screen-frame-live-controls112-'+version+'.html'
new_child = 'assets/screen-frame-live-controls112-'+version+'.js'
new_controls = 'assets/page-controls-'+sha(controls.read_bytes())[:12]+'.js'
assets = {
    new_central:parent.replace(old_guard,new_guard).replace(old_bundle,bundle).replace(frame,new_frame).encode(),
    new_frame:frame_html.replace(child_name,new_child).encode(),
    new_child:child.replace(old_bundle,bundle).encode(),
    new_controls:controls.read_bytes(),
}
for name,data in assets.items():
    path = root/name
    if path.exists(): assert path.read_bytes() == data, 'Immutable asset collision'
    else: write(path,data)
    m['staged'][str(path)] = digest(path)
updated = index.replace(central,new_central)
updated, count = re.subn(r'<script src="assets/page-controls-[a-f0-9]+\.js[^"\n]*"></script>', '<script src="'+new_controls+'"></script>', updated)
assert count == 1, 'Controls include changed'
for path,data in [(live_schema,schema.read_bytes()),(root/'index.html',updated.encode())]:
    n = str(len(m['changes'])); (backup/(n+'.old')).write_bytes(path.read_bytes()); (backup/(n+'.new')).write_bytes(data)
    m['changes'][str(path)] = {'old':n+'.old','new':n+'.new','before':digest(path),'after':sha(data)}
manifest.write_text(json.dumps(m,indent=2))
print(json.dumps({'staged':True,'backup':str(backup),'bundle':bundle}))
