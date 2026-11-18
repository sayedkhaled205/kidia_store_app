"""Stage/live hash-guarded sale-query deployment, retaining each site's current loader."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import urllib.request

SOURCE = 'e83489e3356fb320f41ae0785cbf7a6e4e17782b'
ROOTS = {'staging': '/home/kidiastg/public_html', 'live': '/home/kidiastore/public_html'}
LOADERS = {
    'staging': 'b387b24ffb0f5795946f633537666583151e20bce1d1a26c2b20a1cefaad08f0',
    'live': '1ca7701d42cf7a03da0c395d0a1091c0d27647a6b71fea882707156fc3be2d70',
}
FILES = {
    'api/class-discount-rules-catalogue-query.php': ('0b27261524de35cdf818a41e932f8226637f009de01449c41990995e0e91f220', '0ca521c504c901e522ffa43e39f23a97b89690bc9287d1a64e9aacc4c0cff3bd'),
    'api/class-discount-rules-prices.php': ('d834c3122523fcc565e46fdf262ec609537550ad8306bf3b17e79978c0d1416d', '53bfdd5ca6808fa4fe63f2042144f36b561d46dcb267115cd5b568bc89ec789a'),
}

def digest(data):
    return hashlib.sha256(data).hexdigest() if data is not None else None

def main():
    site, mode = sys.argv[1:]
    assert site in ROOTS and mode in ('check', 'apply')
    root = Path(ROOTS[site]) / 'wp-content/plugins/mobi2app-connector'
    backup = Path('/root/kidia-discount-audit-20261118') / ('sale-query-' + site)
    backup.mkdir(mode=0o700, exist_ok=True)
    loader = root / 'includes/class-mobishop.php'
    old_loader = loader.read_bytes()
    anchor = b"require_once MOBISHOP_PATH . 'api/class-discount-rules-prices.php';"
    addition = b"require_once MOBISHOP_PATH . 'api/class-discount-rules-catalogue-query.php';"
    before_loader = old_loader.replace(b'\n' + addition, b'')
    assert digest(before_loader) == LOADERS[site], 'Current loader changed'
    assert before_loader.count(anchor) == 1 and addition not in before_loader
    after_loader = before_loader.replace(anchor, anchor + b'\n' + addition)
    assert old_loader in (before_loader, after_loader)
    plans = []
    for name, (before, after) in FILES.items():
        target = root / name
        current = target.read_bytes() if target.exists() else None
        assert digest(current) in (before, after), 'Concurrent change: ' + name
        if digest(current) == after:
            continue
        url = 'https://raw.githubusercontent.com/sayedkhaled205/kidia_store_app/' + SOURCE + '/connectors/woocommerce/source/' + name
        data = urllib.request.urlopen(url, timeout=30).read()
        assert digest(data) == after, 'Candidate mismatch'
        plans.append((target, current, data))
    if old_loader != after_loader:
        plans.append((loader, old_loader, after_loader))  # Enable only after dependencies are present.
    for target, old, data in plans:
        candidate = backup / (target.name + '.candidate')
        candidate.write_bytes(data)
        subprocess.run(['/opt/cpanel/ea-php83/root/usr/bin/php', '-l', str(candidate)], check=True)
        original = backup / (target.name + '.before')
        if old is not None:
            if original.exists(): assert original.read_bytes() == old
            else:
                original.write_bytes(old)
                original.chmod(0o600)
    if mode == 'apply':
        for target, old, _ in plans:
            assert (target.read_bytes() if target.exists() else None) == old, 'Concurrent change'
        for target, _, data in plans:
            stat = target.stat() if target.exists() else loader.stat()
            temp = target.with_suffix('.discount-query-tmp')
            with temp.open('xb') as stream: stream.write(data)
            os.chown(temp, stat.st_uid, stat.st_gid)
            temp.chmod(stat.st_mode & 0o777)
            temp.replace(target)
            assert target.read_bytes() == data
    print('SALE_QUERY_DEPLOY ' + json.dumps({'site': site, 'mode': mode, 'files': {str(p.relative_to(root)): digest(d) for p, _, d in plans}}))

if __name__ == '__main__': main()
