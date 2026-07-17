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
- Google and Facebook sign-in through the store's configured Nextend Social
  Login providers, returning securely to the app without embedding provider
  secrets
- Secure, store-scoped mobile sessions and mandatory authentication before
  checkout, with orders attached to the signed-in WooCommerce customer
- Native customer order history, WooCommerce-controlled cancellation, saved
  addresses, profile editing, and store-controlled customer-service details
- Arabic/English direction support and responsive mobile layouts

## Store-specific integrations

Google and Facebook sign-in reuse the store's existing Nextend Social Login
configuration. Enable and verify each provider in WordPress before testing the
app. Provider credentials remain in WordPress and are never committed to or
embedded in the Flutter app. Payment gateways likewise require credentials and
server-side adapters owned by each store. The generic checkout deliberately
does not store or transmit raw card details.

## WordPress package

`kidia-mobile-cms.zip` is the installable plugin archive. Replace the installed
plugin only after backing up the site, then verify Library, Home Builder,
Editor, and `/wp-json/kidia-mobile/v1/home-layout` on a staging site. App
authentication, customer orders, saved addresses, profile editing, and
customer service require plugin version 1.12.0 or newer and an HTTPS store.

The app never embeds WooCommerce API secrets. The companion plugin validates
the website email/password, stores only hashed mobile-session tokens in user
metadata, rate-limits public auth endpoints, and authenticates those tokens
only for the mobile plugin and WooCommerce Store API namespaces.

The same build works against staging or production: install the same plugin
version on the target site and build with that site's `STORE_URL`. Customer
accounts and orders always belong to the site selected by `STORE_URL`; staging
sessions are kept separate from production sessions on the device. Nextend's
Google and Facebook providers must also be enabled for that exact site origin;
configure and verify staging and production separately when they use different
domains.
