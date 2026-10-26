# WooCommerce connector release source

This is the canonical source of **Mobi2App Connector for WooCommerce** distributed
to new WooMobile stores. The `mobishop/` directory and `mobishop.zip` are the older
CMS plugin; do not use those packages as replacements for this connector.

Version 1.46.103 fixes customer logout and concurrent session mutations using
per-user database locks and authoritative readback. It also prevents late build
responses from overwriting or cancelling a newer build. Existing stores require
the connector update; publishing its download does not update installed plugins.

Version 1.46.101 adds optional category-name background highlighting to the shared
category schema and response. Existing designs default to no highlight.

Version 1.46.100 includes the known saved-address provider adapter in the shared
package and loads it automatically. It detects `Kidia_Shipping_Addresses`, reads
only the signed-in customer's addresses, retains native Woo billing/shipping
addresses, and coexists with the older MU adapter. There is no domain or merchant
ID condition. Unsupported address-book plugins need one shared adapter for their
published contract; arbitrary metadata is never guessed or scanned. Their
integration point is `mobishop_native_checkout_addresses92`. Publishing this
download does not automatically upgrade plugins already installed on stores.

Build and verify:

```sh
python3 tool/build_woocommerce_connector.py
python3 -m unittest discover -s tool -p test_build_woocommerce_connector.py
unzip -q build/woocommerce/mobi2app-connector-1.46.91.zip -d build/woocommerce
MOBISHOP_CONNECTOR_TEST_ROOT="$PWD/build/woocommerce/mobi2app-connector" \
  php connectors/woocommerce/tests/website-auth-contract-test.php
MOBISHOP_CONNECTOR_TEST_ROOT="$PWD/build/woocommerce/mobi2app-connector" \
  php connectors/woocommerce/tests/native-checkout-setup-contract-test.php
MOBISHOP_CONNECTOR_TEST_ROOT="$PWD/build/woocommerce/mobi2app-connector" \
  php connectors/woocommerce/tests/customer-orders-endpoint-contract-test.php
```

The output is a versioned installable ZIP and `connector-release.json` containing
its SHA256. CI runs the PHP contract against the **packaged** code, covering the
existing customer-session issuer and the restored website authentication bridge.

`source-manifest.json` pins every file in the reviewed release. Connector-specific
files live in `source/`; unchanged assets are read from their pinned paths in
`mobishop/` to avoid duplicating the entire legacy plugin. Source hashes normalize
ordinary text line endings for Windows/Linux, then reconstruct the original
release bytes. Mixed-line-ending files are kept byte-for-byte in `source/`.
Unlisted files never enter the ZIP. An unrelated edit to a shared source fails
packaging until its inclusion is explicitly reviewed.

For a connector change, edit its dedicated source, update the corresponding
`source_sha256` and final-byte `sha256` in the manifest, and bump the version in the
manifest, plugin header/constant, and readme together. If a shared file needs a
connector-specific change, copy it into `source/` and change that manifest entry's
`source` first. Do not edit the legacy plugin merely to change the connector.

The initial manifest preserves all 492 files from the verified 1.46.75 release.
It includes automatic central setup, store data, application state and push
bridges, plus website authentication. Packaging fails if one of these modules or
its registration disappears. Website authentication inherits the store's actual
login methods; it does not invent OTP or social providers for an unconfigured site.

Version 1.46.76 adds native checkout preparation to the existing authorized
central bootstrap. Both existing administrator capabilities and an active
installation license remain required. A random internal deduplication key is
persisted once in a non-autoloaded option before installing the existing four
ledger tables. Explicit server disables and existing external keys are honored;
unowned, mismatched or active partial ledgers fail closed without being reset.
Only owned unused interrupted setup can resume. Public capability reads never
write the key/schema. The central service must verify `enforced: true` on a later
request before announcing checkout readiness. WooCommerce 9.9+ and PHP 8.1+ are
required for this native protection; ordinary website checkout is unchanged.

