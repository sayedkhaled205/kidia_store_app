"""Stage the category View all release; activate/rollback only unchanged files."""
from pathlib import Path
import difflib, hashlib, importlib.util, json, os, re, shutil, subprocess, sys, zipfile

repo = Path(sys.argv[1]).resolve()
root = Path('/home/woomobile/woomobile-api/public/mobishop-builder-v26')
preview = repo / 'mobishop/admin/flutter-preview'
sha = lambda data: hashlib.sha256(data).hexdigest()
version = sha((preview / 'main.dart.js').read_bytes())[:12]
backup = Path('/home/woomobile/shared-product-cards-backup-' + version)
manifest = backup / 'manifest.json'
base = '980ccccb0d0d9f9b23a54fbe1be662455aa63493'

def write(path, data, owner=None):
    owner = owner or path.stat()
    temp = path.with_name(path.name + '.shared-cards-tmp')
    with temp.open('xb') as handle: handle.write(data)
    os.chown(temp, owner.st_uid, owner.st_gid)
    os.chmod(temp, 0o644)
    temp.replace(path)

def git_source(path):
    return subprocess.check_output(['git', '-c', 'safe.directory='+str(repo), '-C', str(repo), 'show', base+':'+path])

if '--activate' in sys.argv or '--rollback' in sys.argv:
    m = json.loads(manifest.read_text())
    rollback = '--rollback' in sys.argv
    for path, record in m['changes'].items():
        assert sha(Path(path).read_bytes()) == record['after' if rollback else 'before'], 'Concurrent change: '+path
    if not rollback:
        for path, digest in {**m['checks'], **m['staged']}.items():
            assert sha(Path(path).read_bytes()) == digest, 'Concurrent dependency: '+path
    for path, record in m['changes'].items():
        write(Path(path), (backup / record['old' if rollback else 'new']).read_bytes())
    print(json.dumps({'activated': not rollback, 'backup': str(backup), 'bundle': m['bundle']}))
    sys.exit()

assert not backup.exists(), 'Inspect existing stage before retrying'
index = (root/'index.html').read_text()
central = re.search(r'assets/(?:original|customize)-central[^"?\s]+\.js', index).group()
parent = (root/central).read_text()
frame = re.search(r'(?:screen-frame|customize-screen-frame)[^"?\s]+\.html', parent).group()
frame_html = (root/frame).read_text()
script = re.search(r'assets/(?:screen-frame|customize-screen-frame)[^"?\s]+\.js', frame_html).group()
script_text = (root/script).read_text()
old_bundle = re.search(r'assets/flutter-preview-[\w-]+/', parent).group()
assert old_bundle == 'assets/flutter-preview-category-products-footer-d64ec87288da/', 'Review new live preview before replacing it'
preset = re.search(r'assets/theme-snapshots[^"\x27?\s]+\.json', parent).group()
presets = json.loads((root/preset).read_text())
appearance = json.loads((repo/'tool/builder-assets/kids-appearance-20261027.json').read_text())
grid = next(e['settings'] for e in appearance['pages']['catalog']['elements'] if e['type']=='product_grid')
appearance_keys = {'card_style','card_radius','card_outline_color','card_outline_width','image_ratio','enable_image_swipe','show_name','show_price','show_regular_price','show_rating','show_badge','show_wishlist','image_inset','image_radius','content_horizontal_padding','content_top_padding','content_bottom_padding','price_color','price_size','price_prefix'}
style = {k:v for k,v in grid.items() if k in appearance_keys or k.startswith(('quick_add_','product_wishlist_'))}
kids = presets['kids_baby']
for element in kids['home']:
    if element['type'] in ('product_grid','product_carousel'):
        element['settings'].update({k:v for k,v in style.items() if k in element['settings']})
for name,page in kids['pages'].items():
    for element in page.get('elements',[]):
        if element['type'] in ('product_grid','wishlist_grid','related_products') or element['type'].endswith('_recommendations'):
            element['settings'].update({k:v for k,v in style.items() if k in element['settings']})
        if name=='catalog' and element['type']=='product_grid':element['settings']['share_style_across_app']=True
hook = '    KidiaProductOutline.prepare(root, payload.identity);'
assert script_text.count(hook)==1
assert 'KidiaSharedProductCard' not in script_text
script_text = (repo/'tool/builder-assets/shared-product-card-controls.js').read_text()+'\n'+script_text.replace(hook,hook+"\n    if (screen === 'catalog-builder') KidiaSharedProductCard.prepare(root);")
backup.mkdir(mode=0o700)
bundle = 'assets/flutter-preview-shared-product-cards-'+version+'/'
m = {'bundle': bundle, 'changes': {}, 'staged': {}, 'checks': {str(root/p):sha((root/p).read_bytes()) for p in [central,frame,script,preset]}}
owner = (root/'index.html').stat()
assert '<base href="./">' in (preview/'index.html').read_text()
assert '__mobishopStartFlutterPreview' in (preview/'flutter_bootstrap.js').read_text()
assert not (root/bundle).exists()
shutil.copytree(preview, root/bundle)
for path in [root/bundle, *(root/bundle).rglob('*')]:
    os.chown(path, owner.st_uid, owner.st_gid)
    os.chmod(path, 0o755 if path.is_dir() else 0o644)
    if path.is_file(): m['staged'][str(path)] = sha(path.read_bytes())
