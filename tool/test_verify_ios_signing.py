import copy
from datetime import datetime, timedelta, timezone
import hashlib
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

from verify_ios_signing import SigningError, identity, validate_entitlements, validate_profile, verify_application


class SigningIsolationTest(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 10, 20, tzinfo=timezone.utc)
        self.cert = b"test certificate; no signing material"
        self.env = {
            "IOS_BUNDLE_ID": "com.customer.store",
            "APPLE_TEAM_ID": "AB12345678",
            "IOS_SIGNING_PROFILE_UUID": "12345678-1234-1234-1234-123456789012",
            "IOS_SIGNING_CERTIFICATE_SHA256": hashlib.sha256(self.cert).hexdigest(),
        }
        self.expected = identity(self.env)
        self.profile = {
            "UUID": self.env["IOS_SIGNING_PROFILE_UUID"],
            "TeamIdentifier": [self.expected["team"]],
            "ExpirationDate": self.now + timedelta(days=30),
            "DeveloperCertificates": [self.cert],
            "Entitlements": {
                "application-identifier": "AB12345678.com.customer.store",
                "com.apple.developer.team-identifier": "AB12345678",
                "aps-environment": "production",
                "get-task-allow": False,
            },
        }

    def test_accepts_exact_store_profile(self):
        validate_profile(self.profile, self.expected, self.now)

    def test_other_customer_profile_rejected(self):
        self.profile["Entitlements"]["application-identifier"] = "AB12345678.com.another.store"
        with self.assertRaises(SigningError):
            validate_profile(self.profile, self.expected, self.now)

    def test_wildcard_profile_rejected(self):
        self.profile["Entitlements"]["application-identifier"] = "AB12345678.*"
        with self.assertRaises(SigningError):
            validate_profile(self.profile, self.expected, self.now)

    def test_foreign_team_rejected(self):
        self.profile["TeamIdentifier"] = ["ZZ12345678"]
        with self.assertRaises(SigningError):
            validate_profile(self.profile, self.expected, self.now)

    def test_unregistered_profile_rejected(self):
        self.profile["UUID"] = "87654321-4321-4321-4321-210987654321"
        with self.assertRaises(SigningError):
            validate_profile(self.profile, self.expected, self.now)

    def test_expired_profile_rejected(self):
        self.profile["ExpirationDate"] = self.now - timedelta(seconds=1)
        with self.assertRaises(SigningError):
            validate_profile(self.profile, self.expected, self.now)

    def test_missing_expiry_rejected(self):
        del self.profile["ExpirationDate"]
        with self.assertRaises(SigningError):
            validate_profile(self.profile, self.expected, self.now)

    def test_different_certificate_rejected(self):
        self.profile["DeveloperCertificates"] = [b"another certificate"]
        with self.assertRaises(SigningError):
            validate_profile(self.profile, self.expected, self.now)

    def test_development_entitlement_rejected(self):
        self.profile["Entitlements"]["get-task-allow"] = True
        with self.assertRaises(SigningError):
            validate_profile(self.profile, self.expected, self.now)

    def test_missing_production_push_rejected(self):
        for value in (None, "development"):
            with self.subTest(value=value), self.assertRaises(SigningError):
                self.profile["Entitlements"]["aps-environment"] = value
                validate_profile(self.profile, self.expected, self.now)

    def test_device_only_or_enterprise_profile_rejected(self):
        for key, value in (("ProvisionedDevices", ["test-device"]), ("ProvisionsAllDevices", True)):
            profile = copy.deepcopy(self.profile)
            profile[key] = value
            with self.subTest(key=key), self.assertRaises(SigningError):
                validate_profile(profile, self.expected, self.now)

    def test_signed_entitlements_bound_to_team(self):
        entitlements = copy.deepcopy(self.profile["Entitlements"])
        entitlements["com.apple.developer.team-identifier"] = "ZZ12345678"
        with self.assertRaises(SigningError):
            validate_entitlements(entitlements, self.expected)

    def test_missing_registry_identity_rejected(self):
        for field in self.env:
            with self.subTest(field=field), self.assertRaises(SigningError):
                identity({key: value for key, value in self.env.items() if key != field})

    def test_public_identity_validation(self):
        for key, value in (("IOS_BUNDLE_ID", "invalid;command"), ("APPLE_TEAM_ID", "OTHER"),
                           ("IOS_SIGNING_PROFILE_UUID", "../../profile"),
                           ("IOS_SIGNING_CERTIFICATE_SHA256", "not-a-fingerprint")):
            with self.subTest(key=key), self.assertRaises(SigningError):
                identity(dict(self.env, **{key: value}))

    def test_exported_application_certificate_is_checked_with_codesign_optional_argument(self):
        # Model codesign's optional-argument grammar: the separated prefix is a
        # second input, not the certificate output prefix (GNU getopt_long).
        for leaf in (self.cert, b"wrong leaf certificate"):
            with self.subTest(certificate_matches=leaf == self.cert), tempfile.TemporaryDirectory() as directory:
                app = Path(directory) / "Store.app"
                app.mkdir()
                (app / "Info.plist").write_bytes(plistlib.dumps({
                    "CFBundleIdentifier": self.expected["bundle"], "CFBundleDisplayName": "Store"}))

                def codesign(arguments, failure):
                    if arguments[1] == "--verify":
                        return b""
                    if "--entitlements" in arguments:
                        return plistlib.dumps(self.profile["Entitlements"])
                    extracts = [arg for arg in arguments if arg.startswith("--extract-certificates=")]
                    if len(extracts) != 1 or arguments[-1] != str(app):
                        raise SigningError(failure)
                    Path(extracts[0].split("=", 1)[1] + "0").write_bytes(leaf)
                    return b""

                valid_profile = copy.deepcopy(self.profile)
                valid_profile["ExpirationDate"] = datetime.now(timezone.utc) + timedelta(days=30)
                with patch("verify_ios_signing.run", side_effect=codesign), patch(
                    "verify_ios_signing.decode_profile", return_value=valid_profile
                ):
                    if leaf == self.cert:
                        verify_application(app, self.expected, "Store")
                    else:
                        with self.assertRaisesRegex(SigningError, "another signing certificate"):
                            verify_application(app, self.expected, "Store")


if __name__ == "__main__":
    unittest.main()
