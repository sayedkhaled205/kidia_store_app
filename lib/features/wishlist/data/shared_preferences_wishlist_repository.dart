import 'dart:convert';

import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef WishlistPreferencesLoader = Future<SharedPreferences> Function();

class SharedPreferencesWishlistRepository implements WishlistRepository {
  SharedPreferencesWishlistRepository({
    required String storeUrl,
    WishlistPreferencesLoader? preferencesLoader,
  }) : _storageKey = _buildStorageKey(storeUrl),
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  factory SharedPreferencesWishlistRepository.forConfiguredStore({
    WishlistPreferencesLoader? preferencesLoader,
  }) {
    return SharedPreferencesWishlistRepository(
      storeUrl: AppConfig.apiBaseUrl,
      preferencesLoader: preferencesLoader,
    );
  }

  static const String _keyPrefix = 'woo_mobile.wishlist.v1';

  final String _storageKey;
  final WishlistPreferencesLoader _preferencesLoader;

  String get storageKey => _storageKey;

  @override
  Future<List<int>> loadProductIds() async {
    try {
      final SharedPreferences preferences = await _preferencesLoader();
      final List<String> rawValues =
          preferences.getStringList(_storageKey) ?? const <String>[];
      final List<int> normalized = _normalizeIds(
        rawValues.map((String value) => int.tryParse(value.trim()) ?? 0),
      );
      final List<String> normalizedStrings = normalized
          .map((int id) => id.toString())
          .toList(growable: false);
      if (!_sameStrings(rawValues, normalizedStrings)) {
        final bool repaired = await preferences.setStringList(
          _storageKey,
          normalizedStrings,
        );
        if (!repaired) {
          throw const WishlistStorageException(
            'Unable to repair the local wishlist.',
          );
        }
      }
      return List<int>.unmodifiable(normalized);
    } on WishlistStorageException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        WishlistStorageException(
          'Unable to read the local wishlist.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<void> saveProductIds(List<int> productIds) async {
    final List<String> values = _normalizeIds(
      productIds,
    ).map((int id) => id.toString()).toList(growable: false);
    try {
      final SharedPreferences preferences = await _preferencesLoader();
      final bool saved = await preferences.setStringList(_storageKey, values);
      if (!saved) {
        throw const WishlistStorageException(
          'Unable to save the local wishlist.',
        );
      }
    } on WishlistStorageException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        WishlistStorageException(
          'Unable to save the local wishlist.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  static List<int> _normalizeIds(Iterable<int> productIds) {
    final Set<int> seen = <int>{};
    final List<int> result = <int>[];
    for (final int productId in productIds) {
      if (productId > 0 && seen.add(productId)) {
        result.add(productId);
      }
    }
    return result;
  }

  static bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  static String _buildStorageKey(String storeUrl) {
    final String scope = _canonicalStoreScope(storeUrl);
    final String encoded = base64Url
        .encode(utf8.encode(scope))
        .replaceAll('=', '');
    return '$_keyPrefix.$encoded';
  }

  static String _canonicalStoreScope(String storeUrl) {
    final String trimmed = storeUrl.trim();
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return trimmed.isEmpty
          ? 'unconfigured-local-store'
          : trimmed.toLowerCase();
    }

    final String scheme = uri.scheme.toLowerCase();
    final String host = uri.host.toLowerCase();
    final bool defaultPort =
        (scheme == 'https' && uri.port == 443) ||
        (scheme == 'http' && uri.port == 80);
    final String port = uri.hasPort && !defaultPort ? ':${uri.port}' : '';
    String path = uri.path.trim();
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path == '/') {
      path = '';
    }
    return '$scheme://$host$port$path';
  }
}
