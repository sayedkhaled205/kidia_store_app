"""Explicit test/release Android signing, verified before and after compilation.

No signing key is created here. Release keys come from a registered store's CI
secret group. Reports contain only public certificate and artifact metadata.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import zipfile


class SigningError(ValueError):
    pass


KEY_FIELDS = ("CM_KEYSTORE_PASSWORD", "CM_KEY_ALIAS", "CM_KEY_PASSWORD")
ROOT = Path(__file__).resolve().parents[1]


def identity(environment):
    mode = environment.get("MOBISHOP_ANDROID_BUILD_MODE", "")
    if mode not in ("qa", "release"):
        raise SigningError("An explicit Android qa or release build mode is required.")
    package = environment.get("ANDROID_APPLICATION_ID", "")
    if not re.fullmatch(r"[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+", package):
        raise SigningError("A registered Android package is required.")
    digest = environment.get("ANDROID_SIGNING_CERTIFICATE_SHA256", "").lower()
    credentials = [environment.get(field, "") for field in KEY_FIELDS]
    sources = [environment.get("CM_KEYSTORE_PATH", ""), environment.get("CM_KEYSTORE", "")]
    if mode == "qa":
        if any(credentials + sources) or digest or environment.get("MOBISHOP_REQUIRE_RELEASE_SIGNING") == "true":
            raise SigningError("A test build must not receive release signing credentials or identity.")
        qa_key = environment.get("MOBISHOP_QA_KEYSTORE", "")
        qa_path = environment.get("MOBISHOP_QA_KEYSTORE_PATH", "")
        digest = environment.get("MOBISHOP_QA_CERT_SHA256", "").lower()
        if qa_key or qa_path or digest or environment.get("MOBISHOP_REQUIRE_QA_SIGNING") == "true":
            if sum(bool(value) for value in (qa_key, qa_path)) != 1 or not re.fullmatch(r"[a-f0-9]{64}", digest):
                raise SigningError("A managed test build requires its stable private QA signer and fingerprint.")
    else:
        if any(environment.get(field) for field in ("MOBISHOP_QA_KEYSTORE", "MOBISHOP_QA_KEYSTORE_PATH", "MOBISHOP_QA_CERT_SHA256")):
            raise SigningError("A release build must not receive a QA signing identity.")
        if not re.fullmatch(r"[a-f0-9]{64}", digest):
            raise SigningError("The registered Android upload certificate fingerprint is required.")
        if not all(credentials) or sum(bool(value) for value in sources) != 1:
            raise SigningError("A release build requires one existing keystore and all signing credentials.")
    return {"mode": mode, "package": package, "certificate_sha256": digest}


def run(command, environment=None):
    result = subprocess.run(command, env=environment, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=180)
    if result.returncode:
        raise SigningError("Android signing verification failed; no verified artifact was produced.")
    return result.stdout


def java_tool(environment):
    suffix = ".exe" if os.name == "nt" else ""
    java_home = environment.get("JAVA_HOME")
    return str(Path(java_home) / "bin" / ("java" + suffix)) if java_home else "java"


def certificate_report(operation, path, environment):
    output = run([java_tool(environment), str(ROOT / "tool/VerifyAndroidSigning.java"), operation, str(path)], environment)
    try:
        report = json.loads(output)
        if not re.fullmatch(r"[a-f0-9]{64}", report["certificate_sha256"]):
            raise ValueError()
        return report
    except (ValueError, KeyError, TypeError):
        raise SigningError("The signer report is invalid.") from None


def is_debug_certificate(subject):
    return bool(re.search(r"(?:^|,)\s*CN\s*=\s*Android Debug\s*(?:,|$)", subject, re.I))


def validate_signer(report, expected):
    debug = is_debug_certificate(report.get("subject", ""))
    digest = report.get("certificate_sha256", "").lower()
    if not re.fullmatch(r"[a-f0-9]{64}", digest):
        raise SigningError("The artifact has no verifiable signer fingerprint.")
    if expected["mode"] == "release":
        if debug:
            raise SigningError("An Android Debug certificate cannot sign a release artifact.")
        if digest != expected["certificate_sha256"]:
            raise SigningError("The signer belongs to a different registered Android identity.")
    elif not debug:
        raise SigningError("The test build unexpectedly used a non-debug signing identity.")
    elif expected["certificate_sha256"] and digest != expected["certificate_sha256"]:
        raise SigningError("The test artifact does not match this application's stable QA signer.")
    return debug


def prepare(environment, env_file):
    expected = identity(environment)
    if expected["mode"] == "qa":
        if expected["certificate_sha256"]:
            prepare_qa(environment, env_file, expected)
        print("ANDROID TEST BUILD: for testing only; not signed for Google Play distribution.")
        return
    environment = dict(environment)
    temporary = None
    try:
        if environment.get("CM_KEYSTORE"):
            if not env_file:
                raise SigningError("An environment file is required for the temporary signing key.")
            try:
                data = base64.b64decode(environment["CM_KEYSTORE"], validate=True)
            except ValueError:
                raise SigningError("The registered keystore is not valid base64.") from None
            if not data or len(data) > 1024 * 1024:
                raise SigningError("The registered keystore size is invalid.")
            with tempfile.NamedTemporaryFile(prefix="mobishop-signing-", suffix=".keystore", delete=False) as handle:
                temporary = Path(handle.name)
                handle.write(data)
            temporary.chmod(0o600)
            environment["CM_KEYSTORE_PATH"] = str(temporary)
        path = Path(environment["CM_KEYSTORE_PATH"])
        if not path.is_file():
            raise SigningError("The registered keystore is unavailable in this build.")
        report = certificate_report("keystore", path, environment)
        validate_signer(report, expected)
        if env_file:
            with Path(env_file).open("a", encoding="utf-8", newline="\n") as stream:
                # Codemagic sources this file between steps. It contains no password.
                if temporary:
                    stream.write("CM_KEYSTORE_PATH=" + shlex.quote(str(temporary)) + "\n")
                    stream.write("CM_KEYSTORE=\n")
                stream.write("MOBISHOP_REQUIRE_RELEASE_SIGNING=true\n")
        print("Registered Android release signing identity verified.")
    except Exception:
        if temporary:
            temporary.unlink(missing_ok=True)
        raise


def prepare_qa(environment, env_file, expected):
    if not env_file:
        raise SigningError("An environment file is required for managed QA signing.")
    temporary = None
    try:
        if environment.get("MOBISHOP_QA_KEYSTORE"):
            data = base64.b64decode(environment["MOBISHOP_QA_KEYSTORE"], validate=True)
            if not data or len(data) > 1024 * 1024:
                raise SigningError("The private QA keystore size is invalid.")
            with tempfile.NamedTemporaryFile(prefix="mobishop-qa-", suffix=".p12", delete=False) as handle:
                temporary = Path(handle.name)
                handle.write(data)
            temporary.chmod(0o600)
            path = temporary
        else:
            path = Path(environment["MOBISHOP_QA_KEYSTORE_PATH"])
        if not path.is_file():
            raise SigningError("The private QA signer is unavailable.")
        verifier_environment = dict(environment, CM_KEYSTORE_PASSWORD="android", CM_KEY_ALIAS="androiddebugkey", CM_KEY_PASSWORD="android")
        validate_signer(certificate_report("keystore", path, verifier_environment), expected)
        with Path(env_file).open("a", encoding="utf-8", newline="\n") as stream:
            stream.write("MOBISHOP_QA_KEYSTORE_PATH=" + shlex.quote(str(path)) + "\n")
            stream.write("MOBISHOP_QA_KEYSTORE=\n")
    except Exception as error:
        if temporary:
            temporary.unlink(missing_ok=True)
        if isinstance(error, SigningError):
            raise
        raise SigningError("The private QA signer could not be prepared.") from None


def proto_fields(data):
    """Read only protobuf wire fields needed by AAPT's public XmlNode schema."""
    cursor = 0

    def varint():
        nonlocal cursor
        value = 0
        for shift in range(0, 70, 7):
            if cursor >= len(data):
                raise SigningError("Truncated Android bundle manifest.")
            byte = data[cursor]
            cursor += 1
            value |= (byte & 127) << shift
            if not byte & 128:
                return value
        raise SigningError("Invalid Android bundle manifest encoding.")

    fields = {}
    while cursor < len(data):
        tag = varint()
        number, wire = tag >> 3, tag & 7
        if number == 0:
            raise SigningError("Invalid Android bundle manifest field.")
        if wire == 0:
            value = varint()
        elif wire in (1, 2, 5):
            length = varint() if wire == 2 else (8 if wire == 1 else 4)
            if cursor + length > len(data):
                raise SigningError("Truncated Android bundle manifest field.")
            value = data[cursor:cursor + length]
            cursor += length
        else:
            raise SigningError("Unsupported Android bundle manifest field.")
        fields.setdefault(number, []).append(value)
    return fields


