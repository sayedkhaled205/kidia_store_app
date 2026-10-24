Native checkout 92 — implementation and verification
===================================================

The Flutter WooCommerce route now uses CheckoutScreen rather than the merchant
checkout WebView. It reads current merchant fields, labels and saved core
addresses through authenticated connector configuration v8. Shipping quotations
and availability still come from the merchant's Store API. Production checkout
does not fall back to a generic form if that configuration is unavailable.

Kashier uses the pinned Flutter SDK 0.1.4 runtime, with the documented inline
card-form extension. The merchant server
creates one durable session per protected unpaid order, retaining its credentials.
The SDK owns card entry and bank 3DS; it does not render the merchant checkout.
Callbacks do not mark orders paid. Server reconciliation requires the exact
merchant, session, order reference, currency, total and successful capture.
Timeouts and expired/changed attempts require review, not an automatic second
provider session. Offline methods retain WooCommerce's original processing.

This is a shared WooCommerce connector, with no Kidia origin or merchant ID in
the adapter. Unrecognized payment gateways are not presented as native-capable.
Address book extensions can supply current-customer rows via the documented
mobishop_native_checkout_addresses92 filter; core billing/shipping are included.

Limitations still requiring work/acceptance:
- Shopify/Odoo native checkout parity is not implemented by this change. Existing
  platform paths remain; no all-platform or all-gateway readiness claim is made.
- Custom website JavaScript fields/validation and arbitrary address book plugins
  require supported adapters; copying labels alone cannot reproduce that logic.
- iOS runtime has not yet been verified. See the verified Android capture below.

Local verification: Flutter analyzer clean; 577 Flutter tests passed, 4 existing
tests skipped. Packaged PHP contracts cover native payment, tenant isolation,
international destination fields and the existing 59 checkout safety / 10
payment dispatch cases. Real merchant/device verification remains separate.

AGP 9 dependency compatibility
-----------------------------
Build 54 reached Android compilation after passing analysis/tests but failed in
InAppWebView Android 1.1.3 on its legacy proguard-android.txt reference. The shared
settings script generates a version-checked copy using proguard-android-optimize.txt,
matching the upstream fix. The global pub cache is not changed. Local Gradle help
and the plugin release AAR compilation/R8 both pass. Recheck/remove this scoped
patch when upgrading InAppWebView; do not globally disable the R8 compatibility
check. Build 55 uses source 7eb09746 for full application validation.

Connector 1.46.93 additionally requires the persisted guarded checkout attempt
to be complete, successful and owned by the same customer/order before issuing
a provider session. The packaged PHP suite passes all 29 native-payment cases.
# Runtime verification, 2026-10-24

Build 55 / Android version code 32 was installed over the existing QA app.
Saved addresses and merchant-labelled Flutter fields were visible. Cairo shipping
55 EGP changed to outskirts 60 EGP (totals 70/75), and selecting Beheira changed
the method to Delta governorates at 60 EGP. Restoring Cairo restored 55 EGP.
COD and card selection worked; no COD order was submitted.

One explicitly authorized live card test created pending order 650809 at 70 EGP.
Kashier's native card fields rendered inside the application. The user submitted
the card; the bank verification view became blank. The provider reported
INITIATED / AUTHENTICATION_IN_PROGRESS and captured amount 0 at inspection.
This is **not a completed payment test**. Do not automatically retry, reset its
ledger, or create a second payment. Subsequent settlement remains authoritative.

The first SDK launch also exposed an upstream connectivity startup race. The
pinned local SDK runtime snapshot waits for initialization; regression tests
cover a delayed platform response and callback failures/cancellation. Failure
also reconciles the existing order and remains visible to the user.
The bank challenge snapshot also preserves the provider-supplied redirectHtml
parameter. Kashier's current public 3ds-redirect component requires it to start
issuer authentication. A widget regression checks the exact URL handed to the
native WebView. A new live runtime attempt is still needed; no capture has been
verified from this source change alone.

Build 56 / Android version code 33 installs with the expected release signature.
The first native payment-sheet launch and card form work after a cold start.
The user's next real attempt still produced a blank bank verification view.
Both provider records remained INITIATED, AUTHENTICATION_IN_PROGRESS, with zero
captured/refunded/authorized totals. No successful charge has been verified.

The emulator uses Google WebView 124.0.6367.219. Read-only CORS preflight checks
to Kashier's device endpoint return 404 without ACAO for both Android and desktop
Chromium 124, while Chromium 141 returns 204 with ACAO. Updating the actual signed
WebView is the next runtime check; user-agent spoofing or disabling protections
is not an acceptable fix. No payment was retried by the agent.

