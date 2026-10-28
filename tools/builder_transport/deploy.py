"""Hash-guarded WHM deployment; no merchant state, credentials, or theme writes."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, sys

ROOT = Path('/home/woomobile/woomobile-api')
SOURCE = Path(__file__).resolve().parent
BACKUP = Path('/home/woomobile/setup-connection-recovery-backup-20261028')
PHP = '/opt/cpanel/ea-php83/root/usr/bin/php'
EXPECTED = {
    'app/Services/BuilderApplicationState.php': 'a600c393ffe44f9b5ea0c6194facbfef7a9104aed4fa85d628bb18ff9649ff85',
    'app/Http/Controllers/Portal/DashboardController.php': '5cf0461f7851b66364bab4c511483693d251380ac640c713eb765ae78da6ef3a',
}
NEW = 'app/Services/BuilderStoreRequest.php'
digest = lambda raw: hashlib.sha256(raw).hexdigest()

def patched_controller(raw):
    text = raw.decode('utf-8')
    lines = text.splitlines(keepends=True)
    changed = 0
    inside = False
    for index, line in enumerate(lines):
        if 'private function builderStoreData(' in line: inside = True
        if 'public function builderMediaLibrary(' in line: inside = False
        if inside and '$productsResponse = Http::' in line or inside and '$categoriesResponse = Http::' in line:
            assert line.count('->timeout(20)') == 1 and line.rstrip().endswith('->throw();')
            prefix, request = line.split(' = ', 1)
            request = request.strip().removesuffix('->throw();').replace('->timeout(20)', '->withOptions($transportOptions)')
            lines[index] = prefix + ' = app(\\App\\Services\\BuilderStoreRequest::class)->send(fn(array $transportOptions) => ' + request + ', 20)->throw();\n'
            changed += 1
    assert changed == 4, f'Expected four catalog reads, got {changed}'
    return ''.join(lines).encode('utf-8')

def replace(path, data, reference):
    pending = path.with_name(path.name + '.connection-recovery.tmp')
    pending.write_bytes(data)
    shutil.copymode(reference, pending)
    st = reference.stat()
    os.chown(pending, st.st_uid, st.st_gid)
    os.replace(pending, path)

mode = sys.argv[1] if len(sys.argv) > 1 else '--check'
if mode == '--rollback':
    manifest = json.loads((BACKUP/'manifest.json').read_text())
    for relative, checksum in manifest['after'].items():
        assert digest((ROOT/relative).read_bytes()) == checksum, 'Concurrent change: '+relative
    # Restore callers first. Keep the now-unused helper to avoid deleting concurrent code.
    for relative in EXPECTED:
        replace(ROOT/relative, (BACKUP/relative).read_bytes(), ROOT/relative)
    print(json.dumps({'rolled_back': True, 'merchant_settings_changed': False}))
    sys.exit(0)

assert mode in ['--check', '--apply']
original = {relative: (ROOT/relative).read_bytes() for relative in EXPECTED}
for relative, raw in original.items():
    assert digest(raw) == EXPECTED[relative], 'Concurrent change: '+relative
assert not (ROOT/NEW).exists(), 'Transport helper already exists; inspect before proceeding'
pending = {
    NEW: (SOURCE/'backend/BuilderStoreRequest.php').read_bytes(),
    'app/Services/BuilderApplicationState.php': (SOURCE/'backend/BuilderApplicationState.php').read_bytes(),
    'app/Http/Controllers/Portal/DashboardController.php': patched_controller(original['app/Http/Controllers/Portal/DashboardController.php']),
}
for relative, raw in pending.items():
    checkfile = SOURCE/('lint-'+Path(relative).name)
    checkfile.write_bytes(raw)
    subprocess.run([PHP, '-l', str(checkfile)], check=True)
subprocess.run([PHP, str(SOURCE/'test_transport.php')], check=True)
if mode == '--check':
    print(json.dumps({'ready':True, 'files':list(pending), 'merchant_settings_changed':False}))
    sys.exit(0)
BACKUP.mkdir(mode=0o700, exist_ok=False)
for relative, raw in original.items():
    saved = BACKUP/relative
    saved.parent.mkdir(parents=True, exist_ok=True)
    saved.write_bytes(raw)
manifest = {'before':EXPECTED,'after':{r:digest(raw) for r,raw in pending.items()}}
(BACKUP/'manifest.json').write_text(json.dumps(manifest, indent=2))
for relative, raw in pending.items():
    target = ROOT/relative
    if relative in EXPECTED:
        assert digest(target.read_bytes()) == EXPECTED[relative], 'Concurrent change during activation: '+relative
    else:
        assert not target.exists(), 'Concurrent helper creation'
    replace(target, raw, ROOT/'app/Services/BuilderApplicationState.php')
print(json.dumps({'deployed':True,'backup':str(BACKUP),'sha256':manifest['after'],'merchant_settings_changed':False}))
