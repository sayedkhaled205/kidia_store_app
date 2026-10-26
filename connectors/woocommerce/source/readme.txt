=== Mobi2App Connector for WooCommerce ===
Contributors: woomobi
Tags: mobile app, app builder, ecommerce, store app, woocommerce
Requires at least: 6.4
Tested up to: 7.1
Requires PHP: 8.0
Requires Plugins: woocommerce
Stable tag: 1.46.99
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Connect your WooCommerce store to WooMobile. Manage the mobile application from the central WooMobile dashboard.

== Description ==

Mobi2App Connector for WooCommerce connects any supported WooCommerce store to the WooMobile service and provides the WordPress-side tools used by its mobile applications.

This is a connector, not a local application builder. It does not add a WordPress settings screen, setup wizard or visual builder. Application design, configuration and managed builds are controlled from the WooMobile dashboard.

The connector provides REST interfaces for store catalog, layouts, customer accounts, orders and checkout, and retains existing store configuration identifiers for compatibility. WooCommerce must be active.

= External service =

This plugin connects to the WooMobile service at `https://api.woomobile.app` when an administrator connects a website, activates or verifies a license, requests an app build, or configures managed push notifications.

For license activation, the plugin sends the license key, website URL, plugin version, a random installation identifier, and a one-time nonce. Hourly license verification sends the installation-bound activation token, plugin version, and a one-time nonce. App-build and managed-push requests send the settings selected by the administrator and the installation-bound authorization token. The plugin does not send customer passwords or raw payment-card data to WooMobile.

The service is provided by WooMobile and is required for subscription validation, managed builds, and managed push notifications:

* Service: https://woomobile.app/
* Terms: https://woomobile.app/terms/
* Privacy policy: https://woomobile.app/privacy/

= Source code and third-party licenses =

The connector PHP and first-party JavaScript are provided as readable source. QRCode.js is distributed under the MIT license; its upstream source and license are documented in SOURCE-BUILD.txt. The central visual builder is not bundled in this connector.

== Installation ==

1. Install and activate WooCommerce.
2. Install and activate Mobi2App Connector for WooCommerce.
3. Open your WooMobile account dashboard and connect the store using its authorization flow.
4. Manage application design, settings and builds in WooMobile. There are no local connector settings to edit.

== Frequently Asked Questions ==

= Does the plugin require WooCommerce? =

Yes. It exposes and manages mobile storefront functionality for a WooCommerce store.

= Is a WooMobile subscription required? =

The connector does not lock local store features behind a license. Managed application builds and push delivery use the external WooMobile service and its subscription plans. All application management is in the WooMobile dashboard.

= Does the plugin store payment-card data? =

No. Store checkout is handled by the payment methods configured in WooCommerce, and the plugin does not store raw card details.

= Does the plugin support Arabic and RTL layouts? =

Yes. Application language, direction, typography, and other visual settings can be configured from the builder.

== Changelog ==

= 1.46.81 =
* Accept valid Google ID tokens until their signed expiry and refresh rotated signing keys safely.
* Keep native authentication failures diagnosable without storing customer data or credentials.

= 1.46.80 =
* Read payment method names from each merchant's enabled WooCommerce gateways; the current cart remains authoritative for payment availability.
* Continue online payments on the merchant's existing order-pay page when Native has no gateway payment data, without separate app gateway credentials or duplicate orders.
* Retain the shared Kids home spacing, product collections, logo proportions and splash defaults.

= 1.46.77 =
* Prepare native checkout protection automatically through the existing authorized WooMobile connection, preserving installation identity and prior checkout attempts.
* Report unavailable checkout protection explicitly, and support authenticated owned-order payment-status refresh without creating or paying an order.
* Preserve a verified external-payment hand-off as an existing unpaid order, without replaying checkout or claiming payment completion.

= 1.46.75 =
* Restore the verified website sign-in bridge for native apps, with automatic WooCommerce account-page discovery and one-time, browser-bound authentication exchange.
* Preserve installed website sign-in methods and customer-only session authorization.


= 1.46.74 =
* Rename the connector to Mobi2App Connector for WooCommerce.
* Preserve store data, authorization and API identifiers.

= 1.46.72 =
* Make the plugin connector-only: remove local administration and management handlers.
* Link directly to the central WooMobile dashboard.
* Preserve existing REST interfaces and store data.

= 1.46.71 =
* Rename the plugin to Mobi2App Connector for WooCommerce, retaining existing store data and API identifiers for compatibility.
* Make local configuration and export available without a service subscription.
* Load dashboard and image-picker assets through WordPress enqueue APIs.
* Use the WordPress REST URL API for store health checks.
* Include readable category-preview bridge source.

= 1.46.70 =
* Build Android and signed iOS together from one request, with a combined download.
* Keep cancellation pending until the build service confirms it has stopped.

= 1.46.69 =
* Forward the selected store language and Firebase bootstrap URL to native builds.
* Include the selected store logo for Android and iOS app icon generation.

= 1.46.68 =
* Select platform-specific Firebase configuration and enable native iOS push registration after APNs becomes available.
* Identify WordPress plugin build requests separately from the central builder project.

= 1.46.67 =
* Restore compatibility with the deployed license and build API and its installation authentication headers.
* Open website connections on the account portal.
* Fix Flutter preview readiness, startup error, scroll and cache-version messages after the MobiShop rename.

= 1.46.66 =

* Fixed switch thumb placement in left-to-right and right-to-left builders.
* Fixed checkout status control and toolbar icon alignment, preserving keyboard focus and form values.

= 1.46.65 =

* Restored the styled sidebar on the main MobiShop administration page.
* Restored the green MobiShop styling for the website connection button.

= 1.46.64 =

* Completed the full MobiShop rebrand across public labels, service attribution, code identifiers, REST namespaces, option keys, hooks, classes, files, and package paths.
* Kept the existing service domains unchanged while presenting the service as MobiShop.

= 1.46.62 =

* Fixed the WordPress installation path by using `mobishop/mobishop.php` as the packaged plugin entry file.
* Added strict ZIP-layout checks and clean activation validation before publishing the package.

= 1.46.61 =

* Aligned the translation text domain with the assigned WordPress.org slug.
* Fixed the plugin and author URI validation for WordPress.org submission.

= 1.46.60 =

* Added global application settings and an expanded font collection.
* Updated the packaged plugin and embedded mobile preview.

== Upgrade Notice ==

= 1.46.65 =

Use this release to restore the main MobiShop administration layout.

= 1.46.64 =

Use this release for the complete MobiShop identity and updated internal namespaces.

= 1.46.62 =

Use this release to replace packages that installed under an incorrect nested plugin directory.
