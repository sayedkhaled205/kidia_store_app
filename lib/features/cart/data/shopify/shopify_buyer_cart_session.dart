import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_cart_gateway.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_cart_session_store.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:mobishop_store_app/features/cart/domain/repositories/cart_repository.dart';

/// A guest cart is a buyer-session secret, not a Woo token or a merchant token.
/// Configured Native sessions use scoped OS-secure storage; fixtures use memory.
/// The shell must reset this owner before any future customer-account switch.
class ShopifyBuyerCartSession {
  ShopifyBuyerCartSession(
    CommerceConnection connection, {
    ShopifyCartSessionStore? storage,
  }) : ownerOrigin = connection.storeOrigin,
       apiVersion = connection.shopifyApiVersion,
       _storage = storage ?? MemoryShopifyCartSessionStore() {
    if (connection.platform != CommercePlatform.shopify) {
      throw const FormatException('A Shopify guest cart requires Shopify.');
    }
  }

  final Uri ownerOrigin;
  final String apiVersion;
  final ShopifyCartSessionStore _storage;
  int _generation = 0;
  bool _disposed = false;
  bool _hydrated = false;
  Future<void>? _hydration;
  Future<void> _storageTail = Future<void>.value();
  bool _persistenceDirty = false;
  String? _cartId;
  ShopifyCartSnapshot? _snapshot;
  bool _creationUncertain = false;
  bool _needsReconciliation = false;
  int get generation => _generation;
  String? get cartId => _cartId;
  ShopifyCartSnapshot? get snapshot => _snapshot;
  bool get creationUncertain => _creationUncertain;
  bool get needsReconciliation => _needsReconciliation;

  bool belongsTo(CommerceConnection connection) =>
      connection.platform == CommercePlatform.shopify &&
      connection.storeOrigin == ownerOrigin &&
      connection.shopifyApiVersion == apiVersion;

  Future<void> hydrate(int owner) async {
    _checkOwner(owner);
    if (_hydrated) return;
    final loading = _hydration ??= _load(owner);
    try {
      await loading;
    } catch (_) {
      if (identical(_hydration, loading)) _hydration = null;
      rethrow;
    }
    _checkOwner(owner);
  }

  Future<void> _load(int owner) async {
    await _storageTail;
    _checkOwner(owner);
    final ShopifyCartSessionRecord? record = await _storage.read();
    _checkOwner(owner);
    if (record != null) {
      if (record.cartId != null) _validateCartId(record.cartId!);
      if (record.cartId != null && record.creationUncertain) {
        throw const FormatException(
          'Conflicting stored Shopify guest session.',
        );
      }
      _cartId = record.cartId;
      _creationUncertain = record.creationUncertain;
      _needsReconciliation = _cartId != null;
    }
    _hydrated = true;
  }

  Future<void> accept(ShopifyCartSnapshot value, int owner) async {
    _checkOwner(owner);
    final bool changed =
        _cartId != value.id || _creationUncertain || _persistenceDirty;
    _cartId = value.id;
    _snapshot = value;
    _creationUncertain = false;
    _needsReconciliation = false;
    if (changed) {
      _persistenceDirty = true;
      await _persist(
        owner,
        () => _storage.write(ShopifyCartSessionRecord(cartId: value.id)),
      );
      _persistenceDirty = false;
    }
    _checkOwner(owner);
  }

  Future<void> markUncertain(int owner) async {
    _checkOwner(owner);
    if (_cartId == null) {
      _creationUncertain = true;
      await _persist(
        owner,
        () => _storage.write(
          const ShopifyCartSessionRecord(creationUncertain: true),
        ),
      );
    } else {
      _needsReconciliation = true;
    }
  }

  /// Explicitly abandon this guest owner, e.g. buyer/account/session reset.
  /// In-flight old responses must not be accepted into the new generation.
  Future<void> reset() async {
    _generation++;
    _cartId = null;
    _snapshot = null;
    _creationUncertain = false;
    _needsReconciliation = false;
    _hydrated = true;
    _hydration = null;
    final int owner = _generation;
    await _persist(owner, _storage.clear);
  }

  /// Remove only this buyer's unavailable/expired cart, without a new create.
  Future<void> clearExpired(int owner) async {
    _checkOwner(owner);
    _cartId = null;
    _snapshot = null;
    _creationUncertain = false;
    _needsReconciliation = false;
    _hydrated = true;
    await _persist(owner, _storage.clear);
    _checkOwner(owner);
  }

  /// App/provider disposal cancels old responses but retains encrypted guest
  /// ownership for a cold restart. Only explicit reset/expiry clears this scope.
  void dispose() {
    _disposed = true;
    _generation++;
    _snapshot = null;
    _cartId = null;
  }

  Future<void> _persist(int owner, Future<void> Function() operation) {
    final Future<void> result = _storageTail.then((_) async {
      _checkOwner(owner);
      await operation();
      _checkOwner(owner);
    });
    // Do not poison later scoped cleanup when one OS storage operation fails.
    _storageTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  void _checkOwner(int owner) {
    if (_disposed || owner != _generation) {
      throw const CartRepositoryException(
        kind: CartFailureKind.cancelled,
        message: 'The Shopify buyer session changed.',
      );
    }
  }

  static void _validateCartId(String id) {
    final Uri? uri = Uri.tryParse(id);
    if (uri == null ||
        uri.scheme != 'gid' ||
        uri.host != 'shopify' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'Cart' ||
        uri.pathSegments.last.isEmpty ||
        uri.queryParametersAll['key']?.length != 1 ||
        uri.queryParameters['key']!.isEmpty ||
        id.length > 4096 ||
        id.contains(RegExp(r'[\s\x00-\x1f\x7f]'))) {
      throw const FormatException('Invalid stored Shopify buyer cart ID.');
    }
  }

  @override
  String toString() =>
      'ShopifyBuyerCartSession($ownerOrigin, secrets redacted)';
}
