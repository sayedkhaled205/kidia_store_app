"""Stage/activate the narrow URL-validation fix without replacing other backend work."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys

target = Path(sys.argv[1]).resolve()
expected = sys.argv[2]
php = sys.argv[3]
backup = target.parent / '.build-retry-url-20261101'
digest = lambda data: hashlib.sha256(data).hexdigest()


def patch(source):
    marker = '    private static function publicDesign('
    assert source.count(marker) == 1, 'Validation method changed'
    prefix, body = source.split(marker)
    old = '                if (filter_var($value, FILTER_VALIDATE_URL) === false || !is_array($parts)'
    assert body.count(old) == 1, 'URL guard changed'
    new = (
        '                // Public media paths may contain Arabic or other UTF-8 characters.\n'
        "                $validationUrl = preg_replace_callback('/[\\x80-\\xFF]/', static fn (array $match): string => rawurlencode($match[0]), $value);\n"
        "                if (preg_match('//u', $value) !== 1 || filter_var($validationUrl, FILTER_VALIDATE_URL) === false || !is_array($parts)"
    )
    return prefix + marker + body.replace(old, new, 1)


if '--activate' in sys.argv or '--rollback' in sys.argv:
    record = json.loads((backup / 'manifest.json').read_text())
    old = (backup / 'original.php').read_bytes()
    new = (backup / 'candidate.php').read_bytes()
    assert digest(old) == record['before'] == expected
    assert digest(new) == record['after']
    current = digest(target.read_bytes())
    assert current in (record['before'], record['after']), 'Concurrent backend edit; reconcile first'
    data = old if '--rollback' in sys.argv else new
    if current != digest(data):
        temp = target.with_name(target.name + '.retry-tmp')
        stat = target.stat()
        with temp.open('xb') as f:
            f.write(data)
        os.chown(temp, stat.st_uid, stat.st_gid)
        os.chmod(temp, stat.st_mode & 0o777)
        subprocess.run([php, '-l', str(temp)], check=True, capture_output=True)
        temp.replace(target)
    print(json.dumps({'activated': '--activate' in sys.argv, 'sha256': digest(data), 'backup': str(backup)}))
else:
    original = target.read_bytes()
    assert digest(original) == expected, 'Backend changed; reconcile first'
    candidate = patch(original.decode()).encode()
    assert candidate != original
    backup.mkdir(mode=0o700)
    (backup / 'original.php').write_bytes(original)
    (backup / 'candidate.php').write_bytes(candidate)
    subprocess.run([php, '-l', str(backup / 'candidate.php')], check=True)
    (backup / 'manifest.json').write_text(json.dumps({'before': expected, 'after': digest(candidate)}))
    print(json.dumps({'candidate': str(backup / 'candidate.php'), 'sha256': digest(candidate)}))
