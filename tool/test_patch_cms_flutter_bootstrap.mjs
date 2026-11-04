import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const patcher = fileURLToPath(new URL('./patch_cms_flutter_bootstrap.mjs', import.meta.url));
const loader = '_flutter.loader.load({config:{canvasKitBaseUrl:"canvaskit/"}});';

function run(source) {
  const dir = mkdtempSync(join(tmpdir(), 'mobishop-bootstrap-'));
  try {
    const path = join(dir, 'flutter_bootstrap.js');
    writeFileSync(path, source);
    const result = spawnSync(process.execPath, [patcher, path], { encoding: 'utf8' });
    return { ...result, source: readFileSync(path, 'utf8') };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

for (const [fn, arg] of [['c', 's'], ['x', 'e'], ['$join', '_base']]) {
  test(`patches generated CanvasKit calls using ${fn}/${arg}`, () => {
    const result = run(`${fn}(${arg},"canvaskit.js");${fn}(${arg},"canvaskit.wasm");${loader}`);
    assert.equal(result.status, 0, result.stderr);
    assert.equal((result.source.match(/encodeURIComponent\(window\.__mobishopPreviewVersion\)/g) ?? []).length, 2);
    assert.ok(result.source.includes('window.__mobishopStartFlutterPreview=function()'));
    assert.ok(result.source.includes('mobishop-flutter-preview-error'));
  });
}

test('leaves input untouched when generated asset calls are ambiguous or missing', () => {
  for (const prefix of [
    'c(s,"canvaskit.js");c(s,"canvaskit.js");c(s,"canvaskit.wasm");',
    'c(s,"canvaskit.js");',
  ]) {
    const source = prefix + loader;
    const result = run(source);
    assert.notEqual(result.status, 0);
    assert.equal(result.source, source);
  }
});