def bundle_package(data):
    # AOSP tools/aapt2/Resources.proto: XmlNode.element=1,
    # XmlElement.name=3/attribute=4, XmlAttribute.name=2/value=3.
    node = proto_fields(data)
    if len(node.get(1, [])) != 1:
        raise SigningError("The bundle has no unique manifest root.")
    element = proto_fields(node[1][0])
    if element.get(3) != [b"manifest"]:
        raise SigningError("The bundle manifest root is invalid.")
    packages = []
    for attribute in element.get(4, []):
        fields = proto_fields(attribute)
        if fields.get(2) == [b"package"] and fields.get(1, [b""]) == [b""]:
            packages.extend(fields.get(3, []))
    if len(packages) != 1:
        raise SigningError("The bundle has no unique package identity.")
    return packages[0].decode("utf-8", errors="strict")


def sdk_tools(environment):
    home = environment.get("ANDROID_HOME") or environment.get("ANDROID_SDK_ROOT")
    if not home:
        raise SigningError("Android SDK verification tools are unavailable.")
    folders = [path for path in (Path(home) / "build-tools").iterdir()
               if re.fullmatch(r"\d+(?:\.\d+)+", path.name)]
    if not folders:
        raise SigningError("Android SDK verification tools are unavailable.")
    return max(folders, key=lambda path: tuple(map(int, path.name.split("."))))


