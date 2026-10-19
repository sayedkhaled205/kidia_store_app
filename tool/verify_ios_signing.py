"""Validate a store's registered Apple identity before signing and after export.

Secrets come only from a store-specific Codemagic secret group. Neither signing
material nor command output containing it is printed. Requires macOS for CMS,
keychain and codesign operations; pure validation is exercised on every host.
"""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import os
from pathlib import Path
import plistlib
import re
import stat
import subprocess
import tempfile
import uuid
import zipfile


class SigningError(ValueError):
    pass


def identity(environment):
    fields = {
        "bundle": environment.get("IOS_BUNDLE_ID", ""),
        "team": environment.get("APPLE_TEAM_ID", ""),
        "profile": environment.get("IOS_SIGNING_PROFILE_UUID", ""),
        "certificate": environment.get("IOS_SIGNING_CERTIFICATE_SHA256", "").upper(),
    }
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", fields["bundle"]):
        raise SigningError("A registered iOS bundle identifier is required.")
    if not re.fullmatch(r"[A-Z0-9]{10}", fields["team"]):
        raise SigningError("A registered Apple team is required.")
    try:
        fields["profile"] = str(uuid.UUID(fields["profile"])).upper()
    except ValueError:
        raise SigningError("A registered provisioning profile UUID is required.") from None
    if not re.fullmatch(r"[A-F0-9]{64}", fields["certificate"]):
        raise SigningError("A registered signing certificate fingerprint is required.")
    return fields


def validate_profile(profile, expected, now=None):
    now = now or datetime.now(timezone.utc)
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, datetime):
        raise SigningError("The signing profile has no valid expiry date.")
    if expiry.replace(tzinfo=timezone.utc) <= now:
        raise SigningError("The signing profile has expired.")
    if str(profile.get("UUID", "")).upper() != expected["profile"]:
        raise SigningError("The signing profile does not match this store's registration.")
    if profile.get("TeamIdentifier") != [expected["team"]]:
        raise SigningError("The signing profile belongs to a different Apple team.")
    entitlements = profile.get("Entitlements", {})
    validate_entitlements(entitlements, expected)
    if profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices"):
        raise SigningError("An App Store distribution profile is required.")
    fingerprints = {
        hashlib.sha256(cert).hexdigest().upper()
        for cert in profile.get("DeveloperCertificates", []) if isinstance(cert, bytes)
    }
    if expected["certificate"] not in fingerprints:
        raise SigningError("The registered certificate is not authorized by this profile.")


def validate_entitlements(entitlements, expected):
    if entitlements.get("application-identifier") != expected["team"] + "." + expected["bundle"]:
        raise SigningError("The signing identity belongs to another application.")
    if entitlements.get("com.apple.developer.team-identifier") != expected["team"]:
        raise SigningError("The signed application has the wrong Apple team.")
    if entitlements.get("aps-environment") != "production":
        raise SigningError("The application needs production push notification entitlement.")
    if entitlements.get("get-task-allow") is not False:
        raise SigningError("A development signing profile cannot be distributed.")


def run(arguments, failure, environment=None):
    result = subprocess.run(arguments, capture_output=True, env=environment)
    if result.returncode:
        raise SigningError(failure)
    return result.stdout


def decode_profile(path):
    return plistlib.loads(run(["security", "cms", "-D", "-i", str(path)],
                             "The provisioning profile could not be verified."))


def secret_bytes(environment, key):
    try:
        value = base64.b64decode(environment.get(key, ""), validate=True)
    except (ValueError, TypeError):
        raise SigningError("The store's signing secret is missing or invalid.") from None
    if not value or len(value) > 2 * 1024 * 1024:
        raise SigningError("The store's signing secret is missing or invalid.")
    return value


