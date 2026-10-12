import 'package:flutter/foundation.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';

import 'runtime_store_origin.dart';

abstract final class AppConfig {
  const AppConfig._();

  static const bool _useMockHomeLayout = bool.fromEnvironment(
    'USE_MOCK_HOME_LAYOUT',
    defaultValue: false,
  );

  static const bool isCmsPreview = bool.fromEnvironment(
    'CMS_PREVIEW',
    defaultValue: false,
  );

  /// Public saved normalized Builder settings for explicit non-Woo builds.
  /// This is not a catalog snapshot, credential, or remote design endpoint.
  static const String appDesignBundle = String.fromEnvironment(
    'APP_DESIGN_BUNDLE',
    defaultValue: '',
  );

  /// A protocol is explicit, never guessed from a URL. Existing builds retain
  /// WooCommerce by default; an invalid value must not silently become Woo.
  static const String _compiledStorePlatform = String.fromEnvironment(
    'STORE_PLATFORM',
    defaultValue: 'woocommerce',
  );

  static CommercePlatform get commercePlatform =>
      switch (_compiledStorePlatform.trim().toLowerCase()) {
        'woocommerce' => CommercePlatform.wooCommerce,
        'shopify' => CommercePlatform.shopify,
        'odoo' => CommercePlatform.odoo,
        _ => throw const AppConfigurationException(
          'STORE_PLATFORM must be woocommerce, shopify or odoo.',
        ),
      };

  static const String shopifyApiVersion = String.fromEnvironment(
    'SHOPIFY_STOREFRONT_API_VERSION',
    defaultValue: '2026-10',
  );
  static const String shopifyPublicStorefrontToken = String.fromEnvironment(
    'SHOPIFY_PUBLIC_STOREFRONT_TOKEN',
    defaultValue: '',
  );
  static const String buyerCountryCode = String.fromEnvironment(
    'STORE_COUNTRY_CODE',
    defaultValue: '',
  );
  static const String _shopifyLanguageCode = String.fromEnvironment(
    'SHOPIFY_LANGUAGE_CODE',
    defaultValue: '',
  );

  static String get shopifyLanguageCode =>
      _shopifyLanguageCode.trim().isNotEmpty
      ? _shopifyLanguageCode.trim().toUpperCase()
      : storeLocale.split(RegExp('[-_]')).first.trim().toUpperCase();

  /// Direct public customer catalog connection for new platform transports.
  /// No merchant/admin credential is consumed by this configuration.
  static CommerceConnection get commerceConnection {
    validateStoreConnection();
    return CommerceConnection(
      platform: commercePlatform,
      storeOrigin: Uri.parse(apiBaseUrl.trim()),
      shopifyApiVersion: shopifyApiVersion,
      shopifyPublicStorefrontToken: shopifyPublicStorefrontToken,
    );
  }

  /// Fixed WordPress customer APIs must call this before transport creation.
  /// A foreign platform is unsupported, not permission to send /wp-json calls.
  static void requireWooCommerceCustomerTransport(String capability) {
    if (commercePlatform != CommercePlatform.wooCommerce) {
      throw AppConfigurationException(
        '${commercePlatform.name} $capability customer transport is not '
        'integrated in this build. No WooCommerce fallback is allowed.',
      );
    }
  }

  /// Legacy build define kept for one migration cycle.
  ///
  /// New builds should use `STORE_URL`. Keeping this fallback means existing
  /// development and CI commands continue to work without shipping a store URL
  /// in the application source.
  static const String _legacyApiBaseUrl = String.fromEnvironment(
    'WOOCOMMERCE_BASE_URL',
    defaultValue: '',
  );

  /// Customer store origin configured at build time.
  ///
  /// Example:
  /// `flutter run --dart-define=STORE_URL=https://example.com`
  static const String _compiledApiBaseUrl = String.fromEnvironment(
    'STORE_URL',
    defaultValue: _legacyApiBaseUrl,
  );

  static String get apiBaseUrl => _compiledApiBaseUrl.trim().isNotEmpty
      ? _compiledApiBaseUrl
      : RuntimeStoreOrigin.value;

  static bool get hasConfiguredStore => apiBaseUrl.trim().isNotEmpty;

  /// An unconfigured debug build intentionally uses local fixture data.
  /// Release builds require an explicit store unless mock mode was requested.
  static bool get useMockHomeLayout {
    return _useMockHomeLayout || (kDebugMode && !hasConfiguredStore);
  }

  static const String homeLayoutEndpoint = String.fromEnvironment(
    'HOME_LAYOUT_ENDPOINT',
    defaultValue: '/wp-json/mobishop/v1/home-layout',
  );