new_parent='assets/original-central-shared-product-cards-'+version+'.js'
new_frame='screen-frame-shared-product-cards-'+version+'.html'
new_script='assets/screen-frame-shared-product-cards-'+version+'.js'
new_preset='assets/theme-snapshots-shared-product-cards-'+version+'.json'
for ref in set(re.findall(r'assets/theme-snapshots[^"\x27?\s]+\.json', script_text)):
    script_text=script_text.replace(ref,new_preset)
assets={new_parent:parent.replace(old_bundle,bundle).replace(frame,new_frame).replace(preset,new_preset),
        new_frame:frame_html.replace(script,new_script),new_script:script_text.replace(old_bundle,bundle),
        new_preset:json.dumps(presets,ensure_ascii=False,separators=(',',':'))}
for path, data in assets.items():
    assert not (root/path).exists()
    write(root/path,data.encode(),owner)
    m['staged'][str(root/path)] = sha((root/path).read_bytes())

def stage(path,data):
    old=path.read_bytes(); n=str(len(m['changes']))
    (backup/(n+'.old')).write_bytes(old); (backup/(n+'.new')).write_bytes(data)
    m['changes'][str(path)]={'before':sha(old),'after':sha(data),'old':n+'.old','new':n+'.new'}
    if path.suffix=='.php': subprocess.run(['/opt/cpanel/ea-php83/root/usr/bin/php','-l',str(backup/(n+'.new'))],check=True)

schema_path = root.parents[1] / 'app/Services/SavedBuilderNativeDesign.php'
spec = importlib.util.spec_from_file_location('footer_schema', repo/'tool/builder-assets/patch-shared-product-card-schema.py')
patcher = importlib.util.module_from_spec(spec); spec.loader.exec_module(patcher)
candidate = patcher.patch(schema_path.read_text())
assert patcher.patch(candidate) == candidate
stage(schema_path, candidate.encode())
subprocess.run(['/opt/cpanel/ea-php83/root/usr/bin/php', str(repo/'tool/builder-assets/shared-product-card-schema-test.php'), str(backup/m['changes'][str(schema_path)]['new'])], check=True)

for rel in ['includes/class-mobishop-page-layout-store.php']:
    path=Path('/home/kidiastore/public_html/wp-content/plugins/mobi2app-connector')/rel
    raw=path.read_bytes(); newline='\r\n' if b'\r\n' in raw else '\n'
    live=raw.decode().replace('\r\n','\n')
    before=git_source('connectors/woocommerce/source/'+rel).decode().splitlines(True)
    after=(repo/'connectors/woocommerce/source'/rel).read_text().splitlines(True)
    for group in difflib.SequenceMatcher(None,before,after).get_grouped_opcodes(2):
        a=''.join(before[group[0][1]:group[-1][2]]); b=''.join(after[group[0][3]:group[-1][4]])
        assert live.count(a)==1,'Concurrent connector change: '+rel
        live=live.replace(a,b,1)
    stage(path,live.replace('\n',newline).encode())

downloads=Path('/home/woomobile/public_html/downloads')
old_manifest=json.loads(git_source('connectors/woocommerce/source-manifest.json'))
old_release=json.loads((downloads/'connector-release.json').read_text())
assert old_release['version']==old_manifest['version']=='1.46.114'
assert sha((downloads/'mobi2app-connector.zip').read_bytes())==old_release['sha256']
with zipfile.ZipFile(downloads/'mobi2app-connector.zip') as package:
    assert len(package.namelist())==len(old_manifest['files'])
    for name,record in old_manifest['files'].items(): assert sha(package.read('mobi2app-connector/'+name))==record['sha256'],name
subprocess.run(['python3',str(repo/'tool/build_woocommerce_connector.py')],check=True)
release=(repo/'build/woocommerce/connector-release.json').read_bytes()
metadata=json.loads(release); assert metadata['version']=='1.46.115'
archive=(repo/'build/woocommerce'/metadata['file']).read_bytes()
assert sha(archive)==metadata['sha256']
versioned=downloads/metadata['file']; assert not versioned.exists()
write(versioned,archive,(downloads/'mobi2app-connector.zip').stat());m['staged'][str(versioned)]=sha(archive)
stage(downloads/'mobi2app-connector.zip',archive)
stage(downloads/'connector-release.json',release)
candidate=index.replace(central,new_parent).encode()
stage(root/'index.html',candidate)
review=root/('index-shared-product-cards-'+version+'-review.html')
write(review,candidate,owner);m['staged'][str(review)]=sha(candidate)
manifest.write_text(json.dumps(m,indent=2))
print(json.dumps({'staged':True,'review':review.name,'backup':str(backup),'bundle':bundle}))
