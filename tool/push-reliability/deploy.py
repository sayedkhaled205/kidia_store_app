"""Stage typed FCM errors and narrow connector changes; activate with CAS/rollback."""
from pathlib import Path
import hashlib, json, os, subprocess, sys, tempfile

repo = Path(sys.argv[1]).resolve()
base = '0431fb1dad488dbf032d7a7485cc197259f448b5'
api = Path('/home/woomobile/woomobile-api')
plugin = Path('/home/kidiastore/public_html/wp-content/plugins/mobi2app-connector')
backup = Path('/home/woomobile/push-reliability-20261029-backup')
php = '/opt/cpanel/ea-php83/root/usr/bin/php'
sha = lambda b: hashlib.sha256(b).hexdigest()

def write(path, data, owner):
    temp = path.with_name(path.name + '.push-tmp')
    with temp.open('xb') as f: f.write(data)
    os.chown(temp, owner.st_uid, owner.st_gid)
    os.chmod(temp, 0o644)
    temp.replace(path)

if '--activate' in sys.argv or '--rollback' in sys.argv:
    rollback = '--rollback' in sys.argv
    records = json.loads((backup/'manifest.json').read_text())
    for record in records:
        path = Path(record['path'])
        assert (sha(path.read_bytes()) if path.exists() else None) == record['after' if rollback else 'before'], 'Concurrent change: '+str(path)
    for i, record in enumerate(records):
        path = Path(record['path'])
        if rollback and record['before'] is None:
            # Preserve the harmless unused helper rather than delete a source file.
            continue
        write(path, (backup/(str(i)+('.old' if rollback else '.new'))).read_bytes(), path.stat() if path.exists() else path.parent.stat())
    print(json.dumps({'activated':not rollback,'files':len(records),'backup':str(backup)}))
    sys.exit()

assert not backup.exists(), 'Inspect the previous stage first'
changes = {}
provider = api/'app/Services/Firebase/FirebaseProvisioner.php'
s = provider.read_text()
old = '''        if (!$response->successful()) {
            $this->throwGoogleError(
                $response,
                "fcm_send_failed",'''
new = '''        if (!$response->successful()) {
            if (FcmDeliveryFailure::isUnregistered((array) $response->json("error"))) {
                throw new \\App\\Exceptions\\FirebaseProvisioningException("fcm_token_unregistered", "This device registration has expired.", 410);
            }
            $this->throwGoogleError(
                $response,
                "fcm_send_failed",'''
assert s.count(old) == 1
changes[provider] = s.replace(old,new).encode()
controller = api/'app/Http/Controllers/Api/V1/StoreNotificationServiceController.php'
s = controller.read_text()
old = "        return response()->json(['ok'=>true, ...$provisioner->send($project, $request->validated())]);"
new = '''        try {
            return response()->json(['ok'=>true, ...$provisioner->send($project, $request->validated())]);
        } catch (\\App\\Exceptions\\FirebaseProvisioningException $error) {
            $expired = $error->apiCode === 'fcm_token_unregistered';
            return response()->json(['ok'=>false, 'code'=>$expired ? 'fcm_token_unregistered' : 'fcm_send_failed',
                'message'=>$expired ? 'This device registration has expired.' : 'The notification provider could not accept this request.'],
                $expired ? 410 : 503)->header('Cache-Control','private, no-store');
        }'''
assert s.count(old)==1
changes[controller]=s.replace(old,new).encode()
helper = api/'app/Services/Firebase/FcmDeliveryFailure.php'
assert not helper.exists()
changes[helper]=(repo/'tool/push-reliability/FcmDeliveryFailure.php').read_bytes()

# Apply only the reviewed hunks to the installed plugin, preserving other work.
mapping = {
 'includes/class-mobishop-push-service.php':'connectors/woocommerce/source/includes/class-mobishop-push-service.php',
 'includes/central/store-notifications.php':'connectors/woocommerce/source/includes/central/store-notifications.php',
 'includes/central/kidia-push-actions.php':'connectors/woocommerce/source/includes/central/kidia-push-actions.php',
}
import difflib
with tempfile.TemporaryDirectory() as folder:
    for relative, source in mapping.items():
        old = subprocess.check_output(['git','show',base+':'+source],cwd=repo).decode().replace('\r\n','\n')
        new = (repo/source).read_text()
        patch = ''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/candidate',tofile='b/candidate'))
        candidate = Path(folder)/'candidate'
        candidate.write_text((plugin/relative).read_text())
        subprocess.run(['patch','--batch','--fuzz=0','-p1'],input=patch.encode(),cwd=folder,check=True,stdout=subprocess.PIPE)
        changes[plugin/relative]=candidate.read_bytes()

# Verify the previously published package before replacing the install download.
import zipfile
downloads = Path('/home/woomobile/public_html/downloads')
release = downloads/'connector-release.json'
alias = downloads/'mobi2app-connector.zip'
old_manifest = json.loads(subprocess.check_output(['git','show',base+':connectors/woocommerce/source-manifest.json'],cwd=repo))
metadata = json.loads(release.read_text())
assert metadata['version'] == old_manifest['version'] == '1.46.118'
assert sha(alias.read_bytes()) == metadata['sha256']
with zipfile.ZipFile(alias) as package:
    for name, record in old_manifest['files'].items():
        assert sha(package.read('mobi2app-connector/'+name)) == record['sha256'], name
subprocess.run(['python3',str(repo/'tool/build_woocommerce_connector.py')],check=True,stdout=subprocess.PIPE)
new_metadata=json.loads((repo/'build/woocommerce/connector-release.json').read_text())
archive=(repo/'build/woocommerce'/new_metadata['file']).read_bytes()
assert new_metadata['version']=='1.46.119' and sha(archive)==new_metadata['sha256']
changes[downloads/new_metadata['file']]=archive
changes[alias]=archive
changes[release]=(json.dumps(new_metadata,indent=2)+'\n').encode()

backup.mkdir(mode=0o700)
records=[]
for i,(path,data) in enumerate(changes.items()):
    old=path.read_bytes() if path.exists() else None
    if old is not None: (backup/(str(i)+'.old')).write_bytes(old)
    candidate=backup/(str(i)+'.new');candidate.write_bytes(data)
    if path.suffix == '.php':
        subprocess.run([php,'-l',str(candidate)],check=True,stdout=subprocess.PIPE)
    records.append({'path':str(path),'before':sha(old) if old is not None else None,'after':sha(data)})
(backup/'manifest.json').write_text(json.dumps(records,indent=2))
print(json.dumps({'staged':True,'files':len(records),'backup':str(backup)}))
