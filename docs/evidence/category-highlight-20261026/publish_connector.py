"""Guarded publication of the reviewed shared connector, without store settings.

Only the public download package is updated. Existing installed plugins and the
working Kidia MU adapter are preserved. Run with immutable reviewed Git commits.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import urllib.request
import zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def fetch(commit, path):
    assert re.fullmatch(r'[a-f0-9]{40}', commit)
    assert '..' not in path.split('/')
    url = f'https://raw.githubusercontent.com/sayedkhaled205/kidia_store_app/{commit}/{path}'
    with urllib.request.urlopen(url, timeout=45) as response:
        return response.read()


def publish(base, commit, directory, backup, apply=False):
    old = json.loads(fetch(base, 'connectors/woocommerce/source-manifest.json'))
    new = json.loads(fetch(commit, 'connectors/woocommerce/source-manifest.json'))
    assert old['version'] == '1.46.100' and new['version'] == '1.46.101'
    alias = directory / 'mobi2app-connector.zip'
    release = directory / 'connector-release.json'
    before = {p: p.read_bytes() for p in (alias, release)}
    current = json.loads(before[release])
    assert current['version'] == old['version'], 'Download version changed; review before publication'
    assert digest(before[alias]) == current['sha256'], 'Download and release metadata disagree'
    prefix = 'mobi2app-connector/'
    with zipfile.ZipFile(io.BytesIO(before[alias])) as archive:
        assert len(archive.namelist()) == len(set(archive.namelist())), 'Duplicate archive entries'
        files = {n[len(prefix):]: archive.read(n) for n in archive.namelist() if n.startswith(prefix)}
        assert len(files) == len(archive.namelist())
    assert set(files) == set(old['files']), 'Existing package inventory changed'
    assert all(digest(files[n]) == r['sha256'] for n, r in old['files'].items()), 'Existing package source changed'
    changed = []
    for name, record in new['files'].items():
        if name in files and digest(files[name]) == record['sha256']:
            continue
        data = fetch(commit, record['source'])
        if record['newline'] != 'binary':
            data = data.replace(b'\r\n', b'\n')
        assert digest(data) == record['source_sha256'], name
        if record['newline'] == 'crlf':
            data = data.replace(b'\n', b'\r\n')
        assert digest(data) == record['sha256'], name
        files[name] = data
        changed.append(name)
    assert set(changed) == {'SOURCE-BUILD.txt', 'mobi2app-connector.php', 'readme.txt',
                            'api/class-category-page-endpoint.php', 'includes/class-mobishop-category-page-store.php'}
    assert set(files) == set(new['files'])
    target_name = 'mobi2app-connector-1.46.101.zip'
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo(prefix + name, (2026, 1, 1, 0, 0, 0))
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    payload = buffer.getvalue()
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        assert all(digest(archive.read(prefix+n)) == r['sha256'] for n, r in new['files'].items())
    metadata = dict(slug=new['slug'], version=new['version'], file=target_name,
                    sha256=digest(payload), files=len(files))
    if apply:
        assert not (directory / target_name).exists(), 'Versioned artifact already exists'
        backup.mkdir(parents=True, exist_ok=False)
        for p in before:
            shutil.copy2(p, backup / p.name)
        pending = {directory / target_name: payload, alias: payload,
                   release: (json.dumps(metadata, indent=2)+'\n').encode()}
        staged = {}
        for p, data in pending.items():
            fd, tmp = tempfile.mkstemp(prefix='.shared-connector-', dir=directory)
            with os.fdopen(fd, 'wb') as f:
                f.write(data)
            stat = (p if p.exists() else alias).stat()
            os.chmod(tmp, stat.st_mode & 0o777)
            os.chown(tmp, stat.st_uid, stat.st_gid)
            staged[p] = tmp
        assert all(p.read_bytes() == data for p, data in before.items()), 'Concurrent publication detected'
        for p, tmp in staged.items():
            os.replace(tmp, p)
        assert digest(alias.read_bytes()) == metadata['sha256']
        assert json.loads(release.read_bytes()) == metadata
        (backup / 'publication.json').write_text(json.dumps(dict(metadata, source_commit=commit,
            base_commit=base, changed_files=changed, installed_store_plugins_changed=False), indent=2)+'\n')
    print(json.dumps(dict(metadata, published=apply, all_file_hashes_verified=True), indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', required=True)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--directory', type=Path, default=Path('/home/woomobile/public_html/downloads'))
    parser.add_argument('--backup', type=Path, default=Path('/root/category-highlight-20261026-connector101'))
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    publish(args.base, args.commit, args.directory, args.backup, args.apply)
