# Android release signing

The existing staging builder can create an APK with Android's debug certificate
when no release keystore is configured. That output is for testing, not store
submission. Never replace an existing published application's signing identity.

For a store build, configure Codemagic's secure Android signing integration with
the established upload key. Supply its `CM_KEYSTORE_PATH`, `CM_KEYSTORE_PASSWORD`,
`CM_KEY_ALIAS`, and `CM_KEY_PASSWORD` environment variables and set
`MOBISHOP_REQUIRE_RELEASE_SIGNING=true`. The Gradle build rejects incomplete
credentials and refuses a required release-signing build with no key. Keep the
keystore and passwords outside Git. This repository contains no production key.

`STORE_NAME` is passed to both Flutter and the Android launcher label;
`ANDROID_APPLICATION_ID` remains the Android package identity. The build service
must also select the approved version name and increasing version code before a
store release; current defaults alone do not guarantee valid update numbering.

The Android release check generates an ephemeral CI-only key, compiles an APK,
and checks the resulting signature, package, and Arabic launcher label. It does
not produce a store-signed Kidia release or upload to a store.

Reference: https://docs.codemagic.io/yaml-code-signing/signing-android/
