# Kashier SDK runtime snapshot

Upstream: `kashier_flutter_sdk` 0.1.4 from pub.dev, MIT (see LICENSE).
Archive SHA-256 from the previously locked registry dependency:
`299d14aec060f1ddc7fa3da8da6e29c569bd1e6b75b7b16e773692aeb5b09dab`.

Runtime files (lib, assets, ios and package metadata) are unchanged except:

- `lib/src/kashier_connectivity.dart`: share and await the initial connectivity
  future. Upstream sets `_started` before awaiting the platform, allowing the
  first `startPayment` to see the default offline value and fail without opening
  card entry. Concurrent requests now wait for the actual result; offline checks
  and DNS reachability checks remain enforced.
- `lib/src/ui/card/three_ds_webview_sheet.dart`: preserve the original provider
  redirect URL, including `redirectHtml`. The current public Kashier
  `payments.kashier.io/3ds-redirect` component explicitly decodes that parameter
  to start issuer authentication before sending device data. Upstream's July
  workaround stripped it, leaving the October 24 live test blank with
  AUTHENTICATION_IN_PROGRESS. TLS/WAF validation and payment reconciliation are
  unchanged; no merchant HTML or local card-processing implementation is added.
- `lib/src/ui/card/inline_card_form.dart`: adds SDK-owned ephemeral card fields
  that can live below the merchant's native payment selector. The controller
  exposes validation, clearing and payment, not card values. It reuses the SDK's
  formatters, validator, API, card handler and bank challenge widget. It checks
  the exact session currency/amount and current customer before its one payment
  request. Card storage is disabled. The application prepares the protected order
  only after the buyer submits the complete form, and still requires server
  reconciliation before displaying success. The original payment sheet remains
  available for explicit recovery of an existing unpaid order.

Regression tests live in the application's checkout tests. Remove this local
snapshot when an upstream release fixes the race and passes those tests.
