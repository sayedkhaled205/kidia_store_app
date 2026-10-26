# Discount Rules integration

The merchant Discounts workspace reuses the authenticated central Store Data
proxy. It defaults to FlyCart rules and retains a separate WooCommerce coupons
view. Search, type, status and pagination are read-only. Raw customer targeting,
conditions and usage records are never exported. Changes to rules are made in
the website's existing plugin administration.

Catalogue and variation display prices use FlyCart's own quantity-one quote.
Currency precision, zero prices, shop tax display and variable-product ranges
are preserved. Cart pricing is not reimplemented: WooCommerce/FlyCart calculate
conditional, quantity, set, cart and gift discounts. Automatic gifts expose a
non-editable quantity in the native cart contract. Negative cart fees are shown
as discounts by the updated native UI without changing server totals.

The rule summary and server catalogue integration do not need a fresh APK.
The native negative-fee label is included in subsequent app builds. Public
catalogue prices use the public request context; customer-specific/cart-only
rules are finalized in the authenticated cart. FlyCart's optional website-only
manual gift-choice HTML is not a native gift picker. Automatic gift rules are
covered; do not describe every third-party storefront widget as supported.

## Validation

- Standalone PHP: price boundaries, currency, variable ranges, authorization,
  escaping, date/status rules, amount meaning and public variation access.
- Builder JS: direct tab, same-frame switching, pagination/filter reset and
  message-origin rejection (fake server).
- Flutter: cart and checkout widget tests, including negative fees.
- `tool/test-discount-rules-staging.php`: staging-only transactional products,
  in-memory isolated rules, no orders or rule writes, rollback in finally.
  Run each case/quantity in a separate WP-CLI process because FlyCart caches
  calculations for the request. Compare first/repeated totals, expected offer
  totals and the real Woo Store API schema. Cases: none, simple, zero, bulk,
  cart, set, bxgx and bxgy; quantities 1–4.
- `tool/test-discount-rules-access.php`: read-only installed-route check for
  an authorized merchant and anonymous rejection.

Deploy connector additions with `install-discount-connector.py` using reviewed
baseline/candidate files and hash-checked backups. Stage the builder against
its current index/assets with `publish-discounts.py`, visually check its review
page, then activate only if all original and staged hashes still match.
