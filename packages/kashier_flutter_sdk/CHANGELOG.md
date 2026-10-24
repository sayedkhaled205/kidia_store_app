# Changelog

## 0.1.4

Removed:

- Internal debug logging.

## 0.1.3

Fixed:

- 3DS verification not completing on some banks (Android).

## 0.1.2

Fixed:

- 3DS verification failing after card PAY: the request now keeps
  `newPaymentUI` so the backend returns the working V3 `/3ds-redirect`
  URL instead of the dead legacy `/3dsRedirect` page.
- 3DS WebView blocked with a 404 by the WAF: the base64 `redirectHtml`
  query param is stripped from the redirect URL before loading.

## 0.1.1

## 0.1.0

Initial public release.

- Card payments (new card, saved cards, 3DS verification)
- Apple Pay integration
- Mobile wallet payments with reconcile polling
- Prebuilt localized payment sheet (English & Arabic)
- iOS only (iOS 14.0+)
