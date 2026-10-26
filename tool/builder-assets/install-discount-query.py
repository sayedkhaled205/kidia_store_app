"""Extend only the existing private merchant query allowlists for FlyCart rules."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys


def patch(source):
    changes = {
        'nullable|in:all,active,expired,scheduled,draft': 'nullable|in:all,active,expired,scheduled,draft,disabled,exhausted',
        'nullable|in:all,percent,fixed_cart,fixed_product': 'nullable|in:all,percent,fixed_cart,fixed_product,wdr_simple_discount,wdr_cart_discount,wdr_bulk_discount,wdr_set_discount,wdr_buy_x_get_x_discount,wdr_buy_x_get_y_discount,wdr_free_shipping',
        'nullable|in:all,individual,product,category': 'nullable|in:all,individual,product,category,rules',
    }
    for before, after in changes.items():
        assert source.count(before+"'") == 1, 'Unexpected current query allowlist'
        source=source.replace(before+"'",after+"'",1)
    return source


if __name__ == '__main__':
    target,backup=map(Path,sys.argv[1:3])
    assert target.name=='StoreDataController.php'
    sha=lambda b:hashlib.sha256(b).hexdigest()
    if '--activate' in sys.argv:
        record=json.loads((backup/'manifest.json').read_text())
        assert sha(target.read_bytes())==record['original'], 'Concurrent controller change'
        content=(backup/'candidate.php').read_bytes()
        assert sha(content)==record['candidate']
        owner=target.stat();temp=target.with_suffix('.discounts-tmp')
        with temp.open('xb') as handle:handle.write(content)
        os.chown(temp,owner.st_uid,owner.st_gid);os.chmod(temp,owner.st_mode & 0o777);temp.replace(target)
        print('Discount query allowlists activated')
    else:
        assert not backup.exists()
        backup.mkdir(mode=0o700,parents=True)
        original=target.read_bytes();candidate=patch(original.decode()).encode()
        (backup/'original.php').write_bytes(original);(backup/'candidate.php').write_bytes(candidate)
        subprocess.run(['/opt/cpanel/ea-php83/root/usr/bin/php','-l',str(backup/'candidate.php')],check=True)
        (backup/'manifest.json').write_text(json.dumps({'original':sha(original),'candidate':sha(candidate)},indent=2))
        print('Three read-only filter allowlists staged; authorization unchanged')
