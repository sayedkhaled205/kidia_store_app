import 'commerce_connection.dart';

/// Buyer-only website destinations. Never returns a merchant/admin endpoint.
abstract final class HostedCommerceDestination297 {
  static Uri? forRoute(CommerceConnection connection, String route) {
    final String? path = switch (connection.platform) {
      CommercePlatform.wooCommerce => null,
      CommercePlatform.shopify => switch (route) {
        '/auth' => '/account/login',
        '/account' || '/profile' || '/orders' => '/account',
        '/addresses' => '/account/addresses',
        '/support' => '/',
        _ => route.startsWith('/orders/') ? '/account' : null,
      },
      CommercePlatform.odoo => switch (route) {
        '/cart' => '/shop/cart',
        '/checkout' => '/shop/checkout',
        _ => null,
      },
    };
    return path == null ? null : connection.storeOrigin.resolve(path);
  }

  static Uri? product(CommerceConnection connection, Uri? permalink) {
    if (connection.platform != CommercePlatform.odoo ||
        permalink == null ||
        permalink.scheme != 'https' ||
        permalink.host != connection.storeOrigin.host ||
        permalink.userInfo.isNotEmpty ||
        (permalink.hasPort && permalink.port != 443) ||
        !permalink.path.startsWith('/shop/')) {
      return null;
    }
    return permalink;
  }
}
