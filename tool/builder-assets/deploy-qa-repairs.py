"""Publish reviewed preview navigation and bounded push reports with CAS rollback."""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess, sys
repo=Path(sys.argv[1]).resolve(); assets=repo/'tool/builder-assets'
api=Path('/home/woomobile/woomobile-api'); root=api/'public/mobishop-builder-v26'
wp=Path('/home/kidiastore/public_html/wp-content/plugins/mobi2app-connector')
preview=repo/'mobishop/admin/flutter-preview'
base='c8c23e5b64091b25b2d5470fd4b430ba0b1e0782'
sha=lambda data:hashlib.sha256(data).hexdigest()
version=sha((preview/'main.dart.js').read_bytes()+(assets/'push-analytics.js').read_bytes())[:12]
backup=Path('/home/woomobile/qa-repairs-backup-'+version); manifest=backup/'manifest.json'
def current(path):return sha(path.read_bytes()) if path.exists() else None
def write(path,data):
    owner=(path if path.exists() else path.parent).stat(); tmp=path.with_name(path.name+'.qa-tmp')
    with tmp.open('xb') as stream:stream.write(data)
    os.chown(tmp,owner.st_uid,owner.st_gid);os.chmod(tmp,0o644);tmp.replace(path)
if '--activate' in sys.argv or '--rollback' in sys.argv:
    m=json.loads(manifest.read_text()); rollback='--rollback' in sys.argv
    for name,item in m['changes'].items():assert current(Path(name))==item['after' if rollback else 'before'],'Concurrent change: '+name
    if not rollback:
        for name,digest in {**m['checks'],**m['staged']}.items():assert current(Path(name))==digest,'Concurrent dependency: '+name
    for name,item in m['changes'].items():write(Path(name),(backup/item['old' if rollback else 'new']).read_bytes())
    print(json.dumps({'activated':not rollback,'backup':str(backup),'bundle':m['bundle']}));sys.exit()
assert not backup.exists(),'Review existing stage'
php='/opt/cpanel/ea-php83/root/usr/bin/php'
for test in ['connectors/woocommerce/tests/push-analytics-test.php','tool/builder-assets/push-analytics-contract.php']:
    subprocess.run([php,str(repo/test)],check=True)
index=(root/'index.html').read_text(); central=re.search(r'assets/original-central[^"?\s]+\.js',index).group()
parent=(root/central).read_text(); frame=re.search(r'screen-frame[^"?\s]+\.html',parent).group()
html=(root/frame).read_text(); script=re.search(r'assets/screen-frame[^"?\s]+\.js',html).group(); child=(root/script).read_text()
old_bundle=re.search(r'assets/flutter-preview-[\w-]+/',parent).group()
assert old_bundle=='assets/flutter-preview-live-controls112-9c9c7df92f38/','Review newer preview'
assert '<base href="./">' in (preview/'index.html').read_text()
assert '__mobishopStartFlutterPreview' in (preview/'flutter_bootstrap.js').read_text()
changes={}
for live,source in [(api/'app/Services/BuilderPushAnalytics.php','tool/builder-assets/BuilderPushAnalytics.php'),(api/'app/Services/ConnectedPushAnalytics.php','tool/builder-assets/ConnectedPushAnalytics.php'),(wp/'includes/class-mobishop-push-analytics.php','connectors/woocommerce/source/includes/class-mobishop-push-analytics.php')]:
    before=subprocess.check_output(['git','-c','safe.directory='+str(repo),'-C',str(repo),'show',base+':'+source]).decode().replace('\r\n','\n')
    assert live.read_text()==before,'Concurrent source change: '+str(live)
    changes[live]=(repo/source).read_bytes()
downloads=Path('/home/woomobile/public_html/downloads'); release=json.loads((downloads/'connector-release.json').read_text())
assert release['version']=='1.46.116' and current(downloads/'mobi2app-connector.zip')==release['sha256'],'Review connector download drift'
subprocess.run(['python3',str(repo/'tool/build_woocommerce_connector.py')],check=True)
release_bytes=(repo/'build/woocommerce/connector-release.json').read_bytes(); release=json.loads(release_bytes)
assert release['version']=='1.46.117'
archive=(repo/'build/woocommerce'/release['file']).read_bytes();assert sha(archive)==release['sha256']
backup.mkdir(mode=0o700);bundle='assets/flutter-preview-qa-'+version+'/'
m={'bundle':bundle,'checks':{str(root/p):current(root/p) for p in [central,frame,script]},'staged':{},'changes':{}}
owner=(root/'index.html').stat();shutil.copytree(preview,root/bundle)
for p in [root/bundle,*(root/bundle).rglob('*')]:
    os.chown(p,owner.st_uid,owner.st_gid);os.chmod(p,0o755 if p.is_dir() else 0o644)
    if p.is_file():m['staged'][str(p)]=current(p)
new_parent='assets/original-central-qa-'+version+'.js'; new_frame='screen-frame-qa-'+version+'.html'; new_child='assets/screen-frame-qa-'+version+'.js'
new_report='assets/push-analytics-qa-'+version+'.js'
html,n=re.subn(r'assets/push-analytics-[a-f0-9]+\.js',new_report,html);assert n==1,'Review reporting helper reference'
immutable={root/new_parent:parent.replace(old_bundle,bundle).replace(frame,new_frame).encode(),root/new_frame:html.replace(script,new_child).encode(),root/new_child:child.replace(old_bundle,bundle).encode(),root/new_report:(assets/'push-analytics.js').read_bytes(),downloads/release['file']:archive}
for path,data in immutable.items():
    assert not path.exists(),'Immutable asset exists';write(path,data);m['staged'][str(path)]=current(path)
changes[downloads/'mobi2app-connector.zip']=archive;changes[downloads/'connector-release.json']=release_bytes
changes[root/'index.html']=index.replace(central,new_parent).encode()
for path,data in changes.items():
    n=str(len(m['changes']));(backup/(n+'.old')).write_bytes(path.read_bytes());(backup/(n+'.new')).write_bytes(data)
    m['changes'][str(path)]={'old':n+'.old','new':n+'.new','before':current(path),'after':sha(data)}
    if path.suffix=='.php':subprocess.run([php,'-l',str(backup/(n+'.new'))],check=True)
manifest.write_text(json.dumps(m,indent=2));print(json.dumps({'staged':True,'backup':str(backup),'bundle':bundle}))
