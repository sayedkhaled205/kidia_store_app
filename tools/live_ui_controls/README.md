# Published page UI controls

The 32 fields in `schema.json` extend the existing live-design release. They are
stored in the authenticated Builder draft at `builder.ui_controls_v1`, and are
only exposed publicly after the owner publishes a release. Saving is separate
from publishing. Each save checks a digest under a store row lock so an old tab
cannot silently overwrite a newer edit. Other store settings remain intact.

The release encodes these values under `pages.home.settings.ui_controls_v1`.
Older schema-1 applications ignore the optional settings. New applications read
the same accepted/cached release as the rest of the page design. An update of
the application binary is required once to introduce these new controls.

Supported presentation: auth background, title size/color, margins, input
radius/padding, continue-button height, logout dimensions, cart badge pulse,
and localized auth/cart/logout copy. Original values remain the defaults;
Google sign-in, OTP/account selection, prices, quantities and checkout rules
are unchanged. There is no remote executable code or arbitrary route command.

Server source is under `backend/`. Its schema copy must match `schema.json` and
the Dart contract in `lib/core/app_design/app_ui_control_schema.dart`. Include
`page-controls.js` after the Builder shell is loaded. The old modal asset is retired. Existing publication
and rollback UI handles the resulting release exactly like other saved designs.

Validation performed: Dart controls and reduced-motion tests, existing native
auth/account/cart behavior tests, and the transaction-only `backend-test.php`
covering strict values, stale writes, owner scope, draft isolation, publishing,
and rollback. The backend test rolls back all test changes.

## Builder page integration

Controls now live in their existing editor pages rather than a toolbar dialog:

- Account: sign-in card and existing Logout Button card (21 controls).
- Home: Fixed Header / cart counter animation (3 controls).
- Checkout: cart text card (8 controls).

The normal Save Page Layout / Save Home Layout / Save Checkout action calls
`await window.MobiShopPageControls.save(sender)` before the existing page save.
`sender` is the already authenticated/validated active editor iframe in the
central `kidia:save` handler. A missing controls module must stop this save on
those three pages, rather than silently reporting success without saving them.
Do not call the helper from theme application or other bulk state writes.

Inputs have no form names, keeping the existing layout serialization and save
receipt comparison intact. The controls helper saves only changed fields,
merging unrelated fields from the latest draft and rejecting conflicting edits
to the same field. A failure stops the page save and uses its existing error UI.
Controls and page layout are separate requests; if the latter fails, retrying
preserves the already saved controls. Saving still does not publish a release.
No data migration or application rebuild is required for this editor relocation.
