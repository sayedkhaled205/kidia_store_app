"""Install page controls into an existing deployed Builder, preserving its code.

Usage: python integrate-builder.py /path/to/public/mobishop-builder-v26
The caller must inspect and approve deployment to the intended Builder first.
"""
from pathlib import Path
import datetime
import hashlib
import os
import re
import shutil
import sys

root = Path(sys.argv[1]).resolve()
index = root / 'index.html'
original = index.read_text(encoding='utf-8')
match = re.search(r'<script src="(assets/original-central-[^"?]+\.js)(?:\?[^"\n]*)?"', original)
assert match, 'Active central Builder script not found'
source = root / match[1]
code = source.read_text(encoding='utf-8')
original_code = code
needle = 'else result=await save(request.screen,event.data.state);'
replacement = """else {
          if (['home-builder','account-builder','checkout-builder'].includes(request.screen)) {
            if (!window.MobiShopPageControls) throw new Error('Page settings could not load. Refresh the builder before saving.');
            await window.MobiShopPageControls.save(sender);
          }
          result=await save(request.screen,event.data.state);
        }"""
if 'await window.MobiShopPageControls.save(sender);' not in code:
    assert code.count(needle) == 1, 'Builder save path changed; review before integration'
    code = code.replace(needle, replacement)
controls = Path(__file__).with_name('page-controls.js').read_bytes()
if 'MobiShopPageControls.decoratePreview(packet)' not in code:
    needle = 'mobileFrame.contentWindow.postMessage(JSON.stringify(packet), location.origin);'
    assert code.count(needle) == 1, 'Preview dispatch changed; review before integration'
    code = code.replace(needle, 'mobileFrame.contentWindow.postMessage(JSON.stringify(window.MobiShopPageControls ? window.MobiShopPageControls.decoratePreview(packet) : packet), location.origin);')
    needle = 'function sendMobilePreview(forceNavigation = false) {'
    assert code.count(needle) == 1, 'Preview refresh changed; review before integration'
    code = code.replace(needle, "window.addEventListener('mobishop:page-controls-preview', () => sendMobilePreview());\n  " + needle)
central_name = 'assets/original-central-page-controls-' + hashlib.sha256(code.encode()).hexdigest()[:12] + '.js'
controls_name = 'assets/page-controls-' + hashlib.sha256(controls).hexdigest()[:12] + '.js'
updated = original.replace(match[1], central_name)
old_tag = r'<script src="assets/(?:live-ui-controls-20261025|page-controls-[a-f0-9]+)\.js[^"\n]*"></script>'
assert len(re.findall(old_tag, updated)) == 1, 'Controls include missing or duplicated'
updated = re.sub(old_tag, '<script src="' + controls_name + '"></script>', updated)
backup = root / ('index.before-page-controls-' + datetime.datetime.now().strftime('%Y%m%d%H%M%S') + '.html')
shutil.copy2(index, backup)
for name, raw in [(central_name, code.encode()), (controls_name, controls)]:
    target = root / name
    if target.exists():
        assert target.read_bytes() == raw, 'Versioned asset collision'
    else:
        target.write_bytes(raw)
        shutil.copymode(index, target)
        if hasattr(os, 'chown'): os.chown(target, index.stat().st_uid, index.stat().st_gid)
assert index.read_text(encoding='utf-8') == original, 'Builder changed concurrently'
assert source.read_text(encoding='utf-8') == original_code, 'Builder script changed concurrently'
temp = root / 'index.inline-controls.tmp'
temp.write_text(updated, encoding='utf-8')
shutil.copymode(index, temp)
if hasattr(os, 'chown'): os.chown(temp, index.stat().st_uid, index.stat().st_gid)
os.replace(temp, index)
print('Page controls integrated; previous index: ' + str(backup))
