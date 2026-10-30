import importlib.util, pathlib, tempfile, unittest, zipfile, plistlib
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('runner',pathlib.Path(__file__).with_name('publish_runner.py'))
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
class PublicationTests(unittest.TestCase):
    def test_codemagic_google_storage_artifact_is_accepted(self):
        url = ('https://storage.googleapis.com/codemagic-build-artifacts/'
               'a52bf0a4-a0d5-40b6-b0c2-de453d849d19/'
               '52c7c84d-a9fb-4759-ac6a-e8f0daa22555/mobishop-build-files.zip'
               '?Expires=1793324885&GoogleAccessId=test&Signature=test%2Bsignature')
        self.assertEqual(runner.approved_download(url), url)
        request = runner.urllib.request.Request('https://api.codemagic.io/artifacts/test')
        redirected = runner.ArtifactRedirect().redirect_request(request, None, 302, 'Found', {}, url)
        self.assertEqual(redirected.full_url, url)

    def test_google_storage_allowlist_is_limited_to_build_bucket(self):
        for url in [
            'https://storage.googleapis.com/unrelated-bucket/file.zip',
            'https://storage.googleapis.com/codemagic-build-artifacts.evil/file.zip',
            'https://storage.googleapis.com.evil.test/codemagic-build-artifacts/file.zip',
            'https://storage.googleapis.com/codemagic-build-artifacts/../other/file.zip',
            'https://storage.googleapis.com/codemagic-build-artifacts/%2e%2e/other/file.zip',
            'https://storage.googleapis.com/codemagic-build-artifacts/%252e%252e/file.zip',
            'https://storage.googleapis.com/codemagic-build-artifacts/a%2ffile.zip',
            'https://storage.googleapis.com/codemagic-build-artifacts/a\\file.zip',
            'https://storage.googleapis.com/codemagic-build-artifacts/',
            'https://storage.googleapis.com:444/codemagic-build-artifacts/file.zip',
        ]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                runner.approved_download(url)

    def test_untrusted_redirect_is_rejected(self):
        request = runner.urllib.request.Request('https://api.codemagic.io/artifacts/test')
        with self.assertRaises(ValueError):
            runner.ArtifactRedirect().redirect_request(
                request, None, 302, 'Found', {}, 'https://example.test/file.zip')

    def test_untrusted_artifact_urls_are_rejected(self):
        for url in ['http://api.codemagic.io/a','https://api.codemagic.io.evil.test/a','https://169.254.169.254/a','https://user:pass@api.codemagic.io/a']:
            with self.assertRaises(ValueError): runner.approved_download(url)
    def test_archive_does_not_extract_paths(self):
        with tempfile.TemporaryDirectory() as temp:
            root=pathlib.Path(temp);archive=root/'bundle.zip'
            with zipfile.ZipFile(archive,'w') as z:z.writestr('../../escape.aab',b'artifact')
            result=runner.artifact_from_archive(archive,'android',root)
            self.assertEqual(result,root/'application.aab');self.assertEqual(result.read_bytes(),b'artifact')
    def test_ambiguous_artifacts_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root=pathlib.Path(temp);archive=root/'bundle.zip'
            with zipfile.ZipFile(archive,'w') as z:z.writestr('a.aab',b'a');z.writestr('b.aab',b'b')
            with self.assertRaises(ValueError):runner.artifact_from_archive(archive,'android',root)
    def test_android_identity_precedes_publishing(self):
        manifest='<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="app.customer.one" android:versionName="1.0.1" android:versionCode="4"/>'
        payload={'platform':'android','application_id':'app.customer.one','version':'1.0.1','version_code':4}
        with patch.object(runner,'run_capture',return_value=manifest):
            runner.validate_identity(pathlib.Path('app.aab'),payload)
            with self.assertRaises(ValueError):runner.validate_identity(pathlib.Path('app.aab'),dict(payload,application_id='app.customer.two'))
    def test_ios_identity_checked_without_upload(self):
        with tempfile.TemporaryDirectory() as temp:
            artifact=pathlib.Path(temp)/'app.ipa'
            with zipfile.ZipFile(artifact,'w') as z:z.writestr('Payload/App.app/Info.plist',plistlib.dumps({'CFBundleIdentifier':'app.customer.one','CFBundleShortVersionString':'1.0.1','CFBundleVersion':'4'}))
            runner.validate_identity(artifact,{'platform':'ios','application_id':'app.customer.one','version':'1.0.1','version_code':4})
    def test_test_release_cannot_submit_production(self):
        with tempfile.TemporaryDirectory() as temp:
            root=pathlib.Path(temp)
            for platform in ['android','ios']:
                p={'platform':platform,'destination':'test','version':'1.0.1','notes':'Fixes','credentials':{'private_key':'test-only','key_id':'TEST','issuer_id':'TEST'}}
                command,env=runner.publish_command(p,root/'artifact',root)
                self.assertNotIn('--app-store',command);self.assertNotIn('production',command)
                self.assertNotIn('test-only',' '.join(command));self.assertNotIn('PUBLICATION_TOKEN',env)
if __name__=='__main__':unittest.main()