def apk_report(path, environment):
    tools = sdk_tools(environment)
    signature = run([java_tool(environment), "-jar", str(tools / "lib/apksigner.jar"),
                     "verify", "--verbose", "--print-certs", str(path)], environment)
    signer = apk_signer(signature)
    aapt = tools / ("aapt.exe" if os.name == "nt" else "aapt")
    badging = run([str(aapt), "dump", "badging", str(path)], environment)
    packages = re.findall(r"^package: name='([^']+)'", badging, re.M)
    if len(packages) != 1:
        raise SigningError("The APK package identity could not be verified.")
    return {**signer, "package": packages[0]}


def apk_signer(signature):
    # Build Tools 37 reports V2/V3 Signer; older tools report Signer #1.
    prefix = r"^(?:Signer #\d+|V[1-4](?:\.\d+)? Signer(?: #\d+)?:) certificate "
    digests = set(re.findall(prefix + r"SHA-256 digest: ([a-fA-F0-9]+)$", signature, re.M))
    subjects = set(re.findall(prefix + r"DN: (.+)$", signature, re.M))
    counts = re.findall(r"^Number of signers: (\d+)$", signature, re.M)
    if counts != ["1"] or len(digests) != 1 or len(subjects) != 1:
        raise SigningError("The APK must have one verified signing identity.")
    return {"certificate_sha256": digests.pop().lower(), "subject": subjects.pop()}


def verify_artifacts(apk, bundle, environment):
    expected = identity(environment)
    report = {
        "schema_version": 1,
        "build_mode": expected["mode"],
        "test_only": expected["mode"] == "qa",
        "release_signing_verified": False,
        "package": expected["package"],
        "notice": "TEST BUILD — for testing only; not for Google Play distribution." if expected["mode"] == "qa"
                  else "Release signer verified. Store acceptance and device functionality are separate checks.",
        "artifacts": {},
    }
    for kind, path in (("apk", apk), ("aab", bundle)):
        with zipfile.ZipFile(path) as archive:
            if archive.testzip() is not None or len(set(archive.namelist())) != len(archive.namelist()):
                raise SigningError("The Android artifact is corrupt or contains duplicate entries.")
            if kind == "aab":
                certificate = certificate_report("bundle", path, environment)
                manifest = archive.getinfo("base/manifest/AndroidManifest.xml")
                if manifest.file_size > 4 * 1024 * 1024:
                    raise SigningError("The Android bundle manifest is too large.")
                certificate["package"] = bundle_package(archive.read(manifest))
            else:
                certificate = apk_report(path, environment)
        if certificate["package"] != expected["package"]:
            raise SigningError("The artifact package does not match this store's registration.")
        certificate["android_debug_certificate"] = validate_signer(certificate, expected)
        with path.open("rb") as stream:
            certificate["artifact_sha256"] = hashlib.file_digest(stream, "sha256").hexdigest()
        certificate["bytes"] = path.stat().st_size
        report["artifacts"][kind] = certificate
    if report["artifacts"]["apk"]["certificate_sha256"] != report["artifacts"]["aab"]["certificate_sha256"]:
        raise SigningError("The APK and AAB were signed with different keys.")
    report["release_signing_verified"] = expected["mode"] == "release"
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--apk", type=Path)
    parser.add_argument("--aab", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.prepare:
        prepare(os.environ, args.env_file)
    elif args.apk and args.aab and args.output:
        report = verify_artifacts(args.apk, args.aab, os.environ)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(report["notice"])
    else:
        parser.error("Choose --prepare or provide --apk, --aab and --output.")


if __name__ == "__main__":
    try:
        main()
    except (SigningError, OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.TimeoutExpired) as failure:
        # Never print subprocess output or secret configuration.
        raise SystemExit(str(failure) if isinstance(failure, SigningError) else "Android signing verification could not complete.")
