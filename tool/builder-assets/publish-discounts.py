"""Add a Discounts workspace using the existing authenticated commerce view.

Stage against the CURRENT builder. Activate only if every original is unchanged.
No store settings, rules or customer data are modified.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import sys


def replace_once(text, before, after):
    assert text.count(before) == 1, 'Unexpected current builder anchor: ' + before[:80]
    return text.replace(before, after, 1)


def patch(index, central, frame, commerce, version):
    index = replace_once(index,
        '<a href="#store-data" data-screen="store-data">',
        '<a href="#discounts" data-screen="discounts"><span class="dashicons dashicons-tickets-alt"></span><span>Discounts</span></a>\n        <a href="#store-data" data-screen="store-data">')
    central = replace_once(central,
        "screen = next === 'themes' ? 'saved-themes' : next;",
        "screen = next === 'themes' ? 'saved-themes' : next === 'discounts' ? 'store-data' : next;")
    central = replace_once(central,
        "if (frame.dataset.screen === screen) {",
        "if (frame.dataset.screen === screen) {\n      if (screen === 'store-data') frame.contentWindow.postMessage({type:'kidia:commerce-tab',tab:next === 'discounts' ? 'discounts' : 'products'}, location.origin);")
    # A new iframe receives its initial tab before the first live-data request.
    anchor = "encodeURIComponent(screen);"
    central = replace_once(central, anchor,
        "encodeURIComponent(screen) + (next === 'discounts' ? '&store_tab=discounts' : '');")
    commerce = replace_once(commerce,
        "event.preventDefault(); query = readForm(form); load();",
        "event.preventDefault(); query = readForm(form); if (query.store_tab === 'discounts') query.coupon_page = '1'; load();")
    commerce = replace_once(commerce,
        "let query = {store_tab: 'products', store_source: 'all', date_preset: 'today'};",
        "let query = {store_tab: new URLSearchParams(location.search).get('store_tab') === 'discounts' ? 'discounts' : 'products', store_source: 'all', date_preset: 'today'};\n"
        "  addEventListener('message', event => {\n"
        "    if (event.source !== parent || event.origin !== location.origin || event.data?.type !== 'kidia:commerce-tab' || !['discounts','products'].includes(event.data.tab)) return;\n"
        "    query = {store_tab:event.data.tab,store_source:'all',date_preset:'today'};\n"
        "    if (root) load();\n"
        "  });")
    return index, central, frame, commerce


def main():
    root = Path(sys.argv[1]).resolve()
    sha = lambda data: hashlib.sha256(data).hexdigest()
    version = sha(Path(__file__).read_bytes())[:12]
    backup = root.parent / ('discounts-backup-' + version)
    review = 'index-discounts-' + version + '-review.html'
    owner = (root / 'index.html').stat()

    def write(name, data):
        target = root / name
        assert root in target.resolve().parents
        temp = target.with_name(target.name + '.discounts-tmp')
        with temp.open('xb') as handle:
            handle.write(data)
        if hasattr(os, 'chown'):
            os.chown(temp, owner.st_uid, owner.st_gid)
        os.chmod(temp, 0o644)
        temp.replace(target)

    if '--activate' in sys.argv:
        record = json.loads((backup / 'manifest.json').read_text())
        for name, digest in {**record['originals'], **record['published']}.items():
            assert sha((root / name).read_bytes()) == digest, 'Changed since review: ' + name
        write('index.html', (root / review).read_bytes())
        print(json.dumps({'activated': True, 'backup': str(backup)}))
        return

    index = (root / 'index.html').read_text(encoding='utf-8')
    central_name = re.findall(r'src="(assets/original-central[^"?]+\.js)(?:\?[^"]*)?"', index)
    assert len(central_name) == 1, 'Current central script must be unambiguous'
    central_name = central_name[0]
    central = (root / central_name).read_text(encoding='utf-8')
    frames = set(re.findall(r"(screen-frame[^'\"?]+\.html)\?connected=1", central))
    assert len(frames) == 1, 'Current frame must be unambiguous'
    frame_name = frames.pop()
    frame = (root / frame_name).read_text(encoding='utf-8')
    commerce_names = re.findall(r'src="(assets/store-data-live[^"?]+\.js)(?:\?[^"]*)?"', frame)
    assert len(commerce_names) == 1
    commerce_name = commerce_names[0]
    commerce = (root / commerce_name).read_text(encoding='utf-8')
    index, central, frame, commerce = patch(index, central, frame, commerce, version)
    new_central = 'assets/original-central-discounts-' + version + '.js'
    new_commerce = 'assets/store-data-live-discounts-' + version + '.js'
    new_frame = 'screen-frame-discounts-' + version + '.html'
    index = index.replace(central_name, new_central)
    central = central.replace(frame_name, new_frame)
    frame = frame.replace(commerce_name, new_commerce)
    changes = {new_central: central, new_commerce: commerce, new_frame: frame, review: index}
    originals = {name: (root / name).read_bytes() for name in ['index.html', central_name, frame_name, commerce_name]}
    assert not backup.exists(), 'Review this deployment before restaging'
    backup.mkdir(mode=0o700)
    for name, data in originals.items():
        target = backup / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    for name, value in changes.items():
        assert not (root / name).exists()
        write(name, value.encode())
    record = {'originals': {name: sha(data) for name, data in originals.items()},
              'published': {name: sha(value.encode()) for name, value in changes.items()}, 'review': review}
    (backup / 'manifest.json').write_text(json.dumps(record, indent=2))
    print(json.dumps({'review_ready': True, 'review': review, 'backup': str(backup)}))


if __name__ == '__main__':
    main()
