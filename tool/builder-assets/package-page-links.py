"""Package the generated preview using the standard preview bootstrap patches."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parents[2]
bundle = root / 'build/page-links-web'
index = bundle / 'index.html'
index.write_text(index.read_text().replace('<base href="/">', '<base href="./">'))
bootstrap = bundle / 'flutter_bootstrap.js'
source = bootstrap.read_text()
source = source.replace('_flutter.loader.load();', '_flutter.loader.load({config:{canvasKitBaseUrl:"canvaskit/"}});')
source = source.replace('_flutter.loader.load(', 'if (window.__mobishopPreviewVersion) { _flutter.buildConfig.builds.forEach(function (build) { if (build.mainJsPath) { build.mainJsPath += "?v=" + encodeURIComponent(window.__mobishopPreviewVersion); } }); }\n_flutter.loader.load(', 1)
bootstrap.write_text(source)
subprocess.run(['node', str(root / 'tool/patch_cms_flutter_bootstrap.mjs'), str(bootstrap)], check=True)
subprocess.run(['node', str(root / 'tool/normalize_cms_preview_artifacts.mjs'), str(bundle)], check=True)
shutil.copyfile(root / 'tool/cms-preview.htaccess', bundle / '.htaccess')
archive = root / 'build/page-links-color-20261030.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for path in bundle.rglob('*'):
        name = path.relative_to(bundle).as_posix()
        if not path.is_file() or name.endswith('.symbols'):
            continue
        if any(v in name for v in ['experimental_webparagraph', '/skwasm', '/wimp']):
            continue
        z.write(path, name)
print(archive)
print(hashlib.sha256(archive.read_bytes()).hexdigest())
