=== Mobi2App Connector for WooCommerce ===
Contributors: woomobi
Tags: mobile app, app builder, ecommerce, store app, woocommerce
Requires at least: 6.4
Tested up to: 7.1
Requires PHP: 8.0
Requires Plugins: woocommerce
Stable tag: 1.46.138
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Connect your WooCommerce store to WooMobile. Manage the mobile application from the central WooMobile dashboard.

== Description ==

Mobi2App Connector for WooCommerce connects any supported WooCommerce store to the WooMobile service and provides the WordPress-side tools used by its mobile applications.

This is a connector, not a local application builder. It does not add a WordPress settings screen, setup wizard or visual builder. Application design, configuration and managed builds are controlled from the WooMobile dashboard.

The connector provides REST interfaces for store catalog, layouts, customer accounts, orders and checkout, and retains existing store configuration identifiers for compatibility. WooCommerce must be active.

= External services =

The following services are used only for the corresponding configured features. Ordinary store checkout continues to use the merchant's installed WooCommerce payment and authentication providers, which may have their own services and privacy terms.

= WooMobile connection and notifications =

WooMobile (`https://api.woomobile.app`) provides the connected dashboard and managed notification delivery. When an administrator activates a connection, the plugin sends the license key, website URL, plugin version, random installation identifier and a one-time nonce. Scheduled license verification sends the installation-bound activation token, plugin version and nonce. Managed application builds run in the external dashboard, not in WordPress.

On an authorized dashboard request, the connector returns the requested store information: catalog, categories, prices, discounts, saved layouts, and, where authorized, customer names and email addresses, orders, totals, statuses and store analytics. These responses support the merchant's store management; the plugin does not automatically export all customers on activation.

When managed push delivery is enabled and a notification is sent, the plugin sends the installation authorization, recipient device push tokens, title, message, optional image URL and action/delivery data to WooMobile. WooMobile delivers these notifications through Google Firebase Cloud Messaging. Customer passwords and raw payment-card data are not sent to WooMobile.

* Service: https://woomobile.app/
* Terms: https://woomobile.app/terms/
* Privacy policy: https://woomobile.app/privacy/

= Google and Firebase authentication =

When the merchant configures native Google or Firebase sign-in and a customer submits a sign-in proof, the connector fetches public signing certificates from `https://www.googleapis.com/oauth2/v1/certs` or `https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com` as needed when the cached certificates expire or signing keys change. These certificate requests contain no customer token, email or phone number. The connector validates the customer's signed token locally against the configured application and uses its verified identity claims to authenticate that customer. Firebase-backed Apple sign-in uses the same Firebase verification path.

The mobile application's configured Google/Firebase SDKs separately communicate with Google when the customer chooses authentication, phone verification or push registration. Firebase handles the corresponding authentication data (such as the selected account or phone number) and device push registration. The connector does not proxy the customer's Google password.

* Service: https://firebase.google.com/ and https://developers.google.com/identity/
* Terms: https://firebase.google.com/terms and https://policies.google.com/terms
* Privacy: https://firebase.google.com/support/privacy and https://policies.google.com/privacy

= Meta / Facebook sign-in =

When Facebook sign-in is configured and the customer chooses it, the connector verifies the supplied access token with `https://graph.facebook.com/debug_token` using the merchant's Facebook app authorization, then requests the account ID and, if granted, email from `https://graph.facebook.com/me`. These requests send the Facebook access token and application authentication proof; they do not send a Facebook password. For supported Limited Login tokens, it instead fetches public keys from `https://www.facebook.com/.well-known/oauth/openid/jwks/` on a cache miss and validates the signed token locally. That public-key request contains no customer token or personal data. Website login can also reuse the merchant's configured Nextend Social Login authorization flow.

* Service: https://developers.facebook.com/docs/facebook-login/
* Terms: https://www.facebook.com/legal/terms/
* Privacy policy: https://www.facebook.com/privacy/policy/

= Kashier payments =

If the merchant has enabled the supported Kashier gateway and a customer chooses it for native checkout, the connector creates a payment session using `https://api.kashier.io` (live) or `https://test-api.kashier.io` (test). The request uses the merchant's API authorization and sends the merchant ID, order/customer reference, amount, currency, session options/expiry, and callback/webhook URLs. Payment-status checks and verified webhook handling query the same service using the order reference. Card details are collected by Kashier's payment interface; this connector does not store raw card data.

* Service: https://www.kashier.io/
* Merchant terms: https://www.kashier.io/legal/terms-of-services
* Privacy policy: https://www.kashier.io/legal/privacy-policy

= Merchant media and WordPress avatars =

Catalog images and merchant-selected artwork retain their configured store/media URLs, which the dashboard or app loads when showing the content. Where WordPress avatars are enabled, WordPress's avatar function may cause the viewer's browser to request a Gravatar image using an email-derived hash. This follows the site's WordPress avatar settings.

* Gravatar service: https://gravatar.com/
* Terms: https://wordpress.com/tos/
* Privacy policy: https://automattic.com/privacy/

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

= 1.46.138 =

* Load checkout, sign-in confirmation and order-source assets through WordPress asset APIs.
* Reject malformed authentication proofs, route targets and analytics identifiers.
* Document configured authentication, payment and notification services and their privacy terms.

= 1.46.137 =

* Use available variations when filtering the public catalogue by stock, attributes and price.
* Show mobile app customer and order sources in store administration.

= 1.46.136 =

* Expose verified store owners saved addresses to native checkout.


= 1.46.134 =

* Sync authenticated customer wishlists across devices using atomic changes.
* Restore verified store owners own shopping history and saved addresses without granting staff privileges.


= 1.46.107 =
* Use FlyCart Discount Rules prices in the mobile catalogue and preserve automatic gift quantity limits.
* Expose read-only discount rule summaries to the authorized merchant builder, alongside WooCommerce coupons.
* Match variation prices to the shop tax display and prevent caching contextual prices.

= 1.46.104 =
* Revoke customer sessions reliably, serialize session changes, and reject unverified storage writes.
* Preserve newer app builds when older status, cancellation or dispatch responses arrive late.

= 1.46.102 =
* Protect the public variation route with explicit publication and storefront visibility checks for the parent and its variations.
* Prevent private, draft, hidden and password-protected product data from being exposed, including to signed-in administrators on this public route.
* Correct connector translation domains and retain WordPress 6.4 / PHP 8.0 compatibility in list validation.

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
