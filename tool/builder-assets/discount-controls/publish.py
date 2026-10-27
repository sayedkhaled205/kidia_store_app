"""Publish offer controls into the CURRENT builder, retaining all other edits."""
from pathlib import Path
import hashlib
import json
import os
import re
import sys


def once(text, before, after):
    assert text.count(before) == 1, 'Current builder anchor changed: ' + before[:80]
    return text.replace(before, after, 1)


def patch(commerce):
    if 'const tableScroll =' not in commerce:
        commerce = once(commerce, '      root.replaceChildren(...fragment.childNodes);',
            "      const tableScroll = Array.from(root.querySelectorAll('.mobishop-data-table-wrap'), table => table.scrollLeft);\n"
            "      root.replaceChildren(...fragment.childNodes);")
        commerce = once(commerce, '      wire();',
            "      wire();\n      root.querySelectorAll('.mobishop-data-table-wrap').forEach((table,index) => { table.scrollLeft = tableScroll[index] || 0; });")
    listener = ("  document.addEventListener('mobishop:discount-saved', () => {\n"
        "    if (root && query.store_tab === 'discounts') load();\n"
        "  });\n")
    commerce = commerce.replace(listener, '')
    return once(commerce, '  function start() {', listener + '  function start() {')


def strip_existing_controls(frame):
    frame = re.sub(r'<link rel="stylesheet" href="assets/discount-rule-controls-[a-f0-9]+\.css">\n?', '', frame)
    return re.sub(r'<script src="assets/discount-rule-controls-[a-f0-9]+\.js"></script>\n?', '', frame)


def main():
    root = Path(sys.argv[1]).resolve()
    source = Path(__file__).parent
    sha = lambda data: hashlib.sha256(data).hexdigest()
    version = sha(b''.join((source/name).read_bytes() for name in
        ['publish.py','discount-rule-controls.js','discount-rule-controls.css']))[:12]
    backup = root.parent / ('discount-controls-backup-' + version)
    review = 'index-discount-controls-' + version + '-review.html'
    owner = (root/'index.html').stat()

    def write(name, data):
        target = root/name
        assert root in target.resolve().parents
        temp = target.with_name(target.name + '.controls-tmp')
        with temp.open('xb') as f: f.write(data)
        if hasattr(os, 'chown'): os.chown(temp, owner.st_uid, owner.st_gid)
        os.chmod(temp, 0o644)
        temp.replace(target)

    if '--activate' in sys.argv:
        record = json.loads((backup/'manifest.json').read_text())
        for name, digest in {**record['originals'], **record['published']}.items():
            assert sha((root/name).read_bytes()) == digest, 'Changed since review: ' + name
        write('index.html', (root/review).read_bytes())
        print(json.dumps({'activated':True, 'backup':str(backup)}))
        return

    index = (root/'index.html').read_text(encoding='utf-8')
    central_names = re.findall(r'src="(assets/original-central[^"?]+\.js)(?:\?[^"]*)?"', index)
    assert len(central_names) == 1
    central_name = central_names[0]
    central = (root/central_name).read_text(encoding='utf-8')
    frames = set(re.findall(r"(screen-frame[^'\"?]+\.html)\?connected=1", central))
    assert len(frames) == 1
    frame_name = frames.pop()
    frame = (root/frame_name).read_text(encoding='utf-8')
    commerce_names = re.findall(r'src="(assets/store-data-live[^"?]+\.js)(?:\?[^"]*)?"', frame)
    assert len(commerce_names) == 1
    commerce_name = commerce_names[0]
    commerce = patch((root/commerce_name).read_text(encoding='utf-8'))
    new_central = 'assets/original-central-offers-' + version + '.js'
    new_commerce = 'assets/store-data-live-offers-' + version + '.js'
    new_frame = 'screen-frame-offers-' + version + '.html'
    controls = 'assets/discount-rule-controls-' + version
    index = index.replace(central_name, new_central)
    central = central.replace(frame_name, new_frame)
    frame = frame.replace(commerce_name, new_commerce)
    frame = strip_existing_controls(frame)
    frame = once(frame, '</head>', '<link rel="stylesheet" href="' + controls + '.css">\n</head>')
    frame = once(frame, '</body>', '<script src="' + controls + '.js"></script>\n</body>')
    changes = {new_central:central.encode(),new_commerce:commerce.encode(),new_frame:frame.encode(),review:index.encode(),
        controls+'.js':(source/'discount-rule-controls.js').read_bytes(), controls+'.css':(source/'discount-rule-controls.css').read_bytes()}
    originals = {name:(root/name).read_bytes() for name in ['index.html',central_name,frame_name,commerce_name]}
    assert not backup.exists(), 'Existing stage must be reviewed first'
    backup.mkdir(mode=0o700)
    for name, data in originals.items():
        target=backup/name; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
    for name, data in changes.items():
        assert not (root/name).exists()
        write(name,data)
    (backup/'manifest.json').write_text(json.dumps({'originals':{k:sha(v) for k,v in originals.items()},
        'published':{k:sha(v) for k,v in changes.items()}, 'review':review},indent=2))
    print(json.dumps({'review_ready':True,'review':review,'backup':str(backup)}))


if __name__ == '__main__': main()