Version 1.46.78 reads each merchant's enabled gateway names, while Store API
continues to determine availability for the actual cart. An authenticated Native
checkout with empty gateway payment data keeps the single protected pending order
and continues on that merchant's existing order-pay page. The payment-context
dispatcher is isolated only during that guarded request and restored in `finally`;
it cannot invoke a gateway with missing card fields. Core COD, bank transfer,
cheque, free orders and ordinary website checkout keep their existing paths.
No gateway credentials are copied into the builder or app. A hand-off remains
pending until the merchant's payment provider actually updates the order.

Owned-order refresh is read-only. Payment URLs are emitted only for the exact
HTTPS store installation and independently derived configured WooCommerce
order-pay endpoint, with the matching order ID/key. Localized/custom path slugs
are supported; unsafe redirects return empty URL/path fields while retaining
the actual payment status. These stub contract tests do not
represent a live gateway, SMS, email, stock or order creation test.

Use a GitHub release tag `connector-vX.Y.Z` to attach this tested ZIP. The legacy
WordPress.org deployment workflow skips these tags. Directory approval and a
WooMobile distribution deployment remain distinct operations; this workflow does
not bypass either authorization.

Version 1.46.86 preserves the merchant's required address fields and allowed
countries, including per-country state choices. A single allowed country remains
automatic. Native WooCommerce checkout quotes the current destination before the
rest of the contact form is complete, exposes every returned package/rate, and
refreshes totals and available payment methods after selection. It never invents
a postcode or substitutes a free shipping charge for an unavailable quote.
Destination contract checks run against the packaged connector in CI. Successful
local contracts are not evidence of deployment or a successful card charge.

Version 1.46.87 completes the authenticated store notification connection expected by the shared onboarding service. It verifies the exact store token at the fixed central HTTPS origin, stores it without autoloading, binds it to the installed website origin, and reuses it for Firebase config and delivery. Existing licensed transports remain available for older installations. No notification is sent during setup.

Version 1.46.88 transfers the authenticated app basket into the merchant checkout using a 90-second, single-use POST ticket. The scoped Secure/HttpOnly session is revoked with the mobile session and grants no general WordPress login or administrator capabilities. Merchant checkout fields, shipping rules and gateway forms execute inside the app WebView. Card data is handled by the existing merchant gateway, never by a Flutter JavaScript bridge. Unknown prior native dispatches block a new checkout. Existing native and CMS preview transports remain available.

Version 1.46.90 resolves the scoped customer before WooCommerce initializes, including when another extension cached the guest identity early. It rebinds an early guest session handler before basket transfer and removes Flatsome outer header/footer only within the scoped app checkout. Ordinary website sessions and merchant checkout/payment fields remain unchanged. The app also reloads the authenticated customer basket after returning from checkout.

Version 1.46.91 explains an expired scoped checkout after a 403 shipping refresh, removes the stuck loading overlay and asks the customer to reopen checkout. Session expiry, nonce validation and merchant payment processing remain unchanged.

Version 1.46.102 adds an explicit permission callback to the public product
variation route. Both the permission callback and the response handler require a
published variable parent, no password, public catalog/search visibility and
the merchant's storefront visibility rules. Administrator privileges do not
bypass these checks on the public route. Non-public, unrelated and invisible
children are excluded before reading their attributes, prices or images.

`tests/product-variation-public-access-test.php` tests the extracted release in
CI, including the Arabic attribute matrix and stock visibility settings.
`tests/product-variation-public-access-integration.php` runs with WP-CLI
`eval-file` in an isolated local WordPress/WooCommerce installation. Skip the
installed connector, set `MOBISHOP_CONNECTOR_TEST_ROOT` to the extracted release,
and run it with a test administrator present. It uses actual REST dispatch for
anonymous and administrator callers and rolls back its database fixtures.
