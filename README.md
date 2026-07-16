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
- Progressive email sign-in/registration using the store's existing
  WooCommerce customer accounts
- Secure, store-scoped mobile sessions and mandatory authentication before
  checkout, with orders attached to the signed-in WooCommerce customer
- Arabic/English direction support and responsive mobile layouts

## Store-specific integrations

Social sign-in and payment gateways require credentials and server-side
adapters owned by each store. Never commit Google, Meta, Apple, payment, or
WooCommerce secrets to this repository. The generic checkout deliberately does
not store or transmit raw card details.

## WordPress package

`kidia-mobile-cms.zip` is the installable plugin archive. Replace the installed
plugin only after backing up the site, then verify Library, Home Builder,
Editor, and `/wp-json/kidia-mobile/v1/home-layout` on a staging site. App
authentication requires plugin version 1.6.0 or newer and an HTTPS store.

The app never embeds WooCommerce API secrets. The companion plugin validates
the website email/password, stores only hashed mobile-session tokens in user
metadata, rate-limits public auth endpoints, and authenticates those tokens
only for the mobile plugin and WooCommerce Store API namespaces.

The same build works against staging or production: install the same plugin
version on the target site and build with that site's `STORE_URL`. Customer
accounts and orders always belong to the site selected by `STORE_URL`; staging
sessions are kept separate from production sessions on the device.
