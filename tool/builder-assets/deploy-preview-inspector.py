"""Stage, activate or roll back the preview inspector against the current shell."""
from pathlib import Path
import hashlib, importlib.util, json, os, re, shutil, sys
repo=Path(sys.argv[1]).resolve()
root=Path('/home/woomobile/woomobile-api/public/mobishop-builder-v26')
preview=repo/'mobishop/admin/flutter-preview'
helper=(repo/'tool/builder-assets/preview-inspector.js').read_bytes()
sha=lambda b:hashlib.sha256(b).hexdigest()
version=sha((preview/'main.dart.js').read_bytes()+helper)[:12]
backup=Path('/home/woomobile/preview-inspector-backup-'+version)
manifest=backup/'manifest.json'
def write(path,data):
    owner=(path if path.exists() else path.parent).stat()
    temp=path.with_name(path.name+'.inspector-tmp')
    with temp.open('xb') as handle:handle.write(data)
    os.chown(temp,owner.st_uid,owner.st_gid);os.chmod(temp,0o644);temp.replace(path)
if '--activate' in sys.argv or '--rollback' in sys.argv:
    m=json.loads(manifest.read_text());rollback='--rollback' in sys.argv
    assert sha((root/'index.html').read_bytes())==m['after' if rollback else 'before'],'Concurrent index change'
    if not rollback:
        for name,digest in {**m['checks'],**m['staged']}.items():
            assert sha(Path(name).read_bytes())==digest,'Concurrent dependency: '+name
    write(root/'index.html',(backup/('index.old' if rollback else 'index.new')).read_bytes())
    print(json.dumps({'activated':not rollback,'backup':str(backup),'bundle':m['bundle']}));sys.exit()
assert not backup.exists(),'Review existing stage'
index=(root/'index.html').read_text()
assert 'preview-inspector-' not in index,'Inspector already installed; review before updating'
parent_name=re.search(r'assets/original-central[^"?\s]+\.js',index).group()
parent=(root/parent_name).read_text()
frame_name=re.search(r'screen-frame[^"?\s]+\.html',parent).group();frame=(root/frame_name).read_text()
child_name=re.search(r'assets/screen-frame[^"?\s]+\.js',frame).group();child=(root/child_name).read_text()
old_bundle=re.search(r'assets/flutter-preview-[\w-]+/',parent).group()
assert old_bundle=='assets/flutter-preview-inline-category-2fc3f625ed94/','Review newer preview before deploying'
spec=importlib.util.spec_from_file_location('inspector_patch',repo/'tool/builder-assets/patch-preview-inspector.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
parent=module.patch_parent(parent)
assert '<base href="./">' in (preview/'index.html').read_text()
assert '__mobishopStartFlutterPreview' in (preview/'flutter_bootstrap.js').read_text()
backup.mkdir(mode=0o700)
bundle='assets/flutter-preview-inspector-'+version+'/'
new_parent='assets/original-central-inspector-'+version+'.js'
new_frame='screen-frame-inspector-'+version+'.html'
new_child='assets/screen-frame-inspector-'+version+'.js'
helper_name='assets/preview-inspector-'+version+'.js'
m={'bundle':bundle,'checks':{str(root/p):sha((root/p).read_bytes()) for p in [parent_name,frame_name,child_name]},'staged':{}}
shutil.copytree(preview,root/bundle);owner=(root/'index.html').stat()
for p in [root/bundle,*(root/bundle).rglob('*')]:
    os.chown(p,owner.st_uid,owner.st_gid);os.chmod(p,0o755 if p.is_dir() else 0o644)
    if p.is_file():m['staged'][str(p)]=sha(p.read_bytes())
for name,data in {
    new_parent:parent.replace(old_bundle,bundle).replace(frame_name,new_frame).encode(),
    new_frame:frame.replace(child_name,new_child).encode(),
    new_child:child.replace(old_bundle,bundle).encode(),helper_name:helper,
}.items():
    assert not (root/name).exists(),'Immutable asset already exists'
    write(root/name,data);m['staged'][str(root/name)]=sha(data)
old=(root/'index.html').read_bytes()
new=index.replace(parent_name,new_parent).replace('</body>','<script src="'+helper_name+'"></script>\n</body>').encode()
assert new!=old
(backup/'index.old').write_bytes(old);(backup/'index.new').write_bytes(new)
review='index-inspector-'+version+'-review.html';write(root/review,new)
m['staged'][str(root/review)]=sha(new)
m.update(before=sha(old),after=sha(new),review=review)
manifest.write_text(json.dumps(m,indent=2))
print(json.dumps({'staged':True,'backup':str(backup),'bundle':bundle,'review':review}))
