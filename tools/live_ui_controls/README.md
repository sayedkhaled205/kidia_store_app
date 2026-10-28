# Published page UI controls

The 73 fields in `schema.json` extend the existing live-design release. They are
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
localized auth/cart/logout copy, and public support WhatsApp/email with explicit
visibility switches. Empty contacts retain the compiled fallback; disabling a
channel hides it. URI-looking email values are rejected on server and client.
Original values remain the defaults;
Google sign-in, OTP/account selection, prices, quantities and checkout rules
are unchanged. There is no remote executable code or arbitrary route command.

Server source is under `backend/`. Run `python tool/generate_app_ui_controls.py`
after changing `schema.json`; `--check` verifies its server and Dart copies in CI.
Include
`page-controls.js` after the Builder shell is loaded. The old modal asset is retired. Existing publication
and rollback UI handles the resulting release exactly like other saved designs.

Validation performed: Dart controls and reduced-motion tests, existing native
auth/account/cart behavior tests, and the transaction-only `backend-test.php`
covering strict values, stale writes, owner scope, draft isolation, publishing,
and rollback. The backend test rolls back all test changes.

## Builder page integration

Controls now live in their existing editor pages rather than a toolbar dialog:

- Account: sign-in, existing Logout Button and public support and order-thumbnail cards (31 controls).
- Home: Fixed Header / cart counter animation and messages (7 controls).
- Checkout: cart text and appearance cards (35 controls).

The 15 cart appearance controls select the existing theme/classic/compact layout,
side padding, item gap, image dimensions/radius, name font size/line count,
checkout button dimensions/radius/font size, coupon/summary expansion and empty
cart icon/spacing. Blank numeric fields inherit the current layout; zero is a
valid radius. Their choices and numeric limits are validated on server and app.
They require a compatible baseline app once; subsequent edits use Publish.
They do not change quantities, discounts, prices, checkout or customer accounts.

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

## Checkout and Odoo coverage

The saved `checkout_design` field is projected separately into
`pages.home.settings.checkout_presentation_v1.design`, restricted to `classic`,
`summary_first`, or `compact`. Native WooCommerce and Odoo checkout consume it.
Shopify's official checkout retains Shopify's own presentation. Checkout fields,
customer addresses, shipping prices and gateways are never copied to a public
design: their current connector APIs remain authoritative.

Odoo account consumes its saved CMS page chrome, content padding, summary/menu
visibility and styling, avatar/email/guest text, logout controls, live app name
and auth presentation. Odoo authentication and customer transports stay separate.
Publishing no longer replays completed app startup. Existing safe-route update
deferral, cache validation, store isolation and rollback behavior remain in place.

See `docs/live-publication-coverage.md` for scope and native-version limits.

The additional 22 controls cover notification-message appearance (theme/soft/
brand, radius, inset, type size), native checkout field/button/address dimensions,
order thumbnail dimensions and radius, the Google button height, and localized
identifier placeholders. Optional sizes inherit the current theme when cleared.
Checkout validation, saved data, provider authentication and payment logic are
unchanged. These consumers require a new baseline binary before publication can
affect an older installation. The server's field-count bound follows the schema.

## cPanel Nginx deployment

The API host's generated default `location /` enables `proxy_cache`. Nginx then
removes the original conditional headers before forwarding, even when the
application response is not cacheable. This made every native design poll
return the full payload instead of 304. See the official proxy module docs:
https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_set_header

Install `nginx-live-design.conf` in the API domain's existing custom include
folder (on this host, `/etc/nginx/conf.d/users/woomobile/api.woomobile.app/`).
Check the generated vhost includes that directory and provides the existing
`$CPANEL_APACHE_PROXY_PASS` variable. Run `nginx -t` before a graceful reload.
The include changes only `/v1/app-design/`, retains cPanel's proxy header rules,
and lets Laravel handle revalidation. Do not edit cPanel's generated vhost or
disable caching globally. Roll back by renaming this include to a non-`.conf`
extension, validating configuration, then reloading Nginx.

Verified on 29 October 2026: the controller received no conditional header
before this change; afterward 18 live native-style conditional reads (maximum
three simultaneous) all returned 304 with zero body bytes. Median round trip
was 0.441 s, maximum/p95 0.714 s. The initial 200 response was 99,341 uncompressed
bytes. This is a small connectivity/revalidation check, not a capacity test.
The temporary diagnostic hook was removed and original source hash restored.