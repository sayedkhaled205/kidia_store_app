=== MobiShop ===
Contributors: woomobile
Tags: mobile app, app builder, ecommerce, store app, woocommerce
Requires at least: 6.4
Tested up to: 7.0
Requires PHP: 8.0
Requires Plugins: woocommerce
Stable tag: 1.46.63
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Connect a WooCommerce store to the WooMobile app builder, manage the mobile storefront, and request Android and iOS builds.

== Description ==

MobiShop connects a WooCommerce store to the WooMobile service and provides the WordPress-side tools used by its mobile applications.

The plugin includes:

* A visual home, catalog, product, account, header, and footer builder.
* REST API endpoints for catalog, layouts, customer accounts, orders, checkout, and app configuration.
* Store analytics, abandoned-cart recovery, offer tools, push notification controls, and app promotion tools.
* License activation and secure, installation-bound communication with the WooMobile build service.
* Arabic and English storefront configuration, including right-to-left layouts.

An active WooMobile subscription is required to unlock the managed app-building and publishing features. WooCommerce must be installed and active.

= External service =

This plugin connects to the WooMobile service at `https://api.woomobile.app` when an administrator connects a website, activates or verifies a license, requests an app build, or configures managed push notifications.

For license activation, the plugin sends the license key, website URL, plugin version, a random installation identifier, and a one-time nonce. Hourly license verification sends the installation-bound activation token, plugin version, and a one-time nonce. App-build and managed-push requests send the settings selected by the administrator and the installation-bound authorization token. The plugin does not send customer passwords or raw payment-card data to WooMobile.

The service is provided by WooMobile and is required for subscription validation, managed builds, and managed push notifications:

* Service: https://woomobile.app/
* Terms: https://woomobile.app/terms/
* Privacy policy: https://woomobile.app/privacy/

== Installation ==

1. Install and activate WooCommerce.
2. Install and activate MobiShop.
3. Open **MobiShop** in WordPress administration.
4. Connect the website to your WooMobile account.
5. Activate the license assigned to this website.
6. Configure the application and request a build when ready.

== Frequently Asked Questions ==

= Does the plugin require WooCommerce? =

Yes. It exposes and manages mobile storefront functionality for a WooCommerce store.

= Is a WooMobile subscription required? =

The plugin can be installed and previewed without a subscription. An active subscription is required to save licensed configuration and use managed build and push services.

= Does the plugin store payment-card data? =

No. Store checkout is handled by the payment methods configured in WooCommerce, and the plugin does not store raw card details.

= Does the plugin support Arabic and RTL layouts? =

Yes. Application language, direction, typography, and other visual settings can be configured from the builder.

== Changelog ==

= 1.46.63 =

* Added translator context for every placeholder string reported by Plugin Check.
* Completed the remaining public MobiShop branding replacements.

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

= 1.46.63 =

Use this release for a zero-error WordPress.org Plugin Check result.

= 1.46.62 =

Use this release to replace packages that installed under an incorrect nested plugin directory.
