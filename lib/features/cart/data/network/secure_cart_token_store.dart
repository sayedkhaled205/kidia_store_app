import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cart_token_store.dart';

/// A session fingerprint binds persisted baskets without storing the auth token.
class CartTokenOwner {
  CartTokenOwner(this.userId, String sessionToken)
    : fingerprint = '$userId:${sha256.convert(utf8.encode(sessionToken))}';

  final int userId;
  final String fingerprint;
}

/// One encrypted, store-scoped basket; it can only be restored by its owner.
class SecureCartTokenStore extends MemoryCartTokenStore
    implements RestorableCartTokenStore {
  SecureCartTokenStore({
    required Uri storeUri,
    required this.currentOwner,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       storageKey =
           'mobishop.woo.cart.v1.${Uri.encodeComponent(storeUri.toString().replaceFirst(RegExp(r'/$'), ''))}';

  final FlutterSecureStorage _storage;
  final Future<CartTokenOwner?> Function() currentOwner;
  final String storageKey;
  CartTokenOwner? _owner;
  bool _ownerKnown = false;
  final Set<String?> _adoptableOwners = {};
  int _ownerRevision = 0;
  Future<void>? _restoring;
  Future<void> _pending = Future.value();
  static final Map<String, Future<void>> _queues = {};

  void _enqueue(Future<void> Function() action) {
    final result = (_queues[storageKey] ?? Future<void>.value()).then(
      (_) => action(),
    );
    _pending = result;
    final settled = result.then<void>((_) {}, onError: (Object _) {});
    _queues[storageKey] = settled;
    unawaited(
      settled.whenComplete(() {
        if (identical(_queues[storageKey], settled)) _queues.remove(storageKey);
      }),
    );
  }

  @override
  Future<void> restore() => _restoring ??= _restore();

  Future<void> _restore() async {
    final revision = generation;
    try {
      final restoredOwner = await currentOwner();
      if (revision != generation) return;
      if (!_ownerKnown) {
        _owner = restoredOwner;
        _ownerKnown = true;
      }
      while (revision == generation) {
        final ownerRevision = _ownerRevision;
        await (_queues[storageKey] ?? Future<void>.value());
        if (revision != generation) return;
        final raw = await _storage.read(key: storageKey);
        if (revision != generation) return;
        if (ownerRevision != _ownerRevision) continue;
        if (raw == null) return;
        Object? record;
        try {
          record = jsonDecode(raw);
        } on FormatException {
          record = null;
        }
        if (record is Map &&
            record.containsKey('owner') &&
            (record['owner'] == _owner?.fingerprint ||
                _adoptableOwners.contains(record['owner'])) &&
            record['token'] is String &&
            (record['token'] as String).trim().isNotEmpty) {
          super.write(record['token'] as String);
          if (record['owner'] != _owner?.fingerprint) {
            _persist();
            await flush();
          }
          _adoptableOwners.clear();
        } else {
          _enqueue(() => _storage.delete(key: storageKey));
          await flush();
        }
        return;
      }
    } catch (_) {
      _restoring = null;
      rethrow;
    }
  }

  /// Login promotes the active guest basket. Logout or a different customer
  /// clears it. Initial auth restoration leaves the matching disk record intact.
  void setOwner(CartTokenOwner? value) {
    if (_ownerKnown && _owner?.fingerprint == value?.fingerprint) return;
    if (_ownerKnown && _owner != null && _owner?.userId != value?.userId) {
      clear();
    } else if (_ownerKnown) {
      // An explicit login or same-customer refresh may finish while disk is
      // still loading. Only this known predecessor may transfer its basket.
      _adoptableOwners.add(_owner?.fingerprint);
    }
    _owner = value;
    _ownerKnown = true;
    _ownerRevision++;
    if (read() != null) _persist();
  }

  void _persist() {
    final token = read();
    if (token == null) return;
    final value = jsonEncode({'owner': _owner?.fingerprint, 'token': token});
    _enqueue(() => _storage.write(key: storageKey, value: value));
  }

  @override
  void write(String token) {
    super.write(token);
    _persist();
  }

  @override
  void clear() {
    _adoptableOwners.clear();
    super.clear();
    _enqueue(() => _storage.delete(key: storageKey));
  }

  @override
  Future<void> flush() => _pending;
}
