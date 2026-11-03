from pathlib import Path
import importlib.util
import unittest

spec = importlib.util.spec_from_file_location('preview_patch', Path(__file__).with_name('patch-preview-auth-performance.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class PreviewPrefetchPatchTests(unittest.TestCase):
    def test_second_deployment_preserves_an_existing_prefetch(self):
        source = """// Other builder features stay unchanged.
  async function load(screenName) {
    return json(origin + '/account/builder/state?store=' + encodeURIComponent(store) + '&screen=' + encodeURIComponent(screenName) + '&settings_only=1&_fresh=' + Date.now());
  }
response = await KidiaPreviewAuth.load(await load('home-builder'), window.fetch.bind(window));"""
        first = module.patch(source)
        self.assertEqual(module.patch(first), first)
        self.assertIn('// Other builder features stay unchanged.', first)

    def test_partial_patch_still_requires_review(self):
        with self.assertRaises(AssertionError):
            module.patch("response = await KidiaPreviewAuth.load(previewAuthPayload || await load('home-builder'), window.fetch.bind(window));")

if __name__ == '__main__':
    unittest.main()
