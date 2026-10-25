# Published app designs

Central Builder builds can receive a public declarative design at runtime using
the server-owned `APP_DESIGN_UPDATE_URL` build definition. An existing installed
binary needs one upgrade containing this receiver. Legacy builds without the
definition continue using their current design path.

Save the Builder pages, then choose **نشر للموبايل**. Draft saves alone do not
change installed apps. The server stores immutable schema-1 releases; rollback
publishes an older design under a newer revision. New builds use the published
design as their offline baseline when a publication exists.

The receiver checks on foreground/resume and every 30 seconds while foregrounded.
It downloads in the background and applies on the Home route, so checkout,
authentication and other active screens keep their design until returning Home.
It validates the entire bundle, store/platform binding, checksum and size before
applying or caching it. Offline, malformed, oversized, incompatible and stale
responses keep the last valid design; the embedded design remains a fallback.
The public feed contains no customer sessions, credentials or commerce snapshots.
Existing direct store APIs continue owning cart, authentication, stock and prices.

All supported design fields in `AppDesignBundle58` can update this way, including
identity, in-app logos, splash presentation, page settings, headers/footers and
supported Home blocks/selectors. This does not download executable Dart/native
code. New renderer capabilities, permissions, native plugins, launcher icons and
store packaging still require a compatible binary release.

Protocol: HTTPS GET `/v1/app-design/{store-public-uuid}` returns
`{protocol:1, revision:<positive integer>, sha256:<digest>, bundle:<base64 JSON>}`.
The digest is SHA-256 over the UTF-8 base64 string. ETag supports HTTP 304. No
redirects are followed; responses are bounded to 1.5 MB. Cached designs are scoped
to endpoint, platform, origin and embedded binary design.

Focused checks: `live_app_design_test.dart`, `app_design_bundle58_test.dart`,
and `tool/test_native_build_defines81.py`.
