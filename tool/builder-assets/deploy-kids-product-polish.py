"""Stage Kids product refinements on the current live builder; activate with CAS.

Usage: script builder_root repo_root [--activate]
Backups are private, outside the public tree. No store settings are changed here.
"""
from pathlib import Path
import copy
import difflib
import hashlib
import html
import json
import os
import re
import shutil
import subprocess
import sys


def digest(data):
    return hashlib.sha256(data).hexdigest()


def related_fields(repo):
    test = repo / 'mobishop/tests/page-layout-contract-test.php'
    # Reuse just the WordPress test stubs; the test itself exits on success.
    code = test.read_text().split('$store = new MobiShop_Page_Layout_Store();', 1)[0]
    code = code.replace('<?php', '', 1).replace('__DIR__', json.dumps(str(test.parent)))
    code += 'echo json_encode(MobiShop_Page_Layout_Store::element_definitions("product"));'
    definitions = json.loads(subprocess.check_output(['php', '-r', code]))
    return next(x['fields'] for x in definitions if x['id'] == 'related_products')


def field_html(field, prefix):
    key, kind = field['key'], field['type']
    name = html.escape(prefix + '[' + key + ']', quote=True)
    label = html.escape(field['label'])
    value = field['default']
    attrs = ' name="' + name + '" aria-label="' + label + '"'
    if kind == 'checkbox':
        control = '<input type="hidden" name="' + name + '" value="0"><input type="checkbox"' + attrs + ' value="1"' + (' checked' if value else '') + '>'
    elif kind in ('select', 'product_position'):
        control = '<select' + attrs + '>' + ''.join('<option value="' + html.escape(str(k), quote=True) + '"' + (' selected' if str(k) == str(value) else '') + '>' + html.escape(v) + '</option>' for k, v in field['options'].items()) + '</select>'
    else:
        assert kind in ('text', 'color', 'number'), kind
        limits = ''.join(' ' + k + '="' + str(field[k]) + '"' for k in ('min', 'max', 'step')) if kind == 'number' else ''
        control = '<input type="' + kind + '"' + attrs + limits + ' value="' + html.escape(str(value), quote=True) + '">'
    return '<div class="mobishop-page-field"><label>' + label + '</label>' + control + '</div>'


def patch_template(source, fields):
    marker = 'data-element="related_products"'
    start = source.index(marker)
    # This is the final product section; scope field discovery to it.
    end = source.index('data-element="footer"', start)
    section = source[start:end]
    prefix = re.search(r'name="(layout\[elements\]\[\d+\]\[settings\])\[title\]"', section)[1]
    missing = [f for f in fields if 'name="' + prefix + '[' + f['key'] + ']"' not in section]
    assert any(f['key'] == 'show_wishlist' for f in missing), 'Already patched or unexpected template'
    heading = re.search(r'<div class="mobishop-settings-section-title[^">]*--related_products">[^<]+</div>', section)
    assert heading
    at = start + heading.end()
    source = source[:at] + ''.join(field_html(f, prefix) for f in missing) + source[at:]
    source, count = re.subn(r'(<input\b[^>]*name="layout\[footer\]\[settings\]\[button_height\]"[^>]*step=")[^"]+', r'\g<1>0.01', source)
    assert count == 1, 'Footer button control missing'
    return source, [f['key'] for f in missing]


def patch_schema(source, fields):
    match = re.search(r"(private const FIELD_TYPES_JSON = ')(.*?)(';)", source)
    assert match
    schema = json.loads(match[2])
    original = copy.deepcopy(schema)
    related = schema['pages']['product']['related_products']
    for field in fields:
        related[field['key']] = field['type']
    check = copy.deepcopy(schema)
    check['pages']['product']['related_products'] = original['pages']['product']['related_products']
    assert check == original
    return source[:match.start(2)] + json.dumps(schema, separators=(',', ':'), ensure_ascii=False).replace("'", r'\u0027') + source[match.end(2):]


