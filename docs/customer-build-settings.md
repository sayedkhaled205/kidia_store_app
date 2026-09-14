# Customer build settings

WordPress sends `store_locale` and `push_config_url` as the API's canonical fields.
The portable settings snapshot includes `builder_project=wordpress-plugin` and
`app_icon_url` from the logo selected in the setup wizard. The API must explicitly
validate both snapshot fields: Laravel otherwise strips them when validating
the existing nested snapshot rules.

The API keeps central/legacy requests on their configured branch and routes the
explicit WordPress marker to the plugin branch. It forwards the icon URL as
`APP_ICON_URL` only for WordPress requests. The Codemagic workflow generates native
Android and iOS icon sizes before compiling the Android APK and AAB.

The icon must be a static PNG, JPEG or WebP from the connected store's HTTPS media
origin, at least 128 pixels per side and no larger than 8 MB. External-origin and
private-address redirects are rejected. The full logo is fitted without cropping,
with white padding when needed. All generated files are opaque RGB PNGs. For best
store quality, select a square 1024-pixel source image. Generation runs in the
build checkout and does not replace the template icons committed to this repo.

The signed iOS publishing workflow must run the same generator with its selected
logo before archiving. Generating icon files is not iOS signing or TestFlight.

Validation includes every native icon size, aspect-ratio preservation, opaque
output, malformed images/URLs and the icon embedded in a compiled Android APK.
Image processing uses [Pillow](https://pillow.readthedocs.io/en/stable/reference/ImageOps.html).

## Unified WordPress build contract

The plugin requests `platform=both`, `artifact=zip`, and snapshot
`build_targets=[android,ios]`. The service must explicitly validate these fields
and route this request to `mobishop-dual-release`. Do not deploy the plugin change
before the service supports this contract. Preserve the existing Android workflow
for legacy requests and the central builder.

The service must provide the registered `IOS_BUNDLE_ID`, in addition to the
existing store, Android package, icon, version and authenticated callback values.
The workflow currently uses Kidia's existing Apple distribution profile and rejects
other iOS bundle IDs; other stores need their own signing configuration.

One provider job compiles APK, AAB and signed internal-testing IPA. It verifies
the signed iOS identity and requires all three nonempty artifacts before packaging
`mobishop-build-files.zip` and reporting completion. Cancel that provider job to
stop the combined build. Do not acknowledge cancellation merely by deleting the
WordPress display state; the service must confirm the provider cancellation.

This workflow builds downloadable files without publishing to App Store Connect.
Publishing and export compliance remain separate release steps. France remains
excluded from Kidia's current distribution declaration.