def install(environment):
    expected = identity(environment)
    with tempfile.TemporaryDirectory(prefix="mobishop-signing-") as directory:
        root = Path(directory)
        profile_path = root / "profile.mobileprovision"
        certificate_path = root / "certificate.p12"
        profile_path.write_bytes(secret_bytes(environment, "CM_PROVISIONING_PROFILE"))
        certificate_path.write_bytes(secret_bytes(environment, "CM_CERTIFICATE"))
        profile_path.chmod(0o600)
        certificate_path.chmod(0o600)
        validate_profile(decode_profile(profile_path), expected)
        child_environment = dict(environment)
        child_environment.setdefault("CM_CERTIFICATE_PASSWORD", "")
        pem = run(["openssl", "pkcs12", "-in", str(certificate_path), "-clcerts", "-nokeys",
                   "-passin", "env:CM_CERTIFICATE_PASSWORD"],
                  "The store's distribution certificate could not be opened.", child_environment)
        pem_path = root / "certificate.pem"
        pem_path.write_bytes(pem)
        pem_path.chmod(0o600)
        der = run(["openssl", "x509", "-in", str(pem_path), "-outform", "DER"],
                  "The distribution certificate is invalid.")
        if hashlib.sha256(der).hexdigest().upper() != expected["certificate"]:
            raise SigningError("The signing certificate belongs to a different registration.")
        run(["openssl", "x509", "-in", str(pem_path), "-checkend", "0", "-noout"],
            "The signing certificate has expired.")
        run(["keychain", "initialize"], "The isolated signing keychain could not be prepared.")
        run(["keychain", "add-certificates", "--certificate", str(certificate_path),
             "--certificate-password", child_environment["CM_CERTIFICATE_PASSWORD"]],
            "The signing certificate and private key could not be imported.")
        destination = Path.home() / "Library/MobileDevice/Provisioning Profiles"
        destination.mkdir(parents=True, exist_ok=True)
        installed = destination / (expected["profile"] + ".mobileprovision")
        installed.write_bytes(profile_path.read_bytes())
        installed.chmod(0o600)
    print("Registered store signing material verified and installed.")


def verify_application(app, expected, name):
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != expected["bundle"] or info.get("CFBundleDisplayName") != name:
        raise SigningError("The exported application identity does not match this store.")
    run(["codesign", "--verify", "--deep", "--strict", str(app)],
        "The exported application's code signature is invalid.")
    entitlements = plistlib.loads(run(["codesign", "-d", "--entitlements", ":-", str(app)],
                                     "The exported application's entitlements could not be read."))
    validate_entitlements(entitlements, expected)
    validate_profile(decode_profile(app / "embedded.mobileprovision"), expected)
    with tempfile.TemporaryDirectory(prefix="mobishop-leaf-") as directory:
        prefix = str(Path(directory) / "certificate")
        run(["codesign", "-d", "--extract-certificates", prefix, str(app)],
            "The exported application's signing certificate could not be read.")
        certificate = Path(prefix + "0").read_bytes()
        if hashlib.sha256(certificate).hexdigest().upper() != expected["certificate"]:
            raise SigningError("The exported application uses another signing certificate.")


def verify_ipa(path, environment):
    expected = identity(environment)
    with tempfile.TemporaryDirectory(prefix="mobishop-ipa-") as directory:
        root = Path(directory).resolve()
        with zipfile.ZipFile(path) as archive:
            for member in archive.infolist():
                destination = (root / member.filename).resolve()
                if not destination.is_relative_to(root):
                    raise SigningError("The application archive contains an invalid path.")
                if stat.S_ISLNK(member.external_attr >> 16):
                    target = archive.read(member).decode("utf-8")
                    if not (destination.parent / target).resolve().is_relative_to(root):
                        raise SigningError("The application archive contains an invalid link.")
        # ditto preserves executable modes and framework symlinks in signed apps.
        run(["ditto", "-x", "-k", str(path.resolve()), str(root)],
            "The exported application could not be extracted for verification.")
        apps = list((root / "Payload").glob("*.app"))
        if len(apps) != 1:
            raise SigningError("The application archive must contain one iOS application.")
        verify_application(apps[0], expected, environment["STORE_NAME"])
    print("Exported IPA signature, store identity and production push entitlement verified.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--install", action="store_true")
    action.add_argument("--ipa", type=Path)
    args = parser.parse_args()
    try:
        install(os.environ) if args.install else verify_ipa(args.ipa, os.environ)
    except (SigningError, OSError, plistlib.InvalidFileException, zipfile.BadZipFile) as error:
        # Never echo secret inputs, signing command output or certificate bytes.
        raise SystemExit(str(error) if isinstance(error, SigningError) else "Apple signing verification failed.") from None
