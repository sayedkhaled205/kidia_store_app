"""Compare the committed preview with a fresh build without platform noise.

Dart2JS symbol names and Flutter's build ID are not reproducible across paths.
All other assets remain byte-checked, with narrow normalization for license
block ordering and the shell's optional blank line before its startup wrapper.
No generated files or committed assets are changed by this verifier.
"""
from collections import Counter
from pathlib import Path
import argparse
import re
import subprocess

PREFIX = 'mobishop/admin/flutter-preview/'
LICENSE_SEPARATOR = '\n' + '-' * 80 + '\n'


def comparable(name, content):
    if name == 'assets/NOTICES':
        # License discovery order differs between Windows and Linux. Retain
        # every package name, complete license text and duplicate count.
        text = content.decode('utf-8').replace('\r\n', '\n')
        return Counter(text.split(LICENSE_SEPARATOR))
    if name == 'flutter_bootstrap.js':
        text = content.decode('utf-8').replace('\r\n', '\n')
        return re.sub(r'\n\n+(?=window\.__mobishopStartFlutterPreview=function\(\)\{)', '\n', text)
    return content


def difference(name, committed, built):
    if name == 'main.dart.js':
        return None if built.strip() else 'empty JavaScript entrypoint'
    if name == '.last_build_id':
        return None if re.fullmatch(rb'[a-f0-9]{32}', built.strip()) else 'invalid generated build ID'
    return None if comparable(name, committed) == comparable(name, built) else 'asset contents differ'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--built', type=Path, default=Path(PREFIX))
    args = parser.parse_args()
    paths = subprocess.check_output(['git', 'ls-files', '-z', '--', PREFIX]).decode().split('\0')
    failures, count = [], 0
    for path in filter(None, paths):
        name = path.removeprefix(PREFIX)
        target = args.built / name
        if not target.is_file():
            failures.append(f'{name}: missing asset')
            continue
        committed = subprocess.check_output(['git', 'show', f'HEAD:{path}'])
        error = difference(name, committed, target.read_bytes())
        count += 1
        if error:
            failures.append(f'{name}: {error}')
    for error in failures:
        print(error)
    print(f'Checked {count} preview files; {len(failures)} differences. Run node --check on main.dart.js separately.')
    return 1 if failures or not count else 0


if __name__ == '__main__':
    raise SystemExit(main())
