"""Stage outline schema + connector against current files; activate by hash only."""
from pathlib import Path
import hashlib, importlib.util, json, os, re, subprocess, sys, urllib.request, zipfile

commit = sys.argv[1]
assert re.fullmatch(r'[a-f0-9]{40}', commit)
work = Path('/root/catalog-outline-20261027')
sha = lambda data: hashlib.sha256(data).hexdigest()
php = '/opt/cpanel/ea-php83/root/usr/bin/php'

def fetch(name, revision=commit):
    assert '..' not in name.split('/')
    with urllib.request.urlopen(f'https://raw.githubusercontent.com/sayedkhaled205/kidia_store_app/{revision}/{name}', timeout=60) as response:
        return response.read()

if '--activate' in sys.argv:
    record = json.loads((work/'manifest.json').read_text())
    assert record['commit'] == commit
    for item in record['files']:
        assert sha(Path(item['target']).read_bytes()) == item['before'], item['target']
        assert sha((work/item['candidate']).read_bytes()) == item['after']
    for item in record['files']:
        target = Path(item['target']); owner = target.stat()
        temporary = target.with_name(target.name+'.outline-tmp')
        with temporary.open('xb') as handle: handle.write((work/item['candidate']).read_bytes())
        os.chown(temporary, owner.st_uid, owner.st_gid); os.chmod(temporary, owner.st_mode & 0o777)
        temporary.replace(target)
    print(json.dumps({'activated':len(record['files']), 'backup':str(work)}))
    sys.exit()

assert not work.exists(), 'Existing staged work must be reviewed, not overwritten'
work.mkdir(mode=0o700)
record = {'commit':commit, 'files':[]}

def stage(target, data):
    index = len(record['files']); original=target.read_bytes()
    (work/f'original-{index}').write_bytes(original)
    candidate=f'candidate-{index}'+('.php' if target.suffix=='.php' else target.suffix)
    (work/candidate).write_bytes(data)
    if target.suffix=='.php': subprocess.run([php,'-l',str(work/candidate)],check=True)
    record['files'].append({'target':str(target),'before':sha(original),'after':sha(data),'candidate':candidate})

def module(name):
    file=work/name;file.write_bytes(fetch('tool/builder-assets/'+name))
    spec=importlib.util.spec_from_file_location(name,file);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result

schema=Path('/home/woomobile/woomobile-api/app/Services/SavedBuilderNativeDesign.php')
patcher=module('patch-product-outline-schema.py')
patched=patcher.patch(schema.read_text())
assert patcher.patch(patched)==patched
stage(schema,patched.encode())
test=work/'schema-test.php';test.write_bytes(fetch('tool/builder-assets/product-outline-schema-test.php'))
subprocess.run([php,str(test),str(work/record['files'][0]['candidate'])],check=True)

# Apply scoped diffs to the installed merchant connector, preserving live hooks.
reconciler=module('install-discount-connector.py')
baseline='437659cd925d843ba338c87b38028d129f0ffaa4'
plugin=Path('/home/kidiastore/public_html/wp-content/plugins/mobi2app-connector')
names=['includes/class-mobishop-page-layout-store.php','includes/blocks/class-mobishop-product-grid-block.php','includes/blocks/class-mobishop-product-carousel-block.php']
for name in names:
    source='connectors/woocommerce/source/'+name
    target=plugin/name;raw=target.read_bytes()
    changed=reconciler.reconcile(fetch(source,baseline).decode().replace('\r\n','\n'),fetch(source).decode().replace('\r\n','\n'),raw.decode().replace('\r\n','\n'))
    if b'\r\n' in raw: changed=changed.replace('\n','\r\n')
    stage(target,changed.encode())

# Reconstruct the entire canonical download and verify every member against pins.
archive=Path('/home/woomobile/public_html/downloads/mobi2app-connector.zip')
manifest=json.loads(fetch('connectors/woocommerce/source-manifest.json'))
with zipfile.ZipFile(archive) as current:
    files={}
    for name,pin in manifest['files'].items():
        member='mobi2app-connector/'+name
        data=current.read(member) if member in current.namelist() else b''
        if sha(data)!=pin['sha256']:
            data=fetch(pin['source'])
            if pin.get('newline','binary')!='binary': data=data.replace(b'\r\n',b'\n')
            assert sha(data)==pin['source_sha256'],name
            if pin.get('newline')=='crlf':data=data.replace(b'\n',b'\r\n')
        assert sha(data)==pin['sha256'],name
        files[name]=data
package=work/'connector.zip'
with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as out:
    for name,data in sorted(files.items()):
        info=zipfile.ZipInfo('mobi2app-connector/'+name,(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16
        out.writestr(info,data,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
stage(archive,package.read_bytes())
record['connector_version']=manifest['version'];record['connector_sha256']=sha(package.read_bytes())
(work/'manifest.json').write_text(json.dumps(record,indent=2))
print(json.dumps({'staged':len(record['files']),'connector_version':manifest['version'],'connector_sha256':record['connector_sha256'],'backup':str(work)}))
