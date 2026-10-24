Native checkout 92 — implementation and verification
===================================================

The Flutter WooCommerce route now uses CheckoutScreen rather than the merchant
checkout WebView. It reads current merchant fields, labels and saved core
addresses through authenticated connector configuration v8. Shipping quotations
and availability still come from the merchant's Store API. Production checkout
does not fall back to a generic form if that configuration is unavailable.

Kashier uses the official Flutter SDK 0.1.4 payment sheet. The merchant server
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
- The SDK displays its card sheet after the protected pending order is created;
  it does not expose card inputs directly below the checkout radio button.
- Shopify/Odoo native checkout parity is not implemented by this change. Existing
  platform paths remain; no all-platform or all-gateway readiness claim is made.
- Custom website JavaScript fields/validation and arbitrary address book plugins
  require supported adapters; copying labels alone cannot reproduce that logic.
- Actual card authorization/capture and iOS runtime have not yet been verified.

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
