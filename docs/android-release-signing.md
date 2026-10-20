# Android build identity and signing

`mobishop-release` is explicitly an **Android test build** until a registered
release identity is supplied. Its default `MOBISHOP_ANDROID_BUILD_MODE=qa` uses
Android's debug key. This output is for installation testing, not Google Play.
Both Android+iOS release workflows require `release` mode and cannot downgrade
to QA when credentials are missing. Never replace a published app's existing key.

## Registered release contract

The server must bind the store owner, store UUID and host to the existing Android
package and upload certificate before selecting its secret group. Client input
must not select a certificate, secret group or another store's package. Supply:

- `MOBISHOP_ANDROID_BUILD_MODE=release`
- `ANDROID_APPLICATION_ID`: exact registered package
- `ANDROID_SIGNING_CERTIFICATE_SHA256`: registered upload certificate SHA-256,
  64 hexadecimal characters without separators
- One existing keystore source: `CM_KEYSTORE_PATH` from Codemagic signing
  identities, **or** secret `CM_KEYSTORE` containing its base64 bytes
- Secrets `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS`, `CM_KEY_PASSWORD`

`tool/verify_android_signing.py --prepare --env-file "$CM_ENV"` verifies the
private key is accessible, certificate is current, fingerprint matches the
registration, and subject is not Android Debug. Base64 material is written to a
private, temporary CI file only. It creates no key and writes no secret to logs,
artifacts or Git. An invalid or incomplete registration fails before compilation.
Preflight sets `MOBISHOP_REQUIRE_RELEASE_SIGNING=true` for subsequent build steps.
Local debug development remains available; Gradle release tasks without a key
must explicitly select `qa`, rather than silently falling back to the debug key.

The Android-only workflow can receive `release` mode from the server with those
registered values; its workflow display name remains a conservative test-build
label. Product UI should use the verified build report, not the workflow name or
the words `--release`/`app-release.apk`, to determine signing status.

## Verified artifact report

Before a success callback, CI verifies APK signatures with `apksigner`, exact APK
package with `aapt`, and every AAB payload entry through Java's cryptographic JAR
verifier. It checks the AAB manifest package and requires the APK and AAB to share
the expected signer. Unsigned additions, tampering, foreign packages, mismatched
keys, expired certificates and a debug certificate in release mode are rejected.

`android-build-verification.json` is included in the download ZIP and as its own
artifact. It includes `build_mode`, `test_only`, `release_signing_verified`, a
plain-language notice, package, both artifact hashes and public signer metadata.
A test report prominently says it is not for Google Play distribution. Valid
release signing does not prove Play acceptance, runtime flows, or device testing.
The backend must not mark a build release-ready merely because a callback says
completed; that status means compilation and artifact verification succeeded.

For Play App Signing, the upload certificate and the installed application's
signing certificate may differ. Native Google sign-in must register the correct
package/certificate identities in Firebase/Google, including Play's application
signer where applicable. Do not rotate keys automatically to resolve login or
update failures. New managed identities require an explicit provisioning policy,
secure backup and durable store binding before the first release.

## Version and validation

`STORE_NAME` supplies the launcher label. `ANDROID_APPLICATION_ID` stays the
package identity. Both APK and AAB receive `BUILD_VERSION_NAME` (three numeric
components) and `BUILD_VERSION_CODE` (1..2100000000). Missing both keeps Flutter's
defaults; a partial/invalid request fails. A release code must exceed the last
uploaded code for the same package.

`tool/test_verify_android_signing.py` tests mode isolation, exact identity,
manifest parsing and report classification. Set `MOBISHOP_TEST_JDK` to the JDK
home to also run disposable fixture checks for key access, wrong passwords,
unsigned additions and tampered payloads. No fixture identity is used for a
customer. The GitHub Android release check compiles disposable signed APK/AAB
fixtures and checks actual certificates, package, icon and Arabic launcher label.

References:
- https://docs.codemagic.io/yaml-code-signing/signing-android/
- https://developer.android.com/studio/publish/app-signing
- https://raw.githubusercontent.com/aosp-mirror/platform_frameworks_base/android-16.0.0_r1/tools/aapt2/Resources.proto
