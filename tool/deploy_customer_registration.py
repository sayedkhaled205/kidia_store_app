"""Stage/activate the reviewed native-auth fix, preserving concurrent store work."""
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

BASE = '534c9eee92aabe3a87e19f5fdaad4e94e2344ece'
FILES = {'api/class-native-customer-auth-endpoint.php', 'mobi2app-connector.php', 'readme.txt', 'SOURCE-BUILD.txt'}
LIVE_FILES = {'api/class-native-customer-auth-endpoint.php'}
PLUGIN = Path('/home/kidiastore/public_html/wp-content/plugins/mobi2app-connector')
DOWNLOADS = Path('/home/woomobile/public_html/downloads')
BACKUP = Path('/home/woomobile/customer-registration-20261101-backup')
PHP = '/opt/cpanel/ea-php83/root/usr/bin/php'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def fetch(commit, path):
    assert re.fullmatch(r'[a-f0-9]{40}', commit)
    with urllib.request.urlopen(f'https://raw.githubusercontent.com/sayedkhaled205/kidia_store_app/{commit}/{path}', timeout=45) as response:
        return response.read()


def digest(path):
    return sha(path.read_bytes()) if path.exists() else None


def write(path, data):
    owner = (path if path.exists() else path.parent).stat()
    fd, temporary = tempfile.mkstemp(prefix='.auth-registration-', dir=path.parent)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(data)
    os.chown(temporary, owner.st_uid, owner.st_gid)
    os.chmod(temporary, 0o644)
    os.replace(temporary, path)


def stage(commit):
    assert not BACKUP.exists(), 'Review the existing staged deployment first'
    old = json.loads(fetch(BASE, 'connectors/woocommerce/source-manifest.json'))
    new = json.loads(fetch(commit, 'connectors/woocommerce/source-manifest.json'))
    assert old['version'] == '1.46.120' and new['version'] == '1.46.121'
    assert set(old['files']) == set(new['files'])
    changed = {name for name in old['files'] if old['files'][name]['sha256'] != new['files'][name]['sha256']}
    assert changed == FILES, 'Unexpected connector changes'
    alias = DOWNLOADS / 'mobi2app-connector.zip'
    release = DOWNLOADS / 'connector-release.json'
    metadata = json.loads(release.read_bytes())
    before = {p: p.read_bytes() for p in (alias, release)}
    assert metadata['version'] == old['version'] and sha(before[alias]) == metadata['sha256']
    prefix = 'mobi2app-connector/'
    with zipfile.ZipFile(io.BytesIO(before[alias])) as archive:
        assert len(archive.namelist()) == len(set(archive.namelist()))
        files = {n[len(prefix):]: archive.read(n) for n in archive.namelist() if n.startswith(prefix)}
        assert len(files) == len(archive.namelist()) and set(files) == set(old['files'])
    assert all(sha(files[n]) == r['sha256'] for n, r in old['files'].items()), 'Public package changed'
    pending = {}
    for name in sorted(FILES):
        path = PLUGIN / name
        if name in LIVE_FILES:
            before[path] = path.read_bytes()
            assert sha(before[path]) == old['files'][name]['sha256'], 'Installed file changed: ' + name
        record = new['files'][name]
        data = fetch(commit, record['source']).replace(b'\r\n', b'\n')
        assert sha(data) == record['source_sha256']
        if record['newline'] == 'crlf':
            data = data.replace(b'\n', b'\r\n')
        assert sha(data) == record['sha256']
        files[name] = data
        if name in LIVE_FILES:
            # Store metadata still labels a mixed older installation. This scoped
            # hotfix must not relabel it or overwrite unrelated live changes.
            pending[path] = data
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo(prefix + name, (2026, 1, 1, 0, 0, 0))
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    archive_bytes = buffer.getvalue()
    versioned = DOWNLOADS / 'mobi2app-connector-1.46.121.zip'
    assert not versioned.exists()
    pending[versioned] = archive_bytes
    pending[alias] = archive_bytes
    metadata = dict(slug=new['slug'], version=new['version'], file=versioned.name, sha256=sha(archive_bytes), files=len(files))
    pending[release] = (json.dumps(metadata, indent=2) + '\n').encode()
    BACKUP.mkdir(mode=0o700)
    manifest = {'commit': commit, 'metadata': metadata, 'installed_files': sorted(LIVE_FILES), 'changes': {}}
    for path, data in pending.items():
        number = str(len(manifest['changes']))
        if path in before:
            (BACKUP / (number + '.old')).write_bytes(before[path])
        (BACKUP / (number + '.new')).write_bytes(data)
        manifest['changes'][str(path)] = {'before': sha(before[path]) if path in before else None, 'after': sha(data), 'number': number}
        if path.suffix == '.php':
            subprocess.run([PHP, '-l', str(BACKUP / (number + '.new'))], check=True)
    (BACKUP / 'manifest.json').write_text(json.dumps(manifest, indent=2))
    print(json.dumps({'staged': True, 'backup': str(BACKUP), **metadata}))


def activate(rollback=False):
    manifest = json.loads((BACKUP / 'manifest.json').read_text())
    for name, item in manifest['changes'].items():
        assert digest(Path(name)) in (item['before'], item['after']), 'Concurrent change: ' + name
        data = BACKUP / (item['number'] + ('.old' if rollback else '.new'))
        if not rollback or item['before'] is not None:
            assert sha(data.read_bytes()) == item['before' if rollback else 'after']
    for name, item in manifest['changes'].items():
        if rollback and item['before'] is None:
            # Retain immutable versioned artifact; restore only active files.
            continue
        desired = item['before' if rollback else 'after']
        current = digest(Path(name))
        if current == desired:
            continue
        assert current == item['after' if rollback else 'before'], 'Concurrent change: ' + name
        write(Path(name), (BACKUP / (item['number'] + ('.old' if rollback else '.new'))).read_bytes())
        assert digest(Path(name)) == desired, 'Publication verification failed: ' + name
    print(json.dumps({'activated': not rollback, 'rollback': rollback, **manifest['metadata']}))


if __name__ == '__main__':
    if sys.argv[1] in ('--activate', '--rollback'):
        activate(sys.argv[1] == '--rollback')
    else:
        stage(sys.argv[1])
