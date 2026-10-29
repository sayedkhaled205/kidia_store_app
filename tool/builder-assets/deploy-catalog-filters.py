"""Publish filter preview and its public metadata bridge with CAS rollback."""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess, sys
repo=Path(sys.argv[1]).resolve()
api=Path('/home/woomobile/woomobile-api')
root=api/'public/mobishop-builder-v26'
preview=repo/'mobishop/admin/flutter-preview'
digest=lambda b:hashlib.sha256(b).hexdigest()
version=digest((preview/'main.dart.js').read_bytes())[:12]
backup=Path('/home/woomobile/catalog-filters-backup-'+version)
manifest=backup/'manifest.json'
owner=(root/'index.html').stat()
def write(path,data):
    temp=path.with_name(path.name+'.filters-tmp')
    with temp.open('xb') as f:f.write(data)
    os.chmod(temp,0o644);os.chown(temp,owner.st_uid,owner.st_gid);temp.replace(path)
def current(path):return digest(path.read_bytes()) if path.exists() else None
if '--activate' in sys.argv or '--rollback' in sys.argv:
    m=json.loads(manifest.read_text());rollback='--rollback' in sys.argv
    for path,rec in m['changes'].items():assert current(Path(path))==rec['after' if rollback else 'before'],'Concurrent change: '+path
    if not rollback:
        for path,value in {**m['checks'],**m['staged']}.items():assert current(Path(path))==value,'Changed dependency: '+path
    for path,rec in m['changes'].items():
        source=rec['old' if rollback else 'new']
        if source is None:Path(path).unlink()
        else:write(Path(path),(backup/source).read_bytes())
    print(json.dumps({'activated':not rollback,'backup':str(backup),'bundle':m['bundle']}));sys.exit()
assert not backup.exists(),'Inspect existing stage'
index=(root/'index.html').read_text()
central=re.search(r'assets/(?:original|customize)-central[^"?\s]+\.js',index).group()
parent=(root/central).read_text()
frame=re.search(r'(?:screen-frame|customize-screen-frame)[^"?\s]+\.html',parent).group()
frame_html=(root/frame).read_text()
script=re.search(r'assets/(?:screen-frame|customize-screen-frame)[^"?\s]+\.js',frame_html).group()
child=(root/script).read_text()
old_bundle=re.search(r'assets/flutter-preview-[\w-]+/',parent).group()
assert old_bundle in ['assets/flutter-preview-shared-product-cards-20e13f6db012/', 'assets/flutter-preview-catalog-filters-8616737740dc/'],'Review concurrently published preview'
parent_anchor="per_page:Number(data.per_page) || 20, error:data.items_error || ''"
child_anchor="error: storeData.items_error || ''"
assert parent.count(parent_anchor)==1 and child.count(child_anchor)==1
if 'filter_options:data.filter_options || null' not in parent:parent=parent.replace(parent_anchor,'filter_options:data.filter_options || null, '+parent_anchor)
if 'filter_options: storeData.filter_options || null' not in child:child=child.replace(child_anchor,'filter_options: storeData.filter_options || null, '+child_anchor)
controller=api/'app/Http/Controllers/Portal/DashboardController.php'
source=controller.read_text()
anchor='    private function builderStoreData($store, int $page = 1, array $dataQuery = []): array\n    {\n'
assert source.count(anchor)==1
hook="        if (($dataQuery['catalog_resource'] ?? null) === 'filter_options') {\n            return app(\\App\\Services\\BuilderCatalogFilters::class)->forStore($store);\n        }\n"
if 'BuilderCatalogFilters' in source:assert source.count(anchor+hook)==1
else:source=source.replace(anchor,anchor+hook)
backup.mkdir(mode=0o700)
bundle='assets/flutter-preview-catalog-filters-'+version+'/'
m={'bundle':bundle,'changes':{},'checks':{str(root/p):current(root/p) for p in [central,frame,script]},'staged':{}}
assert '<base href="./">' in (preview/'index.html').read_text()
assert '__mobishopStartFlutterPreview' in (preview/'flutter_bootstrap.js').read_text()
shutil.copytree(preview,root/bundle)
for p in [root/bundle,*(root/bundle).rglob('*')]:
    os.chown(p,owner.st_uid,owner.st_gid);os.chmod(p,0o755 if p.is_dir() else 0o644)
    if p.is_file():m['staged'][str(p)]=current(p)
new_central='assets/original-central-catalog-filters-'+version+'.js'
new_frame='screen-frame-catalog-filters-'+version+'.html'
new_script='assets/screen-frame-catalog-filters-'+version+'.js'
for path,data in {new_central:parent.replace(old_bundle,bundle).replace(frame,new_frame),new_frame:frame_html.replace(script,new_script),new_script:child.replace(old_bundle,bundle)}.items():
    assert not (root/path).exists();write(root/path,data.encode());m['staged'][str(root/path)]=current(root/path)
def stage(path,data):
    n=str(len(m['changes']));old=n+'.old' if path.exists() else None
    if old:(backup/old).write_bytes(path.read_bytes())
    (backup/(n+'.new')).write_bytes(data)
    m['changes'][str(path)]={'old':old,'new':n+'.new','before':current(path),'after':digest(data)}
    if path.suffix=='.php':subprocess.run(['/opt/cpanel/ea-php83/root/usr/bin/php','-l',str(backup/(n+'.new'))],check=True)
stage(api/'app/Services/BuilderCatalogFilters.php',(repo/'tool/builder-assets/BuilderCatalogFilters.php').read_bytes())
stage(controller,source.encode())
stage(root/'index.html',index.replace(central,new_central).encode())
subprocess.run(['/opt/cpanel/ea-php83/root/usr/bin/php',str(repo/'tool/builder-assets/test-catalog-filters.php')],check=True)
manifest.write_text(json.dumps(m,indent=2))
print(json.dumps({'staged':True,'backup':str(backup),'bundle':bundle}))
