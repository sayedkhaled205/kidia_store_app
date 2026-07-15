abstract final class AppConfig {
  const AppConfig._();

  static const bool useMockHomeLayout = bool.fromEnvironment(
    'USE_MOCK_HOME_LAYOUT',
    defaultValue: false,
  );

  /// Configure per WooCommerce store at build time:
  /// --dart-define=WOOCOMMERCE_BASE_URL=https://example.com
  static const String apiBaseUrl = String.fromEnvironment(
    'WOOCOMMERCE_BASE_URL',
    defaultValue:
        'https://woocommerce-1463195-5516081.cloudwaysapps.com',
  );

  static const String homeLayoutEndpoint = String.fromEnvironment(
    'HOME_LAYOUT_ENDPOINT',
    defaultValue: '/wp-json/woo-mobile/v1/home-layout',
  );

  static const String storeName = String.fromEnvironment(
    'STORE_NAME',
    defaultValue: 'WooCommerce Store',
  );

  static const String storeTagline = String.fromEnvironment(
    'STORE_TAGLINE',
    defaultValue: '',
  );
}
