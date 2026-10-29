/// Public storefront URL carrying an app-only destination, without session data.
final class AppPageLink {
  static String? location(Uri link, String storeUrl) {
    final store = Uri.tryParse(storeUrl);
    if (store == null ||
        store.host.isEmpty ||
        link.scheme != 'https' ||
        link.userInfo.isNotEmpty ||
        link.host != store.host ||
        link.port != store.port ||
        link.path.replaceAll(RegExp(r'/+$'), '') !=
            store.path.replaceAll(RegExp(r'/+$'), '')) {
      return null;
    }
    final route = link.queryParameters['mobishop_page'];
    return validRoute(route) ? route : null;
  }

  static bool validRoute(String? route) {
    if (route == null || route.length > 1700 || route.contains('\\')) {
      return false;
    }
    final uri = Uri.tryParse(route);
    if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasFragment) {
      return false;
    }
    if (!RegExp(
      r'^/(?:products|categories(?:/[1-9][0-9]*)?|product/[1-9][0-9]*|brand/[1-9][0-9]*|brands|collection/[a-zA-Z0-9_%\-]+|search|wishlist|cart|checkout|account)?$',
    ).hasMatch(uri.path)) {
      return false;
    }
    return uri.queryParameters.keys.every(
      (key) => ['q', 'name', 'collection', 'brand', 'view'].contains(key),
    );
  }
}
