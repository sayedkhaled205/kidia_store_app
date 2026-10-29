"""Stage narrowly patched current server files; CAS activation preserves concurrent work."""
from pathlib import Path
import difflib,hashlib,importlib.util,json,os,re,subprocess,sys,zipfile
repo=Path(sys.argv[1]).resolve(); assets=repo/'tool/builder-assets'
api=Path('/home/woomobile/woomobile-api'); root=api/'public/mobishop-builder-v26'
wp=Path('/home/kidiastore/public_html/wp-content/plugins/mobi2app-connector')
base='da4a639d9df8970f509a8ddeeed95055d31ab0bd'
sha=lambda data:hashlib.sha256(data).hexdigest()
version=sha((assets/'push-analytics.js').read_bytes()+(assets/'push-analytics.css').read_bytes())[:12]
backup=Path('/home/woomobile/push-analytics-backup-'+version); manifest=backup/'manifest.json'
if '--backup' in sys.argv:
    backup=Path(sys.argv[sys.argv.index('--backup')+1]).resolve()
    assert backup.parent==Path('/home/woomobile') and backup.name.startswith('push-analytics-backup-')
    manifest=backup/'manifest.json'
def current(path):return sha(path.read_bytes()) if path.exists() else None
def write(path,data):
    owner=(path if path.exists() else path.parent).stat();temp=path.with_name(path.name+'.push-tmp')
    with temp.open('xb') as f:f.write(data)
    os.chmod(temp,0o644);os.chown(temp,owner.st_uid,owner.st_gid);temp.replace(path)
if '--activate' in sys.argv or '--rollback' in sys.argv:
    m=json.loads(manifest.read_text());rollback='--rollback' in sys.argv
    for name,item in m['changes'].items():assert current(Path(name))==item['after' if rollback else 'before'],'Concurrent change: '+name
    if not rollback:
        for name,digest in {**m['checks'],**m['staged']}.items():assert current(Path(name))==digest,'Changed dependency: '+name
    for name,item in m['changes'].items():
        source=item['old' if rollback else 'new'];path=Path(name)
        if source is None:path.unlink()
        else:write(path,(backup/source).read_bytes())
    print(json.dumps({'activated':not rollback,'backup':str(backup)}));sys.exit()
assert not backup.exists(),'Inspect existing stage'
spec=importlib.util.spec_from_file_location('push_patch',assets/'patch-push-analytics.py');patch=importlib.util.module_from_spec(spec);spec.loader.exec_module(patch)
index=(root/'index.html').read_text();central=re.search(r'assets/(?:original|customize)-central[^"?\s]+\.js',index).group()
parent=(root/central).read_text();frame=re.search(r'(?:screen-frame|customize-screen-frame)[^"?\s]+\.html',parent).group()
html=(root/frame).read_text();script=re.search(r'assets/(?:screen-frame|customize-screen-frame)[^"?\s]+\.js',html).group()
child=patch.frame((root/script).read_text())
assert 'assets/flutter-preview-catalog-filters-75c126348f51/' in parent,'Review newer preview'
backup.mkdir(mode=0o700)
m={'changes':{},'checks':{str(root/p):current(root/p) for p in [central,frame,script]},'staged':{}}
def stage(path,data):
    n=str(len(m['changes']));old=n+'.old' if path.exists() else None
    if old:(backup/old).write_bytes(path.read_bytes())
    (backup/(n+'.new')).write_bytes(data)
    m['changes'][str(path)]={'before':current(path),'after':sha(data),'old':old,'new':n+'.new'}
    if path.suffix=='.php':subprocess.run(['/opt/cpanel/ea-php83/root/usr/bin/php','-l',str(backup/(n+'.new'))],check=True)
def git_source(path):return subprocess.check_output(['git','-c','safe.directory='+str(repo),'-C',str(repo),'show',base+':'+path])
for name in ['BuilderPushAnalytics.php','ConnectedPushAnalytics.php']:
    path=api/'app/Services'/name;assert not path.exists();stage(path,(assets/name).read_bytes())
new='includes/class-mobishop-push-analytics.php';assert not (wp/new).exists();stage(wp/new,(repo/'connectors/woocommerce/source'/new).read_bytes())
for rel in ['app/Services/BuilderPushMetrics.php','app/Services/ConnectedStorePush.php','app/Http/Controllers/Api/V1/StorePushController.php']:
    path=api/rel;stage(path,patch.backend(rel,path.read_text()).encode())
# The installed site carries selective patches on an older release. Preserve its
# version/history; only the complete downloadable package advertises 1.46.116.
for rel in ['includes/class-mobishop.php','includes/class-mobishop-push-service.php','includes/central/kidia-push-admin-bridge.php']:
    path=wp/rel;raw=path.read_bytes();newline='\r\n' if b'\r\n' in raw else '\n';live=raw.decode().replace('\r\n','\n')
    before=git_source('connectors/woocommerce/source/'+rel).decode().replace('\r\n','\n').splitlines(True)
    after=(repo/'connectors/woocommerce/source'/rel).read_text().splitlines(True)
    for group in difflib.SequenceMatcher(None,before,after).get_grouped_opcodes(2):
        a=''.join(before[group[0][1]:group[-1][2]]);b=''.join(after[group[0][3]:group[-1][4]])
        assert live.count(a)==1,'Concurrent connector change: '+rel
        live=live.replace(a,b,1)
    stage(path,live.replace('\n',newline).encode())
new_parent='assets/original-central-push-analytics-'+version+'.js';new_frame='screen-frame-push-analytics-'+version+'.html';new_child='assets/screen-frame-push-analytics-'+version+'.js'
js='assets/push-analytics-'+version+'.js';css='assets/push-analytics-'+version+'.css'
assert html.count('</head>')==1 and html.count('src="'+script)==1
html=html.replace('</head>','<link rel="stylesheet" href="'+css+'"></head>').replace(script,new_child)
tag=r'(<script\b[^>]*\bsrc="'+re.escape(new_child)+r'(?:\?[^" ]*)?"[^>]*>)'
html,count=re.subn(tag,lambda m:'<script src="'+js+'"></script>'+m.group(),html)
assert count==1, 'Expected exactly one frame script tag'
for name,data in {new_parent:parent.replace(frame,new_frame),new_frame:html,new_child:child,js:(assets/'push-analytics.js').read_text(),css:(assets/'push-analytics.css').read_text()}.items():
    path=root/name;assert not path.exists();write(path,data.encode());m['staged'][str(path)]=current(path)
downloads=Path('/home/woomobile/public_html/downloads');release=json.loads((downloads/'connector-release.json').read_text())
assert release['version']=='1.46.115' and current(downloads/'mobi2app-connector.zip')==release['sha256'],'Review newer connector release'
subprocess.run(['python3',str(repo/'tool/build_woocommerce_connector.py')],check=True)
release_bytes=(repo/'build/woocommerce/connector-release.json').read_bytes();release=json.loads(release_bytes);assert release['version']=='1.46.116'
archive=(repo/'build/woocommerce'/release['file']).read_bytes();assert sha(archive)==release['sha256']
versioned=downloads/release['file'];assert not versioned.exists();write(versioned,archive);m['staged'][str(versioned)]=current(versioned)
stage(downloads/'mobi2app-connector.zip',archive);stage(downloads/'connector-release.json',release_bytes)
stage(root/'index.html',index.replace(central,new_parent).encode())
manifest.write_text(json.dumps(m,indent=2))
print(json.dumps({'staged':True,'backup':str(backup),'frame':new_frame}))