  static const String storeName = String.fromEnvironment(
    'STORE_NAME',
    defaultValue: 'MobiShop Store',
  );

  static const String storeTagline = String.fromEnvironment(
    'STORE_TAGLINE',
    defaultValue: '',
  );

  static const String storeLocale = String.fromEnvironment(
    'STORE_LOCALE',
    defaultValue: 'en',
  );

  static const String storeDirection = String.fromEnvironment('STORE_DIRECTION');
  static const String storeFontFamily = String.fromEnvironment('STORE_FONT_FAMILY');
  static const String storePrimaryColor = String.fromEnvironment('STORE_PRIMARY_COLOR');
  static const String storeSecondaryColor = String.fromEnvironment('STORE_SECONDARY_COLOR');
  static bool get hasNativeBranding => storeFontFamily.isNotEmpty || storePrimaryColor.isNotEmpty || storeSecondaryColor.isNotEmpty;
  static Map<String, dynamic>? get nativeIdentity =>
      !hasNativeBranding && storeDirection.isEmpty ? null : <String, dynamic>{
        'app_name': storeName, 'language': storeLocale, 'direction': storeDirection,
        'font_family': storeFontFamily, 'primary_color': storePrimaryColor,
        'secondary_color': storeSecondaryColor,
      };

  /// Public WordPress endpoint that returns the per-store Firebase bootstrap.
  static const String pushConfigUrl = String.fromEnvironment(
    'PUSH_CONFIG_URL',
    defaultValue: '',
  );

  /// Public MobiShop customer-service contacts. Deployments can override either
  /// value without changing application code.
  static const String supportWhatsApp = String.fromEnvironment(
    'STORE_SUPPORT_WHATSAPP',
    defaultValue: '201208846445',
  );

  static const String supportEmail = String.fromEnvironment(
    'STORE_SUPPORT_EMAIL',
    defaultValue: 'support@mobishopstore.com',
  );

  static bool get isRightToLeft {
    if (storeDirection == 'rtl') return true;
    if (storeDirection == 'ltr') return false;
    final String languageCode = storeLocale
        .split(RegExp('[-_]'))
        .first
        .trim()
        .toLowerCase();
    return const <String>{'ar', 'fa', 'he', 'ur'}.contains(languageCode);
  }

  /// Validates the build-time connection without contacting the store.
  /// Keep the `flutter run --dart-define=...` command in the terminal; it is
  /// documentation input and must never be appended to this Dart expression.
  static void validateStoreConnection() {
    // Validate even an unconfigured/mock build's explicit protocol.
    commercePlatform;
    if (!hasConfiguredStore) {
      if (useMockHomeLayout &&
          commercePlatform == CommercePlatform.wooCommerce) {
        return;
      }

      throw const AppConfigurationException(
        'No customer store is configured. Set STORE_URL for this build.',
      );
    }

    final Uri? storeUri = Uri.tryParse(apiBaseUrl.trim());
    final bool isHttp = storeUri?.scheme == 'http';
    final bool isHttps = storeUri?.scheme == 'https';
    final bool isLocalDebugHost =
        kDebugMode &&
        isHttp &&
        (storeUri?.host == 'localhost' || storeUri?.host == '127.0.0.1');

    if (storeUri == null ||
        !storeUri.hasAuthority ||
        (!isHttps && !isLocalDebugHost)) {
      throw const AppConfigurationException(
        'STORE_URL must be a valid HTTPS origin. HTTP is allowed only for '
        'localhost debug builds.',
      );
    }
    if (commercePlatform != CommercePlatform.wooCommerce) {
      // Validate at application entry, before any provider can contact a host.
      // Existing Woo subdirectory/debug semantics above remain unchanged.
      try {
        CommerceConnection(
          platform: commercePlatform,
          storeOrigin: storeUri,
          shopifyApiVersion: shopifyApiVersion,
          shopifyPublicStorefrontToken: shopifyPublicStorefrontToken,
        );
      } on FormatException catch (error) {
        throw AppConfigurationException(error.message);
      }
      if (commercePlatform == CommercePlatform.shopify &&
          ((!RegExp(r'^[A-Z]{2}(_[A-Z]{2})?$').hasMatch(shopifyLanguageCode)) ||
              (buyerCountryCode.trim().isNotEmpty &&
                  !RegExp(
                    r'^[A-Z]{2}$',
                  ).hasMatch(buyerCountryCode.trim().toUpperCase())))) {
        throw const AppConfigurationException(
          'Invalid Shopify country/language context configuration.',
        );
      }
    }
  }
}

class AppConfigurationException implements Exception {
  const AppConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
