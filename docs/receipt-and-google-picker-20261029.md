# Order receipt and customer identity

Completed checkouts now display a receipt with the owned order number, total,
saved payment/delivery method labels, product thumbnails and quantities. Continue
shopping returns Home; View order details opens that exact order. Both direct
card success and the verified order continuation use the same presentation.
Missing details offer a read-only retry. Pending/failed/unverified payment keeps
the existing continuation and never becomes a successful receipt.

The optional connector labels are backward compatible. Customer addresses,
private notes and credentials remain excluded. Receipt reads are scoped to the
current authenticated customer; no request creates another order or payment.

Account headers hide reserved `.invalid` email identifiers (including phone-only
guest accounts) and empty values. Real email remains visible when the saved
show-email option permits it. Authentication identity is not rewritten.

## Google account picker

The app already prefers `attemptLightweightAuthentication` on Android. The
locked Android plugin, google_sign_in_android 7.2.18, first requests previously
authorized accounts, then retries its bottom-sheet flow with all eligible
accounts when no credential exists. Only when the sheet is unavailable does the
app use the official explicit sign-in flow. Cancellation never opens a second
picker. iOS retains its native flow.

Google Play services/account settings can suppress the bottom sheet. A screenshot
of a centered picker does not establish which installed app build or provider
condition caused it. No custom imitation account picker or unsupported SDK patch
was added. A physical-device check of the exact APK and Google Play services is
still needed for the second phone.

Official references:
- https://developer.android.com/identity/sign-in/credential-manager-troubleshooting-guide
- https://pub.dev/packages/google_sign_in_android

## Delivery

Receipt rendering and hiding the placeholder require one application rebuild.
The connector's optional method labels can be deployed independently through WHM.
Subsequent existing theme/color/layout publication remains separate from binary
updates. This change does not claim to update an already-installed native screen
through a data-only publication.
