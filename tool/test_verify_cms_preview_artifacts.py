import unittest
from verify_cms_preview_artifacts import LICENSE_SEPARATOR, difference


class PreviewArtifactComparisonTest(unittest.TestCase):
    def test_license_order_and_newlines_do_not_remove_content(self):
        a = 'flutter\n\nComplete BSD license'
        b = 'font\n\nComplete font license'
        before = (a + LICENSE_SEPARATOR + b).encode()
        after = (b + LICENSE_SEPARATOR + a).replace('\n', '\r\n').encode()
        self.assertIsNone(difference('assets/NOTICES', before, after))
        self.assertIsNotNone(difference('assets/NOTICES', before, a.encode()))
        self.assertIsNotNone(difference('assets/NOTICES', before, before + LICENSE_SEPARATOR.encode() + a.encode()))

    def test_license_word_change_fails(self):
        self.assertIsNotNone(difference('assets/NOTICES', b'Author A', b'Author B'))

    def test_only_startup_wrapper_blank_line_is_normalized(self):
        a = b'cache();\nwindow.__mobishopStartFlutterPreview=function(){\nstart();\n};'
        self.assertIsNone(difference('flutter_bootstrap.js', a, a.replace(b'\nwindow.', b'\n\nwindow.')))
        self.assertIsNotNone(difference('flutter_bootstrap.js', a, a.replace(b'cache()', b'wrong()')))
        self.assertIsNotNone(difference('flutter_bootstrap.js', a, a.replace(b'\nstart()', b'\n\nstart()')))

    def test_other_assets_are_exact(self):
        self.assertIsNone(difference('assets/logo.png', b'logo', b'logo'))
        self.assertIsNotNone(difference('assets/logo.png', b'logo', b'new logo'))
        self.assertIsNotNone(difference('index.html', b'a\nb', b'a\r\nb'))

    def test_build_identifier_is_generated_but_required(self):
        self.assertIsNone(difference('.last_build_id', b'a' * 32, b'b' * 32))
        self.assertIsNotNone(difference('.last_build_id', b'a' * 32, b''))

    def test_entrypoint_must_exist_and_not_be_empty(self):
        self.assertIsNone(difference('main.dart.js', b'old()', b'new()'))
        self.assertIsNotNone(difference('main.dart.js', b'old()', b' '))


if __name__ == '__main__':
    unittest.main()
