"""Hash-guarded, atomic deployment of the two reviewed discount repairs."""
from pathlib import Path
import hashlib
import os
import subprocess
import sys
import urllib.request

SHA = '8f6ea2098f55dad0a794be04c60ffc5c0f32e7bc'
ROOTS = {'staging': '/home/kidiastg/public_html', 'live': '/home/kidiastore/public_html'}
FILES = {
    'includes/class-mobishop-coupon-channel.php': (
        '6f46113fae14f0af379378c62d47d5b8f9d1f5beaaae724dc9d626a613e82c8a',
        'c8387c0fd4e542f60c25bad609bddd77815e4192028e5814801b715d7b2d88cf'),
    'api/class-discount-rules-prices.php': (
        '9a93c49c7efdcbda6831952485750ce1c2b4f93a4a46f0dc5738aeaa55839c40',
        'd834c3122523fcc565e46fdf262ec609537550ad8306bf3b17e79978c0d1416d'),
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    site, mode = sys.argv[1:]
    assert site in ROOTS and mode in ('check', 'apply')
    root = Path(ROOTS[site]) / 'wp-content/plugins/mobi2app-connector'
    backup = Path('/root/kidia-discount-audit-20261118') / ('deploy-' + site)
    backup.mkdir(mode=0o700, exist_ok=True)
    changes = []
    for name, (before, after) in FILES.items():
        target = root / name
        old = target.read_bytes()
        current = digest(old)
        assert current in (before, after), 'Live source changed: ' + name + ' ' + current
        if current == after:
            print('ALREADY', site, name, after)
            continue
        url = 'https://raw.githubusercontent.com/sayedkhaled205/kidia_store_app/' + SHA + '/connectors/woocommerce/source/' + name
        data = urllib.request.urlopen(url, timeout=30).read()
        assert digest(data) == after, 'Candidate hash mismatch: ' + name
        candidate = backup / (target.name + '.candidate')
        candidate.write_bytes(data)
        subprocess.run(['/opt/cpanel/ea-php83/root/usr/bin/php', '-l', str(candidate)], check=True)
        original = backup / (target.name + '.before')
        if original.exists():
            assert original.read_bytes() == old, 'Backup differs'
        else:
            original.write_bytes(old)
            original.chmod(0o600)
        changes.append((target, old, data))
        print('READY', site, name, after)
    if mode == 'apply':
        # Check the entire set before the first replacement.
        for target, old, _ in changes:
            assert target.read_bytes() == old, 'Concurrent change'
        for target, _, data in changes:
            stat = target.stat()
            temp = target.with_suffix(target.suffix + '.discount-tmp')
            with temp.open('xb') as stream:
                stream.write(data)
            os.chown(temp, stat.st_uid, stat.st_gid)
            temp.chmod(stat.st_mode & 0o777)
            temp.replace(target)
            assert digest(target.read_bytes()) == digest(data)
            print('APPLIED', site, target.name)


if __name__ == '__main__':
    main()
