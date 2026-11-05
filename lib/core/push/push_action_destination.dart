import '../config/app_config.dart';
import 'app_page_link.dart';

/// Resolve the builder notification contract without permitting arbitrary schemes.
final class PushActionDestination {
  const PushActionDestination({required this.location});
  final String location;

  static PushActionDestination? fromData(Map<String, dynamic> data) {
    String value(String key) =>
        data[key] is String ? (data[key] as String).trim() : '';
    final destination = value('destination');
    final id = value('destination_id');
    bool positiveId() => RegExp(r'^[1-9][0-9]*$').hasMatch(id);
    switch (destination) {
      case 'home':
        return const PushActionDestination(location: '/');
      case 'categories':
        return const PushActionDestination(location: '/categories');
      case 'cart':
        return const PushActionDestination(location: '/cart');
      case 'checkout':
        return const PushActionDestination(location: '/checkout');
      case 'wishlist':
        return const PushActionDestination(location: '/wishlist');
      case 'account':
        return const PushActionDestination(location: '/account');
      case 'order':
        return positiveId()
            ? PushActionDestination(location: '/orders/$id')
            : null;
      case 'product':
        return positiveId()
            ? PushActionDestination(location: '/product/$id')
            : null;
      case 'category':
      case 'subcategory':
        return positiveId()
            ? PushActionDestination(location: '/categories/$id')
            : null;
      case 'offers':
        return const PushActionDestination(location: '/collection/sale');
      case 'collection':
        return id.isNotEmpty
            ? PushActionDestination(
                location: '/collection/${Uri.encodeComponent(id)}',
              )
            : null;
      case 'search':
        return PushActionDestination(
          location: Uri(
            path: '/search',
            queryParameters: id.isEmpty ? null : {'q': id},
          ).toString(),
        );
      case 'external':
        final route = AppPageLink.fromStoreUrl(
          value('action_url'),
          AppConfig.apiBaseUrl,
        );
        return route == null ? null : PushActionDestination(location: route);
      default:
        return null;
    }
  }
}
