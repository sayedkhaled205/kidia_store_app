import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  const AppConfig._();

  static const bool _useMockHomeLayout = bool.fromEnvironment(
    'USE_MOCK_HOME_LAYOUT',
    defaultValue: false,
  );

  /// Legacy build define kept for one migration cycle.
  ///
  /// New builds should use `STORE_URL`. Keeping this fallback means existing
  /// development and CI commands continue to work without shipping a store URL
  /// in the application source.
  static const String _legacyApiBaseUrl = String.fromEnvironment(
    'WOOCOMMERCE_BASE_URL',
    defaultValue: '',
  );

  /// WooCommerce store origin configured at build time.
  ///
  /// Example:
  /// `flutter run --dart-define=STORE_URL=https://example.com`
  static const String apiBaseUrl = String.fromEnvironment(
    'STORE_URL',
    defaultValue: _legacyApiBaseUrl,
  );

  static bool get hasConfiguredStore => apiBaseUrl.trim().isNotEmpty;

  /// An unconfigured debug build intentionally uses local fixture data.
  /// Release builds require an explicit store unless mock mode was requested.
  static bool get useMockHomeLayout {
    return _useMockHomeLayout || (kDebugMode && !hasConfiguredStore);
  }

  static const String homeLayoutEndpoint = String.fromEnvironment(
    'HOME_LAYOUT_ENDPOINT',
    defaultValue: '/wp-json/woo-mobile/v1/home-layout',
  );

  static const String storeName = String.fromEnvironment(
    'STORE_NAME',
    defaultValue: 'Woo Mobile Store',
  );

  static const String storeTagline = String.fromEnvironment(
    'STORE_TAGLINE',
    defaultValue: '',
  );

  static const String storeLocale = String.fromEnvironment(
    'STORE_LOCALE',
    defaultValue: 'en',
  );

  static bool get isRightToLeft {
    final String languageCode = storeLocale
        .split(RegExp('[-_]'))
        .first
        .trim()
        .toLowerCase();
    return const <String>{'ar', 'fa', 'he', 'ur'}.contains(languageCode);
  }

  /// Validates the build-time connection without contacting the store.
  static void validateStoreConnection() {
    if (!hasConfiguredStore) {
      if (useMockHomeLayout) {
        return;
      }

      throw const AppConfigurationException(
        'No WooCommerce store is configured. Set STORE_URL for this build.',
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
  }
}

class AppConfigurationException implements Exception {
  const AppConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
