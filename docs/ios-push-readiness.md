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
