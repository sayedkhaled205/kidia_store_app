/// Customer transports are selected explicitly, never inferred from a URL or
/// replaced by the builder's merchant/admin API.
enum CommercePlatform { wooCommerce, shopify, odoo }

enum CustomerCommerceCapability { catalog, cart, checkout, profile, orders }

class CommerceConnection {
  CommerceConnection({
    required this.platform,
    required Uri storeOrigin,
    this.shopifyApiVersion = '2026-10',
    String shopifyPublicStorefrontToken = '',
  }) : storeOrigin = _origin(storeOrigin),
       shopifyPublicStorefrontToken = _publicToken(
         shopifyPublicStorefrontToken,
       ) {
    if (platform == CommercePlatform.shopify &&
        !RegExp(
          r'^[a-z0-9][a-z0-9-]*\.myshopify\.com$',
        ).hasMatch(this.storeOrigin.host)) {
      throw const FormatException(
        'Shopify requires its canonical HTTPS myshopify.com store origin.',
      );
    }
    if (!RegExp(r'^20\d{2}-(01|04|07|10)$').hasMatch(shopifyApiVersion)) {
      throw const FormatException('Pin a dated Shopify API version.');
    }
    if (platform != CommercePlatform.shopify &&
        this.shopifyPublicStorefrontToken.isNotEmpty) {
      throw const FormatException('A Shopify public token belongs to Shopify.');
    }
  }

  final CommercePlatform platform;
  final Uri storeOrigin;
  final String shopifyApiVersion;

  /// This is a *public Storefront* token, not an Admin API, private Storefront,
  /// merchant OAuth, or Customer Account token. Tokenless catalog is supported.
  final String shopifyPublicStorefrontToken;

  Uri get shopifyStorefrontEndpoint {
    if (platform != CommercePlatform.shopify) {
      throw StateError('This connection does not use the Shopify protocol.');
    }
    return storeOrigin.resolve('/api/$shopifyApiVersion/graphql.json');
  }

  /// Implemented transport coverage, not a claim that a remote store is ready.
  /// Shopify checkout/account transports have not yet been integrated. Odoo's
  /// merchant licensed API must not stand in for a verified buyer API.
  Set<CustomerCommerceCapability> get implementedCapabilities =>
      switch (platform) {
        CommercePlatform.wooCommerce =>
          Set<CustomerCommerceCapability>.unmodifiable(
            CustomerCommerceCapability.values,
          ),
        CommercePlatform.shopify => const <CustomerCommerceCapability>{
          CustomerCommerceCapability.catalog,
          CustomerCommerceCapability.cart,
        },
        CommercePlatform.odoo => const <CustomerCommerceCapability>{
          CustomerCommerceCapability.catalog,
        },
      };

  void requireCapability(CustomerCommerceCapability capability) {
    if (!implementedCapabilities.contains(capability)) {
      throw UnsupportedError(
        '${platform.name} ${capability.name} customer transport is not '
        'implemented. A builder/merchant endpoint is not a fallback.',
      );
    }
  }

  static Uri _origin(Uri source) {
    if (source.scheme != 'https' ||
        source.host.isEmpty ||
        source.userInfo.isNotEmpty ||
        source.hasQuery ||
        source.hasFragment ||
        (source.hasPort && source.port != 443) ||
        (source.path.isNotEmpty && source.path != '/')) {
      throw const FormatException(
        'A customer connection requires a clean HTTPS store origin.',
      );
    }
    return Uri(scheme: 'https', host: source.host.toLowerCase());
  }

  static String _publicToken(String source) {
    final String token = source.trim();
    if (token.length > 512 ||
        token.contains(RegExp(r'[\s\x00-\x1f\x7f]')) ||
        RegExp(r'^(shpat_|shpca_|shpss_|shpua_)').hasMatch(token)) {
      throw const FormatException(
        'Only a public Storefront token may be configured in a customer app.',
      );
    }
    return token;
  }

  @override
  String toString() => 'CommerceConnection(${platform.name}, $storeOrigin)';
}
