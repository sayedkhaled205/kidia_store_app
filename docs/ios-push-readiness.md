# iOS push release checks

The Flutter client requests `push/config?platform=ios`, initializes Firebase with
the public iOS SDK values, and waits up to 30 seconds for an APNs token before
requesting an FCM token. Android remains the default for older clients. WordPress
caches both platform configurations separately and rejects cross-platform app IDs.

The Runner target includes push entitlements and background fetch/remote
notifications. Debug uses the development APNs environment; Release and Profile
use production. Distribution signing must verify the final signed entitlement
against the selected provisioning profile.

Before TestFlight:

- Set the real bundle ID to match Firebase's `iosBundleId` and the Apple App ID.
- Enable Push Notifications for that App ID and regenerate the signing profile.
- Configure the matching Apple team and distribution certificate/profile.
- Upload the team's APNs authentication key to the app's Firebase project.
- Build and sign the store-specific iOS app; the unsigned CI fixture is not an IPA.
- On a physical iPhone, grant permission, confirm a registered `ios` device, and
  test notification delivery/opening in foreground, background and terminated states.
- Test denied permission and unavailable APNs: app startup must remain usable.
  If APNs is unavailable during the bounded startup wait, retry on the next launch.

Firebase project readiness and the server's validate-only FCM test do not prove
APNs credentials, signing, or actual delivery to an iPhone.

## Customer release contract

The generic `mobishop-customer-dual-release` workflow contains no default store,
Apple team, certificate or profile. The server selects it only for a registered
signing identity bound to the store UUID, owner, website host and Firebase iOS
bundle. The separate existing staging workflow remains a compatibility fixture;
its successful IPA cannot establish readiness for a different customer.

The server's registration records these public values:

- `workflow_id`: `mobishop-customer-dual-release`.
- `signing_group`: the store's Codemagic secret environment group.
- `bundle_id`, `team_id`, `profile_uuid`, `certificate_sha256`.
- `verified_at`, `expires_at` and an explicit enabled state.

Build dispatch supplies `environment.groups` with that single selected group,
and public variables `IOS_BUNDLE_ID`, `APPLE_TEAM_ID`,
`IOS_SIGNING_PROFILE_UUID`, `IOS_SIGNING_CERTIFICATE_SHA256`. They accompany the
existing store URL, name, version and public app design variables. A missing or
expired registration blocks iOS dispatch before a paid build is started. It does
not block a correctly configured Android-only build.

The selected secret group contains `CM_PROVISIONING_PROFILE` (base64 profile),
`CM_CERTIFICATE` (base64 distribution P12) and optional
`CM_CERTIFICATE_PASSWORD`. These secrets never enter the app design, public
request metadata, repository, or build artifacts. API callers cannot select an
arbitrary secret group or override the registered identity.

`tool/verify_ios_signing.py --install` verifies the exact profile UUID, bundle,
team, expiration, production APNs entitlement, App Store distribution type and
certificate fingerprint before importing the certificate into the isolated
build keychain. `--ipa` verifies the exported application again, including its
code signature, embedded profile, entitlements and actual leaf certificate.
Checking only an archive before export is insufficient. Validation failures
stop the release and do not publish an unsigned or differently signed IPA.

Keep these readiness signals distinct:

- `ios_config_ready`: Firebase SDK configuration exists for the exact bundle.
- `ios_signing_ready`: a valid registered Apple signing identity exists.
- `ios_push_ready`: an APNs credential is verified for that same Apple team,
  Firebase project and iOS bundle. A config file is not this evidence.
- Device delivery: independently confirmed on an iPhone, with permission,
  foreground/background/terminated handling and notification destinations.

Connecting a commerce store cannot create an Apple Developer membership,
accept Apple's agreements, or infer permission to reuse another team's identity.
Those account prerequisites must already be provisioned by the service or be
connected once by the authorized account owner. Store catalog connection and
Android readiness should continue while iOS prerequisites are pending.

References: [Codemagic white-label builds](https://docs.codemagic.io/yaml-quick-start/white-label-getting-started/),
[Codemagic signing methods](https://docs.codemagic.io/yaml-code-signing/alternative-code-signing-methods/),
[Firebase Flutter iOS prerequisites](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).
