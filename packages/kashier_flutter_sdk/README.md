# Kashier Flutter SDK

Accept Card, Apple Pay, and mobile wallet payments in Egypt with a prebuilt,
localized (English/Arabic) payment sheet — all from a single API call.

> **Platform support:** iOS and Android for Card and mobile wallet payments.
> Apple Pay is iOS-only and requires iOS 14.0+.
> Android apps should not add Apple Pay setup; Card and Wallet do not require it.

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  kashier_flutter_sdk: ^0.1.0
```

For iOS apps, ensure your `ios/Podfile` targets at least iOS 14.0:

```ruby
platform :ios, '14.0'
```

## Setup

Wrap your app with `KashierPaymentProvider` so the SDK can render its payment
sheet on its own overlay (works with any navigation solution):

```dart
void main() {
  runApp(
    KashierPaymentProvider(
      child: MaterialApp(home: HomeScreen()),
    ),
  );
}
```

Initialize the SDK once before starting any payment:

```dart
KashierSDK.initialize(
  mode: KashierMode.test,        // or KashierMode.live
  language: KashierLanguage.en,  // or KashierLanguage.ar
);
```

## Quick start

Your backend creates a payment session via Kashier's
[Payment Sessions API](https://developers.kashier.io/payment/sessions) and
hands the session ID to your app. The app passes only that session ID to the
SDK — no API keys or card data ever live in the mobile binary.

```dart
KashierSDK.startPayment(
  sessionId: 'sess_abc123', // from your backend
  onSuccess: (KashierPaymentResult result) {
    print('Paid: ${result.transactionId}');
  },
  onPending: (KashierPaymentPending pending) {
    // Terminal: payment still settling — confirm via webhook/backend
    print('Pending order: ${pending.orderId}');
  },
  onFailure: (KashierPaymentError error) {
    if (error.code == KashierErrorCode.userCancelled) return;
    print('Failed: ${error.message}');
  },
);
```

The SDK fetches the session, shows the method-selection sheet (Apple Pay,
Wallet, Card — whichever the session and device support), runs the chosen
flow end-to-end (including 3DS WebViews and wallet reconcile polling), and
fires exactly one callback when done.

## Apple Pay

Apple Pay is available only on iOS. You use **your own** Apple Pay Merchant ID —
Kashier acts as the payment processor (the same per-merchant model Stripe and
Adyen use). The SDK never bundles or exposes any Kashier merchant identifier.

1. Register your own Apple Pay Merchant ID (e.g. `merchant.com.yourcompany.app`)
   in the [Apple Developer portal](https://developer.apple.com/account/resources/identifiers/list/merchant).
2. Enable the **Apple Pay** capability in Xcode (Signing & Capabilities →
   + Capability → Apple Pay).
3. Add **your** Merchant ID to your app's entitlements file
   (`com.apple.developer.in-app-payments`), mirroring
   [`example/ios/Runner/Runner.entitlements`](example/ios/Runner/Runner.entitlements):

   ```xml
   <key>com.apple.developer.in-app-payments</key>
   <array>
     <string>merchant.com.yourcompany.app</string>
   </array>
   ```
4. Pass the same Merchant ID to the SDK when you initialize it:

   ```dart
   KashierSDK.initialize(
     mode: KashierMode.live,
     appleMerchantId: 'merchant.com.yourcompany.app', // must match the entitlement
   );
   ```

The entitlement value and `appleMerchantId` must match exactly. When
`appleMerchantId` is omitted, Apple Pay is not offered. Contact the Kashier team
to have your Merchant ID provisioned as a processing certificate on their side.

Testing Apple Pay requires a physical iOS device; the Simulator reports
`applePayNotAvailable`.

## Wallets and cards

- **Mobile wallets** (Vodafone Cash and other Egyptian R2P wallets): the
  customer enters their phone number and approves the charge in their wallet
  app while the SDK polls for reconciliation.
- **Cards**: new card, saved cards, and 3-D Secure are handled inside the
  SDK's own sheet. Card data is tokenized directly against Kashier — it never
  touches your app, keeping you out of PCI scope.

## Error handling

All failures (including user cancellation) arrive via
`onFailure(KashierPaymentError)`. Inspect `error.code`
(a `KashierErrorCode`) to decide how to respond — for example, suppress error
UI for `userCancelled`, and offer a retry for `networkError` or
`paymentDeclined`. Every error carries localized `message` (English) and
`messageAr` (Arabic) copy.

## Test mode

Initialize with `KashierMode.test` and create sessions against Kashier's test
API. Use the test card to exercise the card flow:

```text
4508 7500 1574 1019
```

## Documentation

Full integration guide, API reference, and backend session setup:
[developers.kashier.io/flutter](https://developers.kashier.io/flutter)

## License

MIT — see [LICENSE](LICENSE).
