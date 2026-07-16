# Woo Mobile Store

A reusable Flutter storefront and WordPress plugin for WooCommerce stores.
The app reads public catalog data from the official WooCommerce Store API and
reads its CMS home layout from the bundled **Woo Mobile CMS** plugin.

## Local setup

1. Install Flutter and Android Studio (including an Android SDK).
2. Copy `config/store.example.json` to `config/store.local.json`.
3. Set `STORE_URL` to the HTTPS origin of the WooCommerce store.
4. Install `kidia-mobile-cms.zip` in WordPress and activate it.
5. Run:

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config/store.local.json
```

To create a local debug APK:

```bash
flutter build apk --debug --dart-define-from-file=config/store.local.json
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

## Included customer flows

- CMS-driven home page and deep links
- Categories, search, product lists, filters, sorting, and pagination
- Product details, variations, quantity selection, and gallery
- Cart, coupons, local wishlist, brands, and standard Store API checkout
- Arabic/English direction support and responsive mobile layouts

## Store-specific integrations

Social sign-in and payment gateways require credentials and server-side
adapters owned by each store. Never commit Google, Meta, Apple, payment, or
WooCommerce secrets to this repository. The generic checkout deliberately does
not store or transmit raw card details.

## WordPress package

`kidia-mobile-cms.zip` is the installable plugin archive. Replace the installed
plugin only after backing up the site, then verify Library, Home Builder,
Editor, and `/wp-json/kidia-mobile/v1/home-layout` on a staging site.
