"""Patch the active builder assets without replacing unrelated editor changes."""
from pathlib import Path
import re
import shutil

b = Path('/home/woomobile/woomobile-api/public/mobishop-builder-v26')
backup = Path('/home/woomobile/kids-ui304-backup')
backup.mkdir(exist_ok=True)
index = b / 'index.html'
html = index.read_text()
parent_name = re.search(r'assets/((?:original|customize)-central[^"?]+\.js)', html).group(1)
parent = b / 'assets' / parent_name
source = parent.read_text()
frame_name = re.search(r'((?:screen-frame|customize-screen-frame)[^"?\s]+\.html)', source).group(1)
frame = b / frame_name
frame_html = frame.read_text()
script_name = re.search(r'assets/((?:screen-frame|customize-screen-frame)[^"?]+\.js)', frame_html).group(1)
script = b / 'assets' / script_name
for p in [index, parent, frame, script]:
    if not (backup / p.name).exists():
        shutil.copy2(p, backup / p.name)
js = script.read_text()
start = js.index('  function updateDestinationWarnings() {')
end = js.index("  root.addEventListener('change', updateDestinationWarnings)", start)
js = js[:start] + '''  function updateDestinationWarnings() {
    // Destinations remain editable in their own controls; no global warning strip.
    root.querySelectorAll('[data-destination-warning]').forEach(notice => notice.remove());
  }
''' + js[end:]
new_script = 'screen-frame-kids-ui304.js'
(b / 'assets' / new_script).write_text(js)
new_frame = 'screen-frame-kids-ui304.html'
(b / new_frame).write_text(frame_html.replace(script_name, new_script))
source = source.replace(frame_name, new_frame)
source = source.replace("const opts = options || {}; opts.credentials = 'include';", "const opts = options || {}; opts.credentials = 'include'; opts.cache = 'no-store';")
source = source.replace("'&settings_only=1'", "'&settings_only=1&_fresh=' + Date.now()")
new_parent = 'original-central-kids-ui304.js'
(b / 'assets' / new_parent).write_text(source)
index.write_text(html.replace(parent_name, new_parent))
# The entry document must revalidate so existing bookmarks receive new assets.
ht = b / '.htaccess'
rules = ht.read_text() if ht.exists() else ''
if '# kids-ui304 entry freshness' not in rules:
    ht.write_text(rules + '\n# kids-ui304 entry freshness\n<IfModule mod_headers.c>\n<Files "index.html">\nHeader always set Cache-Control "no-store, max-age=0"\n</Files>\n</IfModule>\n')
print('KIDS_UI304_READY', parent_name, frame_name)
