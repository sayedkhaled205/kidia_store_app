import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from verify_android_signing import (SigningError, apk_signer, bundle_package, certificate_report,
                                    identity, prepare, validate_signer, verify_artifacts)


PACKAGE = "app.example.customer"
DIGEST = "1a" * 32


def qa():
    return {"MOBISHOP_ANDROID_BUILD_MODE": "qa", "ANDROID_APPLICATION_ID": PACKAGE}


def release():
    return {**qa(), "MOBISHOP_ANDROID_BUILD_MODE": "release",
            "ANDROID_SIGNING_CERTIFICATE_SHA256": DIGEST,
            "CM_KEYSTORE_PATH": "/ci/registered.keystore", "CM_KEYSTORE_PASSWORD": "fixture",
            "CM_KEY_ALIAS": "fixture", "CM_KEY_PASSWORD": "fixture"}


def wire(field, value):
    def varint(n):
        result = bytearray()
        while n > 127:
            result.append((n & 127) | 128)
            n >>= 7
        result.append(n)
        return bytes(result)
    return varint((field << 3) | 2) + varint(len(value)) + value


def manifest(package=PACKAGE):
    attribute = wire(2, b"package") + wire(3, package.encode())
    return wire(1, wire(3, b"manifest") + wire(4, attribute))