def patch_connector(source, repo):
    newline = '\r\n' if '\r\n' in source else '\n'
    source = source.replace('\r\n', '\n')
    path = 'mobishop/includes/class-mobishop-page-layout-store.php'
    before = subprocess.check_output(['git', '-c', 'safe.directory=' + str(repo), '-C', str(repo), 'show', '08559b4e20771c814c6840020c38d7e76026bec5:' + path]).decode()
    after = (repo / path).read_text()
    if "__( 'Related Products', 'mobi2app-connector' )" in source:
        before = before.replace("'mobishop'", "'mobi2app-connector'")
        after = after.replace("'mobishop'", "'mobi2app-connector'")
    a, b = before.splitlines(True), after.splitlines(True)
    # Apply only the reviewed source hunks, leaving unrelated live edits intact.
    for group in difflib.SequenceMatcher(None, a, b).get_grouped_opcodes(2):
        old = ''.join(a[group[0][1]:group[-1][2]])
        new = ''.join(b[group[0][3]:group[-1][4]])
        if new in source:
            continue
        assert source.count(old) == 1, 'Connector changed near product fields; inspect instead of overwriting'
        source = source.replace(old, new, 1)
    return source.replace('\n', newline)


def main():
    root, repo = [Path(p).resolve() for p in sys.argv[1:3]]
    appearance = (repo / 'tool/builder-assets/kids-appearance-20261027.json').read_bytes()
    main_js = repo / 'mobishop/admin/flutter-preview/main.dart.js'
    version = digest(appearance + main_js.read_bytes() + Path(__file__).read_bytes())[:12]
    backup = root.parents[2] / ('kids-product-backup-' + version)
    manifest_path = backup / 'manifest.json'
    review = 'index-kids-product-' + version + '-review.html'
    owner = (root / 'index.html').stat()

    def write(path, data, mode=0o644):
        file_owner = path.stat() if path.exists() else owner
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_name(path.name + '.kids-product-tmp')
        with temp.open('xb') as handle:
            handle.write(data)
        os.chown(temp, file_owner.st_uid, file_owner.st_gid)
        os.chmod(temp, mode)
        temp.replace(path)

    if '--activate' in sys.argv:
        record = json.loads(manifest_path.read_text())
        for path, expected in {**record['originals'], **record['staged']}.items():
            assert digest(Path(path).read_bytes()) == expected, 'Concurrent change: ' + path
        for target, candidate in record['php'].items():
            subprocess.run(['php', '-l', candidate], check=True)
        for target, candidate in record['php'].items():
            write(Path(target), Path(candidate).read_bytes())
        write(root / 'index.html', (root / review).read_bytes())
        print(json.dumps({'activated': True, 'backup': str(backup), 'review': review}))
        return

    assert not backup.exists(), 'Already staged: inspect manifest before proceeding'
    backup.mkdir(mode=0o700)
    originals, staged, php = {}, {}, {}

    def read(path):
        data = path.read_bytes()
        name = str(path)
        originals[name] = digest(data)
        destination = backup / 'originals' / path.relative_to('/').as_posix()
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        return data.decode()

    def stage(path, data):
        assert not path.exists(), 'Immutable candidate already exists: ' + str(path)
        write(path, data)
        staged[str(path)] = digest(data)

    index = read(root / 'index.html')
    central_ref = re.search(r'assets/(?:original|customize)-central[^"?\s]+\.js', index)[0]
    central = read(root / central_ref)
    frame_ref = re.search(r'(?:screen-frame|customize-screen-frame)[^"?\s]+\.html', central)[0]
    frame = read(root / frame_ref)
    script_ref = re.search(r'assets/(?:screen-frame|customize-screen-frame)[^"?\s]+\.js', frame)[0]
    script = read(root / script_ref)
    preset_ref = re.search(r'assets/theme-snapshots[^"\x27?\s]+\.json', central)[0]
    presets = json.loads(read(root / preset_ref))
    reviewed = subprocess.check_output(['git', '-c', 'safe.directory=' + str(repo), '-C', str(repo), 'show', '08559b4e20771c814c6840020c38d7e76026bec5:tool/builder-assets/kids-appearance-20261027.json'])
    assert presets['kids_baby'] == json.loads(reviewed), 'Kids preset changed since review'
    presets['kids_baby'] = json.loads(appearance)
    fields = related_fields(repo)
    template, added = patch_template(read(root / 'screens-v176/product.html'), fields)
    schema_path = root.parents[1] / 'app/Services/SavedBuilderNativeDesign.php'
    schema = patch_schema(read(schema_path), fields)
    connector_path = Path('/home/kidiastore/public_html/wp-content/plugins/mobi2app-connector/includes/class-mobishop-page-layout-store.php')
    connector = patch_connector(read(connector_path), repo)
    for target, contents in [(schema_path, schema), (connector_path, connector)]:
        candidate = backup / ('candidate-' + target.name)
        candidate.write_text(contents)
        subprocess.run(['php', '-l', str(candidate)], check=True)
        staged[str(candidate)] = digest(candidate.read_bytes())
        php[str(target)] = str(candidate)

    bundle_ref = re.search(r'assets/flutter-preview-[\w-]+/', central)[0]
    new_bundle = 'assets/flutter-preview-kids-product-' + version + '/'
    preview = repo / 'mobishop/admin/flutter-preview'
    assert (preview / 'flutter_bootstrap.js').is_file()
    assert 'canvasKitBaseUrl:"canvaskit/"' in (preview / 'flutter_bootstrap.js').read_text()
    assert '__mobishopPreviewVersion' in (preview / 'flutter_bootstrap.js').read_text()
    assert not (root / new_bundle).exists()
    shutil.copytree(preview, root / new_bundle, ignore=shutil.ignore_patterns('*.symbols', 'experimental_webparagraph', 'skwasm*', 'wimp*'))
    for path in [root / new_bundle, *(root / new_bundle).rglob('*')]:
        os.chown(path, owner.st_uid, owner.st_gid)
        os.chmod(path, 0o755 if path.is_dir() else 0o644)
        if path.is_file():
            staged[str(path)] = digest(path.read_bytes())
    new_central = 'assets/original-central-kids-product-' + version + '.js'
    new_frame = 'screen-frame-kids-product-' + version + '.html'
    new_script = 'assets/screen-frame-kids-product-' + version + '.js'
    new_preset = 'assets/theme-snapshots-kids-product-' + version + '.json'
    new_template = 'product-kids-' + version
    # Replace only the embedded outline helper; preserve all other frame code.
    start = script.index('/* Product card outlines share')
    ending = "})(typeof window === 'undefined' ? globalThis : window);"
    end = script.index(ending, start) + len(ending)
    script = script[:start] + (repo / 'tool/builder-assets/product-outline.js').read_text().strip() + script[end:]
    fetch = "'screens-v176/' + (files[screen] || 'home')"
    assert script.count(fetch) == 1
    script = script.replace(fetch, "'screens-v176/' + (screen === 'product-builder' ? '" + new_template + "' : (files[screen] || 'home'))")
    for old in set(re.findall(r'assets/theme-snapshots[^"\x27?\s]+\.json', script)):
        script = script.replace(old, new_preset)
    shell = re.search(re.escape(bundle_ref) + r'index[^?\s\x27\x22]*\.html', central)[0]
    central = central.replace(shell, new_bundle + 'index.html').replace(bundle_ref, new_bundle).replace(frame_ref, new_frame).replace(preset_ref, new_preset)
    script = script.replace(bundle_ref, new_bundle)
    for name, contents in [(new_central, central), (new_frame, frame.replace(script_ref, new_script)), (new_script, script), (new_preset, json.dumps(presets, ensure_ascii=False, separators=(',', ':'))), ('screens-v176/' + new_template + '.html', template), (review, index.replace(central_ref, new_central))]:
        stage(root / name, contents.encode())
    for path, expected in originals.items():
        assert digest(Path(path).read_bytes()) == expected, 'Concurrent change during staging: ' + path
    manifest_path.write_text(json.dumps({'originals': originals, 'staged': staged, 'php': php, 'review': review, 'added_fields': added}, indent=2))
    print(json.dumps({'staged': True, 'review': review, 'backup': str(backup), 'added_fields': len(added)}))


if __name__ == '__main__':
    main()
