"""Deploy only reviewed publication services/helper, with hashes and rollback."""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess, sys, urllib.request

commit = sys.argv[1]
assert re.fullmatch(r'[a-f0-9]{40}', commit)
root = Path('/home/woomobile/woomobile-api')
web = root/'public/mobishop-builder-v26'
work = Path('/root/live-publish-expansion-20261026')
work.mkdir(exist_ok=True, mode=0o700)
backup = work/('backup-'+commit[:12])
backup.mkdir(exist_ok=False, mode=0o700)
sha = lambda raw: hashlib.sha256(raw).hexdigest()
php = '/opt/cpanel/ea-php83/root/usr/bin/php'
expected = {
 'LiveAppDesign.php': '89a6c566df5d877f4393c9c05f945cb626fd4aa751a9ee2121234319261fdb6d',
 'LiveAppUiControls.php': 'bf5d41cdf237d8ea85ef1e2a96d39f619c12900faa572aa7c5b1903d77c697b2',
 'live-ui-controls-v1.json': 'cf143149c4fe44cae9ac0e4c1b4a1be96b547b40c872e822d2cce9bdff070c85',
}
def fetch(name):
    with urllib.request.urlopen(f'https://raw.githubusercontent.com/sayedkhaled205/kidia_store_app/{commit}/{name}', timeout=60) as response:
        return response.read()
def replace(target, raw):
    temp = target.with_name(target.name+'.publication.tmp')
    temp.write_bytes(raw)
    shutil.copymode(target, temp)
    os.chown(temp, target.stat().st_uid, target.stat().st_gid)
    os.replace(temp, target)

index = web/'index.html'
old_index = index.read_bytes()
old_helper = web/'assets/page-controls-6a1ecc9a4025.js'
assert sha(old_helper.read_bytes()) == '6a1ecc9a402553f8a9a90f9f00a021bf9be949e5bf49c6023ec1627ef922176e'
assert old_index.count(b'assets/page-controls-6a1ecc9a4025.js') == 1
pending = {}
for name, digest in expected.items():
    target = root/'app/Services'/name
    assert sha(target.read_bytes()) == digest, 'Concurrent server change: '+name
    data = fetch('tools/live_ui_controls/backend/app/Services/'+name)
    (work/name).write_bytes(data)
    if name.endswith('.php'):
        subprocess.run([php, '-l', str(work/name)], check=True)
    pending[name] = data
helper = fetch('tools/live_ui_controls/page-controls.js')
helper_name = 'assets/page-controls-'+sha(helper)[:12]+'.js'
new_index = old_index.replace(b'assets/page-controls-6a1ecc9a4025.js', helper_name.encode())
test = work/'backend-test.php'
test.write_bytes(fetch('tools/live_ui_controls/backend-test.php'))
for name in pending:
    shutil.copy2(root/'app/Services'/name, backup/name)
shutil.copy2(index, backup/'index.html')
changed = []
try:
    for name, data in pending.items():
        target = root/'app/Services'/name
        assert sha(target.read_bytes()) == expected[name], 'Concurrent server change'
        replace(target, data)
        changed.append(name)
    # The test wraps all database mutations, including releases, in a rollback.
    result = subprocess.run([php, str(test)], text=True, capture_output=True)
    print(result.stdout)
    if result.returncode or 'PASS: 36 controls' not in result.stdout or 'All test data rolled back.' not in result.stdout:
        print(result.stderr)
        raise RuntimeError('Backend verification failed')
    target = web/helper_name
    if target.exists():
        assert target.read_bytes() == helper
    else:
        target.write_bytes(helper)
        shutil.copymode(index, target)
        os.chown(target, index.stat().st_uid, index.stat().st_gid)
    assert index.read_bytes() == old_index, 'Builder changed concurrently'
    replace(index, new_index)
except BaseException:
    for name in reversed(changed):
        target = root/'app/Services'/name
        if target.read_bytes() == pending[name]:
            replace(target, (backup/name).read_bytes())
    raise
record = {'source_commit':commit, 'services': {n:sha(d) for n,d in pending.items()},
          'helper':helper_name, 'backup':str(backup), 'database_test':'passed and rolled back'}
(work/'backend-result.json').write_text(json.dumps(record, indent=2))
print(json.dumps(record, indent=2))
