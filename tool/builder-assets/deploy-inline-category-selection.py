"""Publish only the reviewed category renderer; preserve live theme and forms."""
from pathlib import Path
import hashlib,json,os,re,shutil,sys
repo=Path(sys.argv[1]).resolve();root=Path('/home/woomobile/woomobile-api/public/mobishop-builder-v26')
preview=repo/'mobishop/admin/flutter-preview';sha=lambda b:hashlib.sha256(b).hexdigest()
version=sha((preview/'main.dart.js').read_bytes())[:12]
backup=Path('/home/woomobile/inline-category-backup-'+version);manifest=backup/'manifest.json'
def write(path,data):
    owner=(path if path.exists() else path.parent).stat();temp=path.with_name(path.name+'.inline-tmp')
    with temp.open('xb') as f:f.write(data)
    os.chown(temp,owner.st_uid,owner.st_gid);os.chmod(temp,0o644);temp.replace(path)
if '--activate' in sys.argv or '--rollback' in sys.argv:
    m=json.loads(manifest.read_text());rollback='--rollback' in sys.argv
    assert sha((root/'index.html').read_bytes())==m['after' if rollback else 'before'],'Concurrent index change'
    if not rollback:
        for name,digest in {**m['checks'],**m['staged']}.items():assert sha(Path(name).read_bytes())==digest,'Concurrent dependency: '+name
    write(root/'index.html',(backup/('index.old' if rollback else 'index.new')).read_bytes())
    print(json.dumps({'activated':not rollback,'backup':str(backup),'bundle':m['bundle'],'theme_mode':m['theme_mode']}));sys.exit()
assert not backup.exists(),'Review existing stage'
index=(root/'index.html').read_text();parent_name=re.search(r'assets/original-central[^"?\s]+\.js',index).group()
parent=(root/parent_name).read_text();frame_name=re.search(r'screen-frame[^"?\s]+\.html',parent).group()
frame=(root/frame_name).read_text();child_name=re.search(r'assets/screen-frame[^"?\s]+\.js',frame).group();child=(root/child_name).read_text()
old_bundle=re.search(r'assets/flutter-preview-[\w-]+/',parent).group()
assert old_bundle=='assets/flutter-preview-qa-bbeab3e8fe99/','Review a newer preview before publishing'
preset_name=re.search(r'assets/theme-snapshots[^"\x27?\s]+\.json',parent).group()
theme_mode=json.loads((root/preset_name).read_text())['kids_baby']['category']['general']['navigation_mode']
assert theme_mode=='products_with_children'
assert json.loads((repo/'tool/builder-assets/kids-appearance-20261027.json').read_text())['category']['general']['navigation_mode']==theme_mode
assert '<base href="./">' in (preview/'index.html').read_text()
assert '__mobishopStartFlutterPreview' in (preview/'flutter_bootstrap.js').read_text()
backup.mkdir(mode=0o700);bundle='assets/flutter-preview-inline-category-'+version+'/'
m={'bundle':bundle,'theme_mode':theme_mode,'checks':{str(root/p):sha((root/p).read_bytes()) for p in [parent_name,frame_name,child_name,preset_name]},'staged':{}}
shutil.copytree(preview,root/bundle);owner=(root/'index.html').stat()
for p in [root/bundle,*(root/bundle).rglob('*')]:
    os.chown(p,owner.st_uid,owner.st_gid);os.chmod(p,0o755 if p.is_dir() else 0o644)
    if p.is_file():m['staged'][str(p)]=sha(p.read_bytes())
new_parent='assets/original-central-inline-category-'+version+'.js';new_frame='screen-frame-inline-category-'+version+'.html';new_child='assets/screen-frame-inline-category-'+version+'.js'
for name,data in {new_parent:parent.replace(old_bundle,bundle).replace(frame_name,new_frame),new_frame:frame.replace(child_name,new_child),new_child:child.replace(old_bundle,bundle)}.items():
    assert not (root/name).exists(),'Immutable asset exists'
    write(root/name,data.encode());m['staged'][str(root/name)]=sha((root/name).read_bytes())
old=(root/'index.html').read_bytes();new=index.replace(parent_name,new_parent).encode()
(backup/'index.old').write_bytes(old);(backup/'index.new').write_bytes(new)
m['before']=sha(old);m['after']=sha(new);manifest.write_text(json.dumps(m,indent=2))
print(json.dumps({'staged':True,'backup':str(backup),'bundle':bundle,'theme_mode':theme_mode}))