class SigningPolicyTests(unittest.TestCase):
    def test_managed_qa_requires_key_and_bound_fingerprint(self):
        for changes in ({}, {"MOBISHOP_QA_KEYSTORE": "Zml4dHVyZQ=="}, {"MOBISHOP_QA_CERT_SHA256": DIGEST}):
            with self.subTest(changes=tuple(changes)), self.assertRaises(SigningError):
                identity({**qa(), "MOBISHOP_REQUIRE_QA_SIGNING": "true", **changes})
        env = {**qa(), "MOBISHOP_QA_KEYSTORE": "Zml4dHVyZQ==", "MOBISHOP_QA_CERT_SHA256": DIGEST}
        expected = identity(env)
        self.assertTrue(validate_signer({"certificate_sha256": DIGEST, "subject": "CN=Android Debug"}, expected))
        with self.assertRaises(SigningError):
            validate_signer({"certificate_sha256": "2b" * 32, "subject": "CN=Android Debug"}, expected)
        with self.assertRaises(SigningError):
            identity({**release(), "MOBISHOP_QA_KEYSTORE": "Zml4dHVyZQ=="})

    def test_managed_qa_preflight_verifies_private_file_without_exporting_key(self):
        with tempfile.TemporaryDirectory() as directory, patch("tempfile.tempdir", directory):
            env_file = Path(directory) / "env"
            encoded = base64.b64encode(b"disposable-private-key-fixture").decode()
            env = {**qa(), "MOBISHOP_QA_KEYSTORE": encoded, "MOBISHOP_QA_CERT_SHA256": DIGEST}
            with patch("verify_android_signing.certificate_report", return_value={"certificate_sha256": DIGEST, "subject": "CN=Android Debug"}) as verifier:
                prepare(env, env_file)
                path = verifier.call_args.args[1]
                self.assertEqual(path.read_bytes(), b"disposable-private-key-fixture")
                self.assertNotIn(encoded, env_file.read_text())
                self.assertIn("MOBISHOP_QA_KEYSTORE=\n", env_file.read_text())
                self.assertEqual(verifier.call_args.args[2]["CM_KEY_ALIAS"], "androiddebugkey")

    def test_managed_qa_rejects_wrong_signer_and_removes_temporary_key(self):
        with tempfile.TemporaryDirectory() as directory, patch("tempfile.tempdir", directory):
            env_file = Path(directory) / "env"
            env = {**qa(), "MOBISHOP_QA_KEYSTORE": "Zml4dHVyZQ==", "MOBISHOP_QA_CERT_SHA256": DIGEST}
            with patch("verify_android_signing.certificate_report", return_value={"certificate_sha256": "2b" * 32, "subject": "CN=Android Debug"}), self.assertRaises(SigningError):
                prepare(env, env_file)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_mode_is_mandatory(self):
        for mode in ("", "production", "QA"):
            with self.subTest(mode=mode), self.assertRaises(SigningError):
                identity({**qa(), "MOBISHOP_ANDROID_BUILD_MODE": mode})

    def test_release_requires_registered_signer_and_complete_credentials(self):
        for field in release():
            with self.subTest(field=field), self.assertRaises(SigningError):
                identity({**release(), field: ""})

    def test_qa_rejects_release_credentials(self):
        for field in ("CM_KEYSTORE_PATH", "CM_KEYSTORE", "CM_KEY_ALIAS", "CM_KEY_PASSWORD", "CM_KEYSTORE_PASSWORD", "ANDROID_SIGNING_CERTIFICATE_SHA256"):
            with self.subTest(field=field), self.assertRaises(SigningError):
                identity({**qa(), field: "unexpected"})

    def test_qa_cannot_override_required_release_signing(self):
        with self.assertRaises(SigningError):
            identity({**qa(), "MOBISHOP_REQUIRE_RELEASE_SIGNING": "true"})

    def test_rejects_two_keystore_sources(self):
        with self.assertRaises(SigningError):
            identity({**release(), "CM_KEYSTORE": "eA=="})

    def test_expected_signer_verified_but_debug_rejected_even_when_digest_matches(self):
        expected = identity(release())
        self.assertFalse(validate_signer({"certificate_sha256": DIGEST, "subject": "CN=Customer"}, expected))
        with self.assertRaises(SigningError):
            validate_signer({"certificate_sha256": DIGEST, "subject": "CN=Android Debug,O=Android,C=US"}, expected)

    def test_other_customer_signer_rejected(self):
        with self.assertRaises(SigningError):
            validate_signer({"certificate_sha256": "2b" * 32, "subject": "CN=Other Customer"}, identity(release()))

    def test_test_mode_accepts_debug_only(self):
        self.assertTrue(validate_signer({"certificate_sha256": DIGEST, "subject": "C=US, O=Android, CN=Android Debug"}, identity(qa())))
        with self.assertRaises(SigningError):
            validate_signer({"certificate_sha256": DIGEST, "subject": "CN=Customer"}, identity(qa()))

    def test_bundle_package_is_parsed_structurally(self):
        self.assertEqual(bundle_package(manifest()), PACKAGE)

    def test_apksigner_both_sdk_output_formats(self):
        for prefix in ("Signer #1", "V2 Signer:"):
            output = f"Number of signers: 1\n{prefix} certificate DN: CN=Customer\n{prefix} certificate SHA-256 digest: {DIGEST}\n"
            self.assertEqual(apk_signer(output)["certificate_sha256"], DIGEST)
        with self.assertRaises(SigningError):
            apk_signer(output.replace("signers: 1", "signers: 2"))

    def test_duplicate_or_missing_bundle_package_fails(self):
        attribute = wire(4, wire(2, b"package") + wire(3, PACKAGE.encode()))
        for data in (b"", wire(1, wire(3, b"manifest")), wire(1, wire(3, b"manifest") + attribute + attribute)):
            with self.subTest(data=data), self.assertRaises(SigningError):
                bundle_package(data)

    def test_truncated_manifest_fails(self):
        for data in (b"\x0a\x80", manifest()[:-1], b"\x0a\xff\xff\xff\xff\x0f"):
            with self.subTest(data=data), self.assertRaises(SigningError):
                bundle_package(data)

    def test_preflight_qa_never_installs_a_key(self):
        with patch("verify_android_signing.certificate_report") as verifier:
            prepare(qa(), None)
            verifier.assert_not_called()

    def test_invalid_base64_or_signer_never_publishes_key_path(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / "env"
            env = {**release(), "CM_KEYSTORE_PATH": "", "CM_KEYSTORE": "invalid"}
            with self.assertRaises(SigningError):
                prepare(env, env_file)
            self.assertFalse(env_file.exists())
            env["CM_KEYSTORE"] = base64.b64encode(b"disposable-test-data").decode()
            seen = []
            def reject(operation, path, environment):
                seen.append(path)
                raise SigningError("Rejected fixture")
            with patch("verify_android_signing.certificate_report", side_effect=reject), self.assertRaises(SigningError):
                prepare(env, env_file)
            self.assertFalse(env_file.exists())
            self.assertTrue(seen)
            self.assertFalse(seen[0].exists())

    def test_artifact_report_labels_qa_and_binds_both_packages_and_signers(self):
        with tempfile.TemporaryDirectory() as directory:
            apk, bundle = Path(directory) / "app.apk", Path(directory) / "app.aab"
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr("AndroidManifest.xml", b"fixture")
            with zipfile.ZipFile(bundle, "w") as archive:
                archive.writestr("base/manifest/AndroidManifest.xml", manifest())
            signer = {"certificate_sha256": DIGEST, "subject": "CN=Android Debug"}
            with patch("verify_android_signing.apk_report", return_value={**signer, "package": PACKAGE}), patch("verify_android_signing.certificate_report", return_value=dict(signer)):
                report = verify_artifacts(apk, bundle, qa())
                self.assertTrue(report["test_only"])
                self.assertFalse(report["release_signing_verified"])
                self.assertIn("TEST BUILD", report["notice"])
            with patch("verify_android_signing.apk_report", return_value={**signer, "package": "app.other.customer"}), self.assertRaises(SigningError):
                verify_artifacts(apk, bundle, qa())
            with patch("verify_android_signing.apk_report", return_value={**signer, "package": PACKAGE}), patch("verify_android_signing.certificate_report", return_value={**signer, "certificate_sha256": "3c" * 32}), self.assertRaises(SigningError):
                verify_artifacts(apk, bundle, qa())


@unittest.skipUnless(os.environ.get("MOBISHOP_TEST_JDK"), "Set MOBISHOP_TEST_JDK for disposable JDK signing fixtures.")
class JavaSignatureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.temp.name)
        cls.java_home = Path(os.environ["MOBISHOP_TEST_JDK"])
        cls.env = {**os.environ, **release(), "JAVA_HOME": str(cls.java_home), "CM_KEYSTORE_PATH": str(cls.root / "fixture.jks")}
        cls.command("keytool", "-genkeypair", "-noprompt", "-keystore", cls.env["CM_KEYSTORE_PATH"],
                    "-storepass", "fixture", "-keypass", "fixture", "-alias", "fixture", "-dname", "CN=Disposable CI Fixture", "-keyalg", "RSA", "-validity", "2")
        cls.jar = cls.root / "signed.aab"
        with zipfile.ZipFile(cls.jar, "w") as archive:
            archive.writestr("base/manifest/AndroidManifest.xml", manifest())
            archive.writestr("base/assets/fixture.txt", b"signed fixture")
        cls.command("jarsigner", "-keystore", cls.env["CM_KEYSTORE_PATH"], "-storepass", "fixture", "-keypass", "fixture", str(cls.jar), "fixture")

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    @classmethod
    def command(cls, name, *args):
        binary = cls.java_home / "bin" / (name + (".exe" if os.name == "nt" else ""))
        result = subprocess.run([str(binary), *args], capture_output=True, timeout=60)
        if result.returncode:
            raise AssertionError("Disposable fixture setup failed")

    def test_existing_private_key_and_bundle_share_verified_signer(self):
        key = certificate_report("keystore", Path(self.env["CM_KEYSTORE_PATH"]), self.env)
        bundle = certificate_report("bundle", self.jar, self.env)
        self.assertEqual(key["certificate_sha256"], bundle["certificate_sha256"])
        self.assertEqual(bundle["verified_entries"], 2)

    def test_managed_qa_rebuilds_keep_the_same_real_private_signer(self):
        key_path = self.root / "disposable-qa.p12"
        self.command("keytool", "-genkeypair", "-noprompt", "-storetype", "PKCS12",
                     "-keystore", str(key_path), "-storepass", "android", "-keypass", "android",
                     "-alias", "androiddebugkey", "-dname", "CN=Android Debug,O=Android,C=US",
                     "-keyalg", "RSA", "-validity", "2")
        verifier_env = {"JAVA_HOME": str(self.java_home), "CM_KEYSTORE_PASSWORD": "android", "CM_KEY_PASSWORD": "android", "CM_KEY_ALIAS": "androiddebugkey"}
        signer = certificate_report("keystore", key_path, verifier_env)
        env = {**qa(), "JAVA_HOME": str(self.java_home), "MOBISHOP_REQUIRE_QA_SIGNING": "true",
               "MOBISHOP_QA_CERT_SHA256": signer["certificate_sha256"],
               "MOBISHOP_QA_KEYSTORE": base64.b64encode(key_path.read_bytes()).decode()}
        with patch("tempfile.tempdir", str(self.root)):
            for build in (1, 2):
                prepare(env, self.root / f"qa-env-{build}")
        self.assertTrue(validate_signer(signer, identity(env)))

    def test_wrong_key_password_is_rejected(self):
        with self.assertRaises(SigningError):
            certificate_report("keystore", Path(self.env["CM_KEYSTORE_PATH"]), {**self.env, "CM_KEY_PASSWORD": "wrong"})

    def test_unsigned_addition_is_rejected(self):
        extra = self.root / "extra.aab"
        extra.write_bytes(self.jar.read_bytes())
        with zipfile.ZipFile(extra, "a") as archive:
            archive.writestr("base/assets/unsigned.txt", b"unsigned addition")
        with self.assertRaises(SigningError):
            certificate_report("bundle", extra, self.env)

    def test_tampered_payload_is_rejected(self):
        changed = self.root / "tampered.aab"
        with zipfile.ZipFile(self.jar) as source, zipfile.ZipFile(changed, "w") as target:
            for item in source.infolist():
                target.writestr(item, b"tampered" if item.filename == "base/assets/fixture.txt" else source.read(item))
        with self.assertRaises(SigningError):
            certificate_report("bundle", changed, self.env)

    def test_unsigned_archive_is_rejected(self):
        unsigned = self.root / "unsigned.aab"
        with zipfile.ZipFile(unsigned, "w") as archive:
            archive.writestr("base/manifest/AndroidManifest.xml", manifest())
        with self.assertRaises(SigningError):
            certificate_report("bundle", unsigned, self.env)


if __name__ == "__main__":
    unittest.main()
