"""Carry the canonical logo fix into installations with the earlier MU bridge.

Run on the server with the WordPress document root as the sole argument.
The connector remains the source; unrelated legacy bridge logic is retained.
"""
from pathlib import Path
import shutil
import sys

root = Path(sys.argv[1]).resolve()
source = (root / 'wp-content/plugins/mobi2app-connector/includes/central/kidia-builder-setup-identity.php').read_text()
target = root / 'wp-content/mu-plugins/kidia-builder-setup-identity.php'
if target.exists():
    text = target.read_text()
    marker = '        // Theme application consumes'
    if marker not in text:
        start = source.index(marker)
        end = source.index('        return $identity;', start)
        assert text.count('        return $identity;') == 2
        backup = target.with_suffix('.php.before-kids306')
        if not backup.exists():
            shutil.copy2(target, backup)
        target.write_text(text.replace('        return $identity;', source[start:end] + '        return $identity;', 1))
    print('Legacy Setup bridge has the canonical logo fix.')
