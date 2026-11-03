import hashlib
import io
from pathlib import Path
import plistlib
import tempfile
import unittest
import zipfile

from prepare_app_store_upload import prepare
from verify_ios_signing import SigningError


class ExistingAppUploadTest(unittest.TestCase):
    def setUp(self):
        self.env = dict(IOS_BUNDLE_ID='com.customer.store', APPLE_TEAM_ID='AB12345678',
                        IOS_SIGNING_PROFILE_UUID='12345678-1234-1234-1234-123456789012',
                        IOS_SIGNING_CERTIFICATE_SHA256='a'*64, STORE_NAME='Store',
                        SIGNED_IPA_URL='https://api.codemagic.io/artifacts/test/app.ipa',
                        BUILD_VERSION_CODE='313', BUILD_VERSION_NAME='1.0.0')

    def artifact(self, **changes):
        info = dict(CFBundleIdentifier='com.customer.store', CFBundleVersion='313',
                    CFBundleShortVersionString='1.0.0')
        info.update(changes)
        result = io.BytesIO()
        with zipfile.ZipFile(result, 'w') as archive:
            archive.writestr('Payload/Runner.app/Info.plist', plistlib.dumps(info))
        return result.getvalue()

    def run_prepare(self, blob, output, verifier=lambda *_: None):
        prepare(self.env, output, opener=lambda *_a, **_k: io.BytesIO(blob), verifier=verifier)

    def test_verified_exact_binary_preserved(self):
        blob = self.artifact()
        self.env['SIGNED_IPA_SHA256'] = hashlib.sha256(blob).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)/'app.ipa'; calls=[]
            self.run_prepare(blob, output, lambda p,e: calls.append((p.read_bytes(), e)))
            self.assertEqual(output.read_bytes(), blob)
            self.assertEqual(calls, [(blob, self.env)])

    def test_wrong_hash_identity_version_or_signature_never_publishes(self):
        for case in ('hash','bundle','version','name','signature'):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as directory:
                changes = {'bundle':{'CFBundleIdentifier':'com.other.store'},
                           'version':{'CFBundleVersion':'312'},
                           'name':{'CFBundleShortVersionString':'2.0.0'}}
                blob = self.artifact(**changes.get(case, {}))
                self.env['SIGNED_IPA_SHA256'] = 'b'*64 if case=='hash' else hashlib.sha256(blob).hexdigest()
                output = Path(directory)/'app.ipa'; output.write_bytes(b'stale artifact')
                def verify(*_):
                    if case=='signature': raise SigningError('fixture invalid signature')
                with self.assertRaises(SigningError): self.run_prepare(blob, output, verify)
                self.assertFalse(output.exists())

    def test_untrusted_download_sources_rejected_before_network(self):
        self.env['SIGNED_IPA_SHA256']='a'*64
        for url in ('http://api.codemagic.io/x','https://other.example/x',
                    'https://api.codemagic.io.attacker.example/x','https://user:secret@api.codemagic.io/x'):
            with self.subTest(url=url), tempfile.TemporaryDirectory() as directory:
                self.env['SIGNED_IPA_URL']=url
                with self.assertRaises(SigningError):
                    prepare(self.env, Path(directory)/'app.ipa', opener=lambda *_a,**_k: self.fail('Network must not run'))


if __name__ == '__main__':
    unittest.main()
