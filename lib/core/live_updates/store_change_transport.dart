import 'package:dio/dio.dart';

import 'store_change_signal.dart';

/// Revisions are invalidation hints, never catalog/order/customer payloads.
final class StoreRevisionSnapshot {
  StoreRevisionSnapshot._(this.revisions, this.sessionScope);

  final Map<StoreChangeDomain, String> revisions;
  final String? sessionScope;

  static StoreRevisionSnapshot parse(
    Object? value, {
    required String configuredOrigin,
    required bool authenticatedRequest,
  }) {
    const keys = <String>{
      'version',
      'type',
      'store_origin',
      'revisions',
      'session_scope',
    };
    if (value is! Map ||
        value.keys.any((key) => key is! String || !keys.contains(key)) ||
        value['version'] != 1 ||
        value['type'] != 'mobishop_store_revisions' ||
        value['store_origin'] != configuredOrigin ||
        value['revisions'] is! Map) {
      throw const FormatException('Invalid store revision envelope.');
    }
    final raw = value['revisions'] as Map;
    final revisions = <StoreChangeDomain, String>{};
    for (final entry in raw.entries) {
      final domain = switch (entry.key) {
        'catalog' => StoreChangeDomain.catalog,
        'stock' => StoreChangeDomain.stock,
        'orders' => StoreChangeDomain.orders,
        'profile' => StoreChangeDomain.profile,
        _ => null,
      };
      if (domain == null || !_bounded(entry.value, 128)) {
        throw const FormatException('Invalid store revision.');
      }
      revisions[domain] = entry.value as String;
    }
    if (!revisions.containsKey(StoreChangeDomain.catalog) ||
        !revisions.containsKey(StoreChangeDomain.stock)) {
      throw const FormatException('Public store revisions are missing.');
    }
    final scope = value['session_scope'];
    final hasPrivate = revisions.keys.any((domain) => domain.requiresSession);
    if (hasPrivate && (!authenticatedRequest || !_bounded(scope, 192))) {
      throw const FormatException('Private revisions are not session scoped.');
    }
    if (scope != null && (!authenticatedRequest || !_bounded(scope, 192))) {
      throw const FormatException('Invalid revision session scope.');
    }
    return StoreRevisionSnapshot._(
      Map.unmodifiable(revisions),
      authenticatedRequest ? scope as String? : null,
    );
  }

  static bool _bounded(Object? value, int limit) =>
      value is String &&
      value.isNotEmpty &&
      value.length <= limit &&
      value.trim() == value &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);
}

abstract interface class StoreChangeTransport {
  Future<StoreRevisionSnapshot> readRevisions({String? sessionToken});
}

/// The only destination is the configured platform. No URL from a hint is used.
final class DioStoreChangeTransport implements StoreChangeTransport {
  DioStoreChangeTransport({required this.dio, required String storeUrl})
    : _store = _validateStore(storeUrl);

  final Dio dio;
  final Uri _store;
  String get origin => _store.origin;

  @override
  Future<StoreRevisionSnapshot> readRevisions({String? sessionToken}) async {
    final token = sessionToken?.trim();
    if (token != null &&
        (token.isEmpty ||
            token.length > 512 ||
            RegExp(r'[\x00-\x1f\x7f]').hasMatch(token))) {
      throw const FormatException('Invalid live-update session.');
    }
    final prefix = _store.path.replaceFirst(RegExp(r'/+$'), '');
    final response = await dio.getUri<Object?>(
      _store.replace(path: '$prefix/wp-json/mobishop/v1/store-changes'),
      options: Options(
        followRedirects: false,
        maxRedirects: 0,
        responseType: ResponseType.json,
        headers: <String, String>{
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
          'X-MobiShop-Session': ?token,
        },
      ),
    );
    if (response.statusCode != 200) {
      throw const FormatException('Store revisions are unavailable.');
    }
    return StoreRevisionSnapshot.parse(
      response.data,
      configuredOrigin: origin,
      authenticatedRequest: token != null,
    );
  }

  static Uri _validateStore(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.contains('..')) {
      throw const FormatException(
        'Live updates require a configured HTTPS store.',
      );
    }
    return uri;
  }
}