Connector 1.46.94 handles Kashier's multiple authentication rows for one session.
It accepts exactly one matching full capture alongside uncharged authentication
attempts with zero authorized/refunded/captured totals. Conflicting identity,
currency, money, successful monetary operations, duplicate captures, missing
monetary evidence and multiple successful pay/capture transactions require review.
All 48 payment contract cases pass, including the original durable-session guard.
Broader packaged checks pass except two existing Kids-theme snapshot expectations,
which fail identically against unchanged 1.46.93. Native authentication passes all
300 checks with the local OpenSSL extension enabled.

Verified live payment, 2026-10-24
-------------------------------
After installing Google's signed WebView 134.0.6998.135 on the QA emulator,
the user completed bank verification for order 650814 in Build 56. The provider
reported CAPTURED 70 EGP with one successful pay transaction and approved 3DS.
WooCommerce independently reported paid=true, status=processing, total=70 and
shipping=55 with kashier_card. The SDK displayed its Arabic success screen.
The earlier order 650809 remained unpaid with an expired session; it was not
automatically retried. No refund or cancellation was performed.

Inline checkout 95
------------------
For any merchant advertising the verified Kashier native adapter, selecting the
card method now reveals the SDK-owned number, expiry, security-code and name
fields immediately. Rounded white inputs and a light-gray payment accordion
match the requested visual reference. Merchant address labels, field requirements,
shipping calculation and payment availability remain authoritative.

One "Pay and place order" action validates all fields before order creation,
prepares the durable pending order in the background, and submits its exact
payment session once. There is no intermediate order-created screen. Only an
authenticated, reconciled paid state displays success and records purchase
analytics. Cancellation or an uncertain result retains that same order for
explicit recovery. Double taps, changed customer/store context, and mismatched
session totals do not create another payment. Card fields stay inside the SDK,
are never included in merchant requests or analytics, and clear on method change
or payment dispatch. Offline checkout retains its existing behavior.

Local verification: all 109 checkout tests pass, including 15 new inline/payment
contract cases; targeted analysis is clean. The prior live capture validates the
underlying provider/bank path, not an end-to-end charge from this new form.

Build 57 / Android version code 34 (runtime source 9695f433) passed the CI
analysis/tests/design preflight and produced verified APK/AAB artifacts. Installed
over Build 56 with login and basket preserved. Device checks confirmed saved
addresses and rounded fields, Cairo shipping 55 / total 70 EGP, card fields
directly below selection, COD collapsing the card fields, and the single payment
confirmation button. Empty-card submission stays on the form with field errors.
No new real charge was submitted during this UI review. Four additional SDK
tests intercept all HTTP calls and cover capture, decline, changed totals and
changed customer without transmitting test card values to an external service.

Merchant shipping policy 96
---------------------------
Connector 1.46.97 extends native schema version 8 with
`shipping.allow_different_address`, derived from WooCommerce shipping enablement,
the merchant's billing-only destination setting, and the normal shipping-address
suppression filter. It does not infer permission from a REST request's empty cart.
The app additionally checks whether the actual basket needs shipping. Unknown
policy stays hidden; both legacy and dynamic forms honor explicit permission.
Stored old shipping addresses cannot reactivate a disabled option or leak into
shipping quotes/orders, including after cart refresh and rejected-order recovery.

Each checkout opening reads the current filtered WooCommerce fields and shipping
policy with no-store responses. Labels, placeholders, required flags, options and
removed fields remain merchant-owned. The version remains 8 for installed clients;
the updated app also avoids legacy synthetic billing fields for future versions.
No merchant name, governorate label or shipping rate is
hardcoded in the shared connector/application.

120 checkout tests pass, including seven schema/policy regressions; 11 packaged
PHP merchant-schema checks, six destination checks and 14 package tests pass.
Full lib/test analysis is clean. Android QA Build 58 (versionCode 35, runtime
commit 3e518c30) passed CI and was installed over Build 57 on the API 35 emulator.
The native screen shows the current merchant governorate label and saved
addresses, hides the disabled separate-address switch, retains merchant shipping
rates (55/60 EGP), and opens inline card fields before the single payment/order
button. The existing basket total remains 70 EGP. No order or payment was
submitted during this policy verification. APK/AAB hashes match the build
manifest, the APK signer matches the existing QA installation, and no runtime
errors were observed. Connector 1.46.97 is deployed to the merchant and shared
customer download; the public package hash matches the source-built artifact.
This implementation covers the WooCommerce connector; it does not certify
arbitrary site JavaScript or native checkout parity for Odoo/Shopify.
