# Customer build settings

## Shared authentication release — 2026-11-17

The shared native runtime is promoted from the tested Kidia 343 source
`72b83bf7e3759ead1e9b498fccc07b0b27474e88`. This promotion changes no Flutter,
Android or iOS application source relative to that tested release. It retains
the existing shared runtime history and applies to subsequent builder builds.
Installed application binaries and published merchant designs are unchanged.

WooCommerce connector 1.46.139 packages the same tested social sign-in, profile
name, account deletion and recovery source. Verified social sign-in completes
without contact enrollment; real customer-edited names remain intact. The
account deletion entry is reachable while the existing server readiness and
confirmation checks remain authoritative.

The public connector download is separate from installed merchant plugins.
Existing stores must install the updated connector and build a new application
to receive native interface changes; Publish alone does not replace app code.
Each merchant retains its own provider credentials and application identities.
Deletion still requires the store's existing enablement and verified central
Auth-project mapping. This release does not enable deletion for unprepared
stores, copy Kidia credentials, or change Shopify/Odoo authentication flows.

Release checks cover the extracted connector, including direct social sign-in,
provider names, management shopping identities and deletion/re-login recovery.
Evidence is kept in the team evidence directory `shared-auth343-20261117`.

## Central builder audit — 2026-10-26

The current API's `CodemagicClient` routes saved central designs carrying
`builder_project=central-builder` and `native_design_revision` to
`codemagic.native_runtime_branch`, defaulting to `codex/unified-mobile-build`.
This final routing rule does not depend on a merchant hostname. It was inspected
in the running server source; no new signed customer build was triggered by this
audit. The older branch configuration and legacy WordPress routing remain in
place for requests without the central design marker.

`mobishop-customer-dual-release` is the reusable signed customer workflow. Each
merchant still needs registered Android/iOS application identities and signing
configuration. The Kidia-specific workflows remain for existing release paths;
their signing profiles must not be treated as credentials for other merchants.

The shared WooCommerce download is `mobi2app-connector` 1.46.100. Its complete
499-file inventory was verified against the source manifest after publication.
It automatically loads the known `Kidia_Shipping_Addresses` provider adapter
when that plugin is present, including existing stores that retain the older
standalone MU adapter. Other address-book plugins need a reusable provider
adapter to the existing shared address filter, not a hardcoded merchant ID.
Publishing the download does not update already installed merchant plugins.

The six compiled merchant contract cases (two each for WooCommerce, Shopify and
Odoo) passed 1,176 tests with no skipped cases. They are offline integration and
widget contracts, not six live merchant purchases. The common CI gate preserves
these checks for subsequent changes. Shopify retains its official checkout
handoff; unsupported gateways/extensions require capability-specific adapters.
Wishlist persistence is local to each device/store, not account synchronization
across devices. Existing native apps receive source fixes through a new build.

Evidence: `docs/evidence/shared-builder-20261026/`.

## Historical WordPress request contract

WordPress sends `store_locale` and `push_config_url` as the API's canonical fields.
The portable settings snapshot includes `builder_project=wordpress-plugin` and
`app_icon_url` from the logo selected in the setup wizard. The API must explicitly
validate both snapshot fields: Laravel otherwise strips them when validating
the existing nested snapshot rules.

The historical API kept central/legacy requests on their configured branch and routed the
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

## Legacy WordPress dual build contract

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
