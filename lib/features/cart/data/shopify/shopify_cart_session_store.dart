import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';

class ShopifyCartSessionRecord {
  const ShopifyCartSessionRecord({this.cartId, this.creationUncertain = false});
  final String? cartId;
  final bool creationUncertain;
  @override
  String toString() => 'ShopifyCartSessionRecord(secrets redacted)';
}

abstract interface class ShopifyCartSessionStore {
  Future<ShopifyCartSessionRecord?> read();
  Future<void> write(ShopifyCartSessionRecord record);
  Future<void> clear();
}

/// Injectable contract fixture; configured Native providers use secure storage.
class MemoryShopifyCartSessionStore implements ShopifyCartSessionStore {
  ShopifyCartSessionRecord? record;
  @override
  Future<ShopifyCartSessionRecord?> read() async => record;
  @override
  Future<void> write(ShopifyCartSessionRecord record) async {
    this.record = record;
  }

  @override
  Future<void> clear() async {
    record = null;
  }
}

/// Only this Shopify canonical origin's guest record is accessed. The opaque
/// full cart ID/key is stored in OS-encrypted storage, never SharedPreferences,
/// a URL, builder storage, logs, or an exported app design configuration.
class SecureShopifyCartSessionStore implements ShopifyCartSessionStore {
  SecureShopifyCartSessionStore({
    required CommerceConnection connection,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       storageKey =
           'mobishop.shopify.guest_cart.v1.${Uri.encodeComponent(connection.storeOrigin.toString())}' {
    if (connection.platform != CommercePlatform.shopify) {
      throw const FormatException(
        'Shopify guest storage requires a Shopify connection.',
      );
    }
  }
  final FlutterSecureStorage _storage;
  final String storageKey;
  @override
  Future<ShopifyCartSessionRecord?> read() async {
    final String? raw = await _storage.read(key: storageKey);
    if (raw == null) return null;
    final dynamic data = jsonDecode(raw);
    if (data is! Map ||
        data['v'] != 1 ||
        data['creation_uncertain'] is! bool ||
        (data['cart_id'] != null && data['cart_id'] is! String)) {
      throw const FormatException('Invalid stored Shopify guest session.');
    }
    return ShopifyCartSessionRecord(
      cartId: data['cart_id'] as String?,
      creationUncertain: data['creation_uncertain'] as bool,
    );
  }

  @override
  Future<void> write(ShopifyCartSessionRecord record) => _storage.write(
    key: storageKey,
    value: jsonEncode({
      'v': 1,
      'cart_id': record.cartId,
      'creation_uncertain': record.creationUncertain,
    }),
  );
  @override
  Future<void> clear() => _storage.delete(key: storageKey);
  @override
  String toString() =>
      'SecureShopifyCartSessionStore(origin scoped, secrets redacted)';
}
