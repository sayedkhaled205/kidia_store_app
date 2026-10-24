import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'commerce_connection.dart';

/// A restore candidate, never evidence that a customer is authenticated.
/// No profile, password or CSRF token belongs in durable storage.
class OdooCustomerStoredSession51 {
  OdooCustomerStoredSession51({
    required Uri origin,
    required this.sessionId,
    required DateTime expiresAt,
    required this.customerId,
    required this.partnerId,
  }) : origin = CommerceConnection(
         platform: CommercePlatform.odoo,
         storeOrigin: origin,
       ).storeOrigin,
       expiresAt = expiresAt.toUtc() {
    if (!RegExp(r'^[A-Za-z0-9_-]{16,512}$').hasMatch(sessionId) ||
        customerId < 0 ||
        customerId > 9999999999 ||
        partnerId < 0 ||
        partnerId > 9999999999 ||
        (customerId == 0) != (partnerId == 0) ||
        this.expiresAt.isAfter(
          DateTime.now().toUtc().add(const Duration(seconds: 31536000)),
        )) {
      throw const FormatException('Invalid stored Odoo customer session.');
    }
  }

  factory OdooCustomerStoredSession51.fromJson(Object? data) {
    const keys = {
      'v',
      'origin',
      'session_id',
      'expires_at',
      'customer_id',
      'partner_id',
    };
    if (data is! Map ||
        data.length != keys.length ||
        data.keys.any((key) => key is! String || !keys.contains(key)) ||
        data['v'] is! int ||
        !const {1, 2}.contains(data['v']) ||
        data['origin'] is! String ||
        data['session_id'] is! String ||
        data['expires_at'] is! String ||
        data['customer_id'] is! int ||
        data['partner_id'] is! int) {
      throw const FormatException('Invalid stored Odoo customer session.');
    }
    final expiresAt = DateTime.tryParse(data['expires_at'] as String);
    if (expiresAt == null ||
        expiresAt.toUtc().toIso8601String() != data['expires_at']) {
      throw const FormatException('Invalid stored Odoo customer expiry.');
    }
    final record = OdooCustomerStoredSession51(
      origin: Uri.parse(data['origin'] as String),
      sessionId: data['session_id'] as String,
      expiresAt: expiresAt,
      customerId: data['customer_id'] as int,
      partnerId: data['partner_id'] as int,
    );
    // Version 1 remains the exact authenticated contract. Version 2 is an
    // anonymous SID candidate only; zero is never accepted as a customer UID.
    if ((data['v'] == 2) != record.isGuest) {
      throw const FormatException('Invalid stored Odoo identity version.');
    }
    if (record.origin.toString() != data['origin']) {
      throw const FormatException('Invalid stored Odoo customer origin.');
    }
    return record;
  }

  final Uri origin;
  final String sessionId;
  final DateTime expiresAt;
  final int customerId, partnerId;
  bool get isGuest => customerId == 0 && partnerId == 0;
  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  Map<String, Object> toJson() => {
    'v': isGuest ? 2 : 1,
    'origin': origin.toString(),
    'session_id': sessionId,
    'expires_at': expiresAt.toIso8601String(),
    'customer_id': customerId,
    'partner_id': partnerId,
  };

  @override
  String toString() => 'OdooCustomerStoredSession51(secrets redacted)';
}

abstract interface class OdooCustomerSessionStore51 {
  Future<OdooCustomerStoredSession51?> read();
  Future<void> write(OdooCustomerStoredSession51 record);
  Future<void> clear();

  /// Remove a revoked in-flight write without deleting a newer session.
  Future<void> clearIf(OdooCustomerStoredSession51 record);
}

class MemoryOdooCustomerSessionStore51 implements OdooCustomerSessionStore51 {
  OdooCustomerStoredSession51? value;
  @override
  Future<OdooCustomerStoredSession51?> read() async => value;
  @override
  Future<void> write(OdooCustomerStoredSession51 record) async {
    value = record;
  }

  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<void> clearIf(OdooCustomerStoredSession51 record) async {
    if (value != null &&
        jsonEncode(value!.toJson()) == jsonEncode(record.toJson())) {
      value = null;
    }
  }
}

/// Native providers must inject this store. Only the selected Odoo HTTPS
/// origin's encrypted OS storage key is accessed; Woo auth storage is unrelated.
class SecureOdooCustomerSessionStore51 implements OdooCustomerSessionStore51 {
  SecureOdooCustomerSessionStore51({
    required CommerceConnection connection,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       origin = connection.storeOrigin,
       storageKey =
           'mobishop.odoo.customer51.v1.${Uri.encodeComponent(connection.storeOrigin.toString())}' {
    if (connection.platform != CommercePlatform.odoo) {
      throw const FormatException(
        'Odoo customer storage requires an Odoo connection.',
      );
    }
  }

  final FlutterSecureStorage _storage;
  final Uri origin;
  final String storageKey;
  // A disposed provider and its replacement may briefly share an origin.
  // Serialize their storage operations too, not just one client's operations.
  static final _pending = <String, Future<void>>{};

  Future<T> _ordered<T>(Future<T> Function() operation) {
    final result = (_pending[storageKey] ?? Future<void>.value()).then(
      (_) => operation(),
    );
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending[storageKey] = settled;
    settled.then((_) {
      if (identical(_pending[storageKey], settled)) _pending.remove(storageKey);
    });
    return result;
  }

  @override
  Future<OdooCustomerStoredSession51?> read() => _ordered(() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return null;
    if (raw.length > 4096) {
      throw const FormatException('Stored Odoo session is oversized.');
    }
    final record = OdooCustomerStoredSession51.fromJson(jsonDecode(raw));
    if (record.origin != origin) {
      throw const FormatException('Stored Odoo origin does not match.');
    }
    return record;
  });

  @override
  Future<void> write(OdooCustomerStoredSession51 record) => _ordered(() {
    if (record.origin != origin || record.isExpired) {
      throw const FormatException(
        'Stored Odoo session does not match this origin.',
      );
    }
    return _storage.write(key: storageKey, value: jsonEncode(record.toJson()));
  });

  @override
  Future<void> clear() => _ordered(() => _storage.delete(key: storageKey));

  @override
  Future<void> clearIf(OdooCustomerStoredSession51 record) => _ordered(
    () async {
      if (record.origin != origin) return;
      if (await _storage.read(key: storageKey) == jsonEncode(record.toJson())) {
        await _storage.delete(key: storageKey);
      }
    },
  );

  @override
  String toString() =>
      'SecureOdooCustomerSessionStore51(origin scoped, secrets redacted)';
}
