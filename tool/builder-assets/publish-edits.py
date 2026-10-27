"""Stage/review/activate one-click saving against the exact current Builder.

Usage: python publish-edits.py BUILDER_ROOT EXPECTED_INDEX_SHA [--activate REVIEW_VERSION]
Only versioned assets are added; activation atomically switches the index.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import sys


def replace(source, old, new):
    assert source.count(old) == 1, 'Integration point changed: ' + old[:100]
    return source.replace(old, new)


def frame_patch(source):
    source = replace(source, '  const applicationSave = KidiaApplicationSave.create({', '''  let publishSavedState = {};
  const publishEditor = KidiaPublishEdits.screens.has(screen) ? KidiaPublishEdits.editor({
    screen, form: () => root.querySelector('#mobishop-home-builder-form, form.mobishop-page-editor') || root.querySelector('form'),
    serialize, savedState: () => publishSavedState, busy: () => applicationSave.busy || applicationSave.blocked,
    lock: busy => { root.inert = busy; }
  }) : null;
  if (publishEditor) window.MobiShopPublishEditor = publishEditor;
  window.addEventListener('pagehide', () => publishEditor?.abort(), {once:true});
  const applicationSave = KidiaApplicationSave.create({''')
    source = replace(source, '    uuid: () => crypto.randomUUID(),\n    post: packet => parent.postMessage(packet, location.origin),', '''    uuid: () => publishEditor?.requestId || crypto.randomUUID(),
    post: packet => { publishEditor?.packet(packet); parent.postMessage(packet, location.origin); },''')
    source = replace(source, '      root.inert = busy;', '      root.inert = busy || Boolean(publishEditor?.locked);')
    source = replace(source, "  const appliedAIPushPrefills = new Set();\n  window.addEventListener('message', function (event) {", "  const appliedAIPushPrefills = new Set();\n  window.addEventListener('message', async function (event) {")
    source = replace(source, '        hydrate(event.data.payload || {});', '        await hydrate(event.data.payload || {});')
    source = replace(source, "      lastHydration = event.data.payload || {}; hydrateActionChoices(lastHydration);", "      publishSavedState = JSON.parse(JSON.stringify(event.data.payload?.settings || {}));\n      lastHydration = event.data.payload || {}; hydrateActionChoices(lastHydration);")
    source = replace(source, '    apply: async state => {', '    apply: async state => {\n      publishSavedState = JSON.parse(JSON.stringify(state));')
    source = replace(source, "        hydrateAbandonedCarts(event.data.payload || {});\n      }\n      scheduleFlutterPreview();", "        hydrateAbandonedCarts(event.data.payload || {});\n      }\n      publishEditor?.loaded();\n      scheduleFlutterPreview();")
    return source


def central_patch(source):
    source = replace(source, '  const applicationSaveRequests = new Map();', '''  const applicationSaveRequests = new Map();
  const publishEdits = window.MobiShopPublishEdits = KidiaPublishEdits.coordinator({
    store: () => new URL(location.href).searchParams.get('store') === store ? store : '',
    frames: () => [...new Set([frame, pendingFrame, ...cachedFrames.values()].filter(Boolean))],
    active: () => frame, pending: () => applicationSaveRequests.size > 0,
    uuid: () => crypto.randomUUID(),
    controls: {
      inspect: target => { if (!window.MobiShopPageControls?.inspect) throw new Error('Refresh the builder before publishing.'); return window.MobiShopPageControls.inspect(target); },
      validate: target => window.MobiShopPageControls.validate(target),
      stamp: target => window.MobiShopPageControls.stamp(target)
    }
  });''')
    source = replace(source, "    if (sender !== frame) return;\n    if (event.data.type === 'kidia:setup-exit'", "    if (sender !== frame && !publishEdits.accepts(sender, event.data)) return;\n    if (event.data.type === 'kidia:setup-exit'")
    source = replace(source, "    if (event.data.type === 'kidia:save') {\n", """    if (event.data.type === 'kidia:save') {
      if (publishEdits.busy && !publishEdits.accepts(sender, event.data)) {
        sender.contentWindow.postMessage({type:'kidia:save-result',screen:event.data.screen,request_id:event.data.request_id,result:{ok:false,screen:event.data.screen,message:'Wait for publishing to finish before saving.'}},location.origin);
        return;
      }
""")
    source = replace(source, "        if(request.screen==='setup') result=await applySetupTheme(event.data.state);\n        else {", """        if(request.screen==='setup') result=await applySetupTheme(event.data.state);
        else {
          if (publishEdits.accepts(sender, event.data)) {
            const current = await load(request.screen);
            if (!KidiaPublishEdits.sameSavedState(current.state, sender.contentWindow.MobiShopPublishEditor.savedState())) throw new Error('This page changed in another session. Reload and review your edits before publishing.');
          }""")
    return source


def stage(root, expected, activate=False):
    sha = lambda data: hashlib.sha256(data).hexdigest()
    here = Path(__file__).parent
    root = Path(root).resolve()
    original = (root / 'index.html').read_bytes()
    if activate:
        assert re.fullmatch('[a-f0-9]{12}', activate), 'Exact reviewed version required'
        record = json.loads((root / ('one-click-staged-' + activate + '.json')).read_text())
        assert record['published'][record['review']].startswith(activate)
        assert record['originals']['index.html'] == expected
        for name, digest in {**record['originals'], **record['published']}.items():
            assert sha((root / name).read_bytes()) == digest, 'Changed since review: ' + name
        write(root, 'index.html', (root / record['review']).read_bytes())
        print(json.dumps({'activated': True, 'backup': record['backup']}))
        return
    assert sha(original) == expected, 'Builder changed; reconcile before staging'
    index = original.decode()
    central_name = re.search(r'assets/original-central-[^"?]+\.js', index)[0]
    central_raw = (root / central_name).read_bytes()
    central = central_raw.decode()
    frame_name = re.search(r'screen-frame-[\w-]+\.html', central)[0]
    frame_raw = (root / frame_name).read_bytes()
    frame_html = frame_raw.decode()
    frame_js_name = re.search(r'assets/screen-frame-[\w-]+\.js', frame_html)[0]
    frame_js_raw = (root / frame_js_name).read_bytes()
    publish_name = re.search(r'assets/live-design-publish-[\w-]+\.js', index)[0]
    controls_name = re.search(r'assets/page-controls-[\w-]+\.js', index)[0]
    originals = {'index.html': original, central_name: central_raw, frame_name: frame_raw, frame_js_name: frame_js_raw,
                 publish_name: (root / publish_name).read_bytes(), controls_name: (root / controls_name).read_bytes()}
    assets = {}

    def asset(prefix, raw, extension='js'):
        name = prefix + '-' + sha(raw)[:12] + '.' + extension
        assets[name] = raw
        return name

    bridge = asset('assets/publish-edits', (here / 'publish-edits.js').read_bytes())
    new_frame_js = asset('assets/screen-frame-one-click', frame_patch(frame_js_raw.decode()).encode())
    frame_html = frame_html.replace(frame_js_name, new_frame_js)
    frame_html = replace(frame_html, '<script src="' + new_frame_js, '<script src="' + bridge + '"></script>\n<script src="' + new_frame_js)
    new_frame_html = asset('screen-frame-one-click', frame_html.encode(), 'html')
    central = central_patch(central).replace(frame_name, new_frame_html)
    new_central = asset('assets/original-central-one-click', central.encode())
    new_publisher = asset('assets/live-design-publish', (here / 'live-design-publish.js').read_bytes())
    new_controls = asset('assets/page-controls', (here.parent.parent / 'tools/live_ui_controls/page-controls.js').read_bytes())
    index = index.replace(central_name, new_central).replace(frame_name, new_frame_html).replace(publish_name, new_publisher).replace(controls_name, new_controls)
    index = replace(index, '<script src="' + new_central, '<script src="' + bridge + '"></script>\n<script src="' + new_central)
    review = asset('index-one-click-review', index.encode(), 'html')
    backup = root.parent / ('one-click-backup-' + sha(index.encode())[:12])
    assert not backup.exists(), 'Review already staged; use recorded manifest'
    backup.mkdir(mode=0o700)
    (backup / 'index.html').write_bytes(original)
    for name, raw in assets.items():
        if (root / name).exists(): assert (root / name).read_bytes() == raw, 'Versioned asset collision'
        else: write(root, name, raw)
    for name, raw in originals.items(): assert (root / name).read_bytes() == raw, 'Concurrent edit: ' + name
    record = {'originals': {name: sha(raw) for name, raw in originals.items()}, 'published': {name: sha(raw) for name, raw in assets.items()}, 'backup': str(backup), 'review': review}
    (backup / 'manifest.json').write_text(json.dumps(record, indent=2))
    version = sha(index.encode())[:12]
    write(root, 'one-click-staged-' + version + '.json', json.dumps(record, indent=2).encode())
    print(json.dumps({'version': version, 'review': review, 'backup': str(backup), 'assets': list(assets)}))


def write(root, name, data):
    target = root / name
    assert root in target.resolve().parents
    target.parent.mkdir(parents=True, exist_ok=True)
    owner = (root / 'index.html').stat()
    temp = target.with_name(target.name + '.one-click-tmp')
    with temp.open('xb') as handle: handle.write(data)
    if hasattr(os, 'chown'): os.chown(temp, owner.st_uid, owner.st_gid)
    os.chmod(temp, 0o644)
    temp.replace(target)


if __name__ == '__main__':
    stage(sys.argv[1], sys.argv[2], sys.argv[sys.argv.index('--activate') + 1] if '--activate' in sys.argv else False)
