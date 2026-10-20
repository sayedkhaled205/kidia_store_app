import 'commerce_connection.dart';
import 'shopify_storefront_client.dart';

/// Checkout domains come from this shop's Storefront settings, never from the
/// checkout URL being validated. A foreign cart response cannot widen trust.
class ShopifyCheckoutPolicy297 {
  ShopifyCheckoutPolicy297({
    required CommerceConnection connection,
    required this.reader,
    Set<String> trustedHosts = const {},
  }) : _hosts = {connection.storeOrigin.host, ...trustedHosts} {
    if (connection.platform != CommercePlatform.shopify ||
        _hosts.any(
          (host) => host.isEmpty || host.contains(RegExp(r'[^a-z0-9.-]')),
        )) {
      throw const FormatException('Invalid Shopify checkout connection.');
    }
  }

  final ShopifyStorefrontReader reader;
  final Set<String> _hosts;
  Future<void>? _preparing;
  String? _primaryHost;

  Future<void> prepare() async {
    if (_primaryHost != null) return;
    await (_preparing ??= _loadPrimaryDomain().whenComplete(() {
      _preparing = null;
    }));
  }

  Future<void> _loadPrimaryDomain() async {
    final data = await reader.query(
      'query MobileStoreCheckoutDomain { shop { primaryDomain { url } } }',
    );
    final shop = data['shop'];
    final domain = shop is Map ? shop['primaryDomain'] : null;
    final value = domain is Map ? domain['url'] : null;
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null ||
        !_secure(uri) ||
        uri.hasQuery ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException('Invalid Shopify primary domain.');
    }
    _primaryHost = uri.host;
  }

  Future<void> verify(Uri destination) async {
    if (!_secure(destination)) {
      throw const FormatException('Invalid Shopify checkout URL.');
    }
    if (_hosts.contains(destination.host)) return;
    await prepare();
    if (destination.host != _primaryHost) {
      throw const FormatException('Checkout is not on a verified shop domain.');
    }
  }

  static bool _secure(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      (!uri.hasPort || uri.port == 443);
}
