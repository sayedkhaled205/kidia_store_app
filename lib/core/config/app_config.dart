abstract final class AppConfig {
  const AppConfig._();

  static const bool useMockHomeLayout = bool.fromEnvironment(
    'USE_MOCK_HOME_LAYOUT',
    defaultValue: false,
  );

  /// Configure each WordPress installation at build time:
  ///
  /// `--dart-define=WORDPRESS_BASE_URL=https://store.example.com`
  ///
  /// `WOOCOMMERCE_BASE_URL` remains a compatibility fallback for existing
  /// build pipelines, but there is deliberately no store-specific default.
  static const String _configuredBaseUrl = String.fromEnvironment(
    'WORDPRESS_BASE_URL',
    defaultValue: String.fromEnvironment(
      'WOOCOMMERCE_BASE_URL',
      defaultValue: '',
    ),
  );

  static const String _configuredHomeLayoutEndpoint = String.fromEnvironment(
    'HOME_LAYOUT_ENDPOINT',
    defaultValue: 'wp-json/woo-mobile/v1/home-layout',
  );

  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Woo Mobile CMS',
  );

  static const String storeName = String.fromEnvironment(
    'STORE_NAME',
    defaultValue: 'Woo Mobile CMS',
  );

  static const String storeTagline = String.fromEnvironment(
    'STORE_TAGLINE',
    defaultValue: '',
  );

  /// A normalized base URL ending with `/`, suitable for Dio relative paths.
  static String get wordpressBaseUrl => _resolveWordpressBaseUrl();

  /// Backwards-compatible name used by the existing home data provider.
  static String get apiBaseUrl => wordpressBaseUrl;

  /// A relative endpoint so WordPress installations in subdirectories work.
  static String get homeLayoutEndpoint => _resolveHomeLayoutEndpoint();

  static void validate() {
    if (!useMockHomeLayout) {
      _resolveWordpressBaseUrl();
    }

    _resolveHomeLayoutEndpoint();
  }

  static String _resolveWordpressBaseUrl() {
    final String value = _configuredBaseUrl.trim();

    if (value.isEmpty) {
      throw StateError(
        'WORDPRESS_BASE_URL is required. Configure it with '
        '--dart-define=WORDPRESS_BASE_URL=https://store.example.com.',
      );
    }

    final Uri? uri = Uri.tryParse(value);
    final bool isHttp = uri?.scheme == 'http' || uri?.scheme == 'https';

    if (uri == null || !isHttp || uri.host.isEmpty) {
      throw StateError(
        'WORDPRESS_BASE_URL must be an absolute HTTP or HTTPS URL.',
      );
    }

    if (uri.hasQuery || uri.hasFragment) {
      throw StateError(
        'WORDPRESS_BASE_URL cannot contain a query string or fragment.',
      );
    }

    final String pathWithoutTrailingSlash = uri.path.replaceFirst(
      RegExp(r'/+$'),
      '',
    );

    return uri.replace(path: '$pathWithoutTrailingSlash/').toString();
  }

  static String _resolveHomeLayoutEndpoint() {
    final String value = _configuredHomeLayoutEndpoint.trim().replaceFirst(
      RegExp(r'^/+'),
      '',
    );

    if (value.isEmpty ||
        value.contains('://') ||
        value.split('/').contains('..')) {
      throw StateError('HOME_LAYOUT_ENDPOINT must be a safe relative path.');
    }

    return value;
  }
}
