"""Stage reviewed Kids spacing changes; activate only if live originals still match.
Usage: python3 deploy-kids-spacing.py /path/to/reviewed/repo [--activate]
Requires a completed Flutter CMS preview build in repo/preview.
Private rollback copies include the live builder, schemas and connector download.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import sys
import subprocess
import difflib
import io
import zipfile

root = Path('/home/woomobile/woomobile-api/public/mobishop-builder-v26')
repo = Path(sys.argv[1]).resolve()
preview = repo / 'preview'
base = 'bbc2d7abc4b85af785591f912b3bbb581ba85370'
sha = lambda data: hashlib.sha256(data).hexdigest()
version = sha((preview / 'main.dart.js').read_bytes() + Path(__file__).read_bytes())[:12]
backup = Path('/home/woomobile/kids-spacing-preview-backup-' + version)
manifest_path = backup / 'manifest.json'
owner = (root / 'index.html').stat()

def write(path, data):
    tmp = path.with_name(path.name + '.spacing-preview-tmp')
    with tmp.open('xb') as stream:
        stream.write(data)
    current_owner = path.stat() if path.exists() else owner
    os.chown(tmp, current_owner.st_uid, current_owner.st_gid)
    os.chmod(tmp, 0o644)
    tmp.replace(path)

if '--activate' in sys.argv:
    manifest = json.loads(manifest_path.read_text())
    for name, expected in manifest['originals'].items():
        assert sha((root / name).read_bytes()) == expected, 'Concurrent change: ' + name
    for name, expected in manifest['staged'].items():
        assert sha((root / name).read_bytes()) == expected, 'Staged change: ' + name
    for target, record in manifest['external'].items():
        assert sha(Path(target).read_bytes()) == record['original'], 'Concurrent external change: ' + target
        assert sha(Path(record['candidate']).read_bytes()) == record['sha256']
        if target.endswith('.php'):
            subprocess.run(['/opt/cpanel/ea-php83/root/usr/bin/php', '-l', record['candidate']], check=True)
    for target, record in manifest['external'].items():
        write(Path(target), Path(record['candidate']).read_bytes())
    write(root / 'index.html', (backup / 'index-candidate.html').read_bytes())
    print(json.dumps({'activated': True, 'backup': str(backup), 'bundle': manifest['bundle']}))
    sys.exit()

assert not backup.exists(), 'Inspect existing staged deployment first'
backup.mkdir(mode=0o700)
originals = {}
def read(name):
    data = (root / name).read_bytes()
    originals[name] = sha(data)
    target = backup / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    return data.decode()

index = read('index.html')
central_ref = re.search(r'assets/(?:original|customize)-central[^"?\s]+\.js', index)[0]
central = read(central_ref)
frame_ref = re.search(r'(?:screen-frame|customize-screen-frame)[^"?\s]+\.html', central)[0]
frame = read(frame_ref)
script_ref = re.search(r'assets/(?:screen-frame|customize-screen-frame)[^"?\s]+\.js', frame)[0]
script = read(script_ref)
old_bundle = re.search(r'assets/flutter-preview-[\w-]+/', central)[0]
assert old_bundle == 'assets/flutter-preview-kids-address-1238a4ad6368/', 'Live preview changed: re-review its source'
bundle = 'assets/flutter-preview-kids-spacing-' + version + '/'
assert not (root / bundle).exists()
shutil.copytree(preview, root / bundle, ignore=shutil.ignore_patterns('*.symbols', 'experimental_webparagraph', 'skwasm*', 'wimp*'))
target = root / bundle
page = (target / 'index.html').read_text()
assert '<base href="/">' in page
(target / 'index.html').write_text(page.replace('<base href="/">', '<base href="./">'))
bootstrap = (target / 'flutter_bootstrap.js').read_text()
assert '_flutter.loader.load();' in bootstrap
cache_suffix = '(window.__mobishopPreviewVersion?"?v="+encodeURIComponent(window.__mobishopPreviewVersion):"")'
for asset in ['canvaskit.js', 'canvaskit.wasm']:
    original = 'c(s,"' + asset + '")'
    assert original in bootstrap
    bootstrap = bootstrap.replace(original, 'c(s,"' + asset + '"+' + cache_suffix + ')')
loader = '''if (window.__mobishopPreviewVersion) { _flutter.buildConfig.builds.forEach(function (build) { if (build.mainJsPath) { build.mainJsPath += "?v=" + encodeURIComponent(window.__mobishopPreviewVersion); } }); }
window.__mobishopStartFlutterPreview=function(){
return _flutter.loader.load({config:{canvasKitBaseUrl:"canvaskit/"},
onEntrypointLoaded:async function(engineInitializer){
try{var appRunner=await engineInitializer.initializeEngine({canvasKitBaseUrl:"canvaskit/"});await appRunner.runApp();}
catch(error){window.dispatchEvent(new CustomEvent("mobishop-flutter-preview-error",{detail:String(error)}));}
}}).catch(function(error){window.dispatchEvent(new CustomEvent("mobishop-flutter-preview-error",{detail:String(error)}));});};
window.__mobishopStartFlutterPreview();'''
(target / 'flutter_bootstrap.js').write_text(bootstrap.replace('_flutter.loader.load();', loader))
shutil.copyfile(preview.parent / 'tool/cms-preview.htaccess', target / '.htaccess')
notices = target / 'assets/NOTICES'
notices.write_text(notices.read_text().replace('\r\n', '\n').replace('\r', '\n'))
new_central = 'assets/original-central-kids-spacing-' + version + '.js'
new_frame = 'screen-frame-kids-spacing-' + version + '.html'
new_script = 'assets/screen-frame-kids-spacing-' + version + '.js'
staged = {}
external = {}
def stage_external(path, data):
    original = path.read_bytes()
    private = backup / ('external-' + sha(str(path).encode())[:12])
    private.mkdir()
    (private / path.name).write_bytes(original)
    candidate = private / ('candidate-' + path.name)
    candidate.write_bytes(data)
    external[str(path)] = {'original':sha(original), 'candidate':str(candidate), 'sha256':sha(data), 'backup':str(private / path.name)}
    if path.suffix == '.php':
        subprocess.run(['/opt/cpanel/ea-php83/root/usr/bin/php', '-l', str(candidate)], check=True)

def git_source(path):
    return subprocess.check_output(['git', '-c', 'safe.directory='+str(repo), '-C', str(repo), 'show', base+':'+path])

# Patch only the two requested Kids settings; preserve every other live preset.
preset_ref = re.search(r'assets/theme-snapshots[^"\x27?\s]+\.json', central)[0]
presets = json.loads(read(preset_ref))
general = presets['kids_baby']['category']['general']
assert general['card_height'] == 190 and 'name_vertical_padding' not in general
appearance = json.loads((repo / 'tool/builder-assets/kids-appearance-20261027.json').read_text())
general['card_height'] = appearance['category']['general']['card_height']
general['name_vertical_padding'] = appearance['category']['general']['name_vertical_padding']
new_preset = 'assets/theme-snapshots-kids-spacing-' + version + '.json'
write(root / new_preset, (json.dumps(presets, ensure_ascii=False, separators=(',', ':'))+'\n').encode())
staged[new_preset] = sha((root / new_preset).read_bytes())
central = central.replace(preset_ref, new_preset)
for reference in set(re.findall(r'assets/theme-snapshots[^"\x27?\s]+\.json', script)):
    script = script.replace(reference, new_preset)

# Upgrade the inline category module only if it matches the reviewed baseline.
start = script.index('/* category-designer-')
ending = "})(typeof window==='undefined'?globalThis:window);"
end = script.index(ending, start) + len(ending)
assert script[start:end].strip() == git_source('tool/builder-assets/category-designer.js').decode().strip()
script = script[:start] + (repo / 'tool/builder-assets/category-designer.js').read_text().strip() + script[end:]

# Publish now normalizes numbers for WooCommerce, Shopify and Odoo alike.
schema_path = root.parents[1] / 'app/Services/SavedBuilderNativeDesign.php'
schema = schema_path.read_text()
a = schema.index('function categoryGeneral')
b = schema.index('return $settings;', a)
part = schema[a:b]
assert "'name_vertical_padding'" not in part
assert part.count("'text_max_lines', 'line_height'") == 1
part = part.replace("'text_max_lines', 'line_height'", "'text_max_lines', 'line_height', 'name_vertical_padding'")
stage_external(schema_path, (schema[:a]+part+schema[b:]).encode())

# Apply reviewed hunks to the active connector, preserving unrelated edits.
for relative in ['includes/class-mobishop-category-page-store.php', 'api/class-category-page-endpoint.php']:
    source_path = 'connectors/woocommerce/source/' + relative
    path = Path('/home/kidiastore/public_html/wp-content/plugins/mobi2app-connector') / relative
    raw = path.read_bytes()
    newline = '\r\n' if b'\r\n' in raw else '\n'
    live = raw.decode().replace('\r\n', '\n')
    old = git_source(source_path).decode().splitlines(True)
    new = (repo / source_path).read_text().splitlines(True)
    for group in difflib.SequenceMatcher(None, old, new).get_grouped_opcodes(2):
        before = ''.join(old[group[0][1]:group[-1][2]])
        after = ''.join(new[group[0][3]:group[-1][4]])
        assert live.count(before) == 1, 'Connector conflict: ' + relative
        live = live.replace(before, after, 1)
    stage_external(path, live.replace('\n', newline).encode())

# Shared automatic-install download: verify all 503 old files before upgrading.
downloads = Path('/home/woomobile/public_html/downloads')
alias = downloads / 'mobi2app-connector.zip'
release = downloads / 'connector-release.json'
old_manifest = json.loads(git_source('connectors/woocommerce/source-manifest.json'))
metadata = json.loads(release.read_text())
assert metadata['version'] == old_manifest['version'] == '1.46.109'
assert sha(alias.read_bytes()) == metadata['sha256']
with zipfile.ZipFile(io.BytesIO(alias.read_bytes())) as package:
    assert len(package.namelist()) == len(old_manifest['files'])
    for name, record in old_manifest['files'].items():
        assert sha(package.read('mobi2app-connector/' + name)) == record['sha256'], name
subprocess.run(['python3', str(repo / 'tool/build_woocommerce_connector.py')], check=True)
new_metadata = json.loads((repo / 'build/woocommerce/connector-release.json').read_text())
new_zip = (repo / 'build/woocommerce' / new_metadata['file']).read_bytes()
assert new_metadata['version'] == '1.46.110' and sha(new_zip) == new_metadata['sha256']
versioned = downloads / new_metadata['file']
assert not versioned.exists()
write(versioned, new_zip)
stage_external(alias, new_zip)
stage_external(release, (json.dumps(new_metadata, indent=2)+'\n').encode())

for name, contents in [(new_central, central.replace(old_bundle, bundle).replace(frame_ref, new_frame)), (new_frame, frame.replace(script_ref, new_script).replace(old_bundle, bundle)), (new_script, script.replace(old_bundle, bundle))]:
    assert not (root / name).exists()
    write(root / name, contents.encode())
    staged[name] = sha((root / name).read_bytes())
for path in [target, *target.rglob('*')]:
    os.chown(path, owner.st_uid, owner.st_gid)
    os.chmod(path, 0o755 if path.is_dir() else 0o644)
    if path.is_file():
        staged[str(path.relative_to(root))] = sha(path.read_bytes())
for name, expected in originals.items():
    assert sha((root / name).read_bytes()) == expected, 'Concurrent change: ' + name
candidate = index.replace(central_ref, new_central)
review = 'index-kids-spacing-review-' + version + '.html'
assert not (root / review).exists()
write(root / review, candidate.encode())
staged[review] = sha((root / review).read_bytes())
(backup / 'index-candidate.html').write_text(candidate)
manifest_path.write_text(json.dumps({'originals': originals, 'staged': staged, 'bundle': bundle, 'external': external}, indent=2))
print(json.dumps({'staged': True, 'backup': str(backup), 'bundle': bundle, 'review': review, 'main_js_sha256': sha((target / 'main.dart.js').read_bytes())}))
