import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AccountDeletionReceipt {
  const AccountDeletionReceipt({
    required this.receipt,
    required this.userId,
    required this.sessionHash,
  });

  final String receipt;
  final int userId;
  final String sessionHash;

  bool matchesSession(String token) => sessionHash == hashSession(token);
  static String hashSession(String token) =>
      sha256.convert(utf8.encode(token)).toString();
}

/// Persist before sending: a lost response must not lose the deletion outcome.
/// This bearer capability is device-local and scoped to the connected store.
class AccountDeletionReceiptStore {
  AccountDeletionReceiptStore(String storeUrl, {FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage(),
      _key =
          'mobishop_deletion_receipt_${sha256.convert(utf8.encode(_scope(storeUrl)))}';

  final FlutterSecureStorage _storage;
  final String _key;
  static final Map<String, Future<void>> _pending = {};

  static String _scope(String value) {
    final uri = Uri.parse(value.trim());
    return Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString().replaceFirst(RegExp(r'/+$'), '');
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = (_pending[_key] ?? Future<void>.value()).then(
      (_) => action(),
    );
    final settled = result.then<void>((_) {}, onError: (Object _) {});
    _pending[_key] = settled;
    settled.whenComplete(() {
      if (identical(_pending[_key], settled)) _pending.remove(_key);
    });
    return result;
  }

  Future<AccountDeletionReceipt?> read() => _exclusive(_read);

  Future<AccountDeletionReceipt?> _read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final value = jsonDecode(raw);
    if (value is! Map ||
        value['receipt'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(value['receipt'] as String) ||
        value['userId'] is! int ||
        (value['userId'] as int) < 1 ||
        value['sessionHash'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(value['sessionHash'] as String)) {
      throw const FormatException('Invalid stored deletion receipt');
    }
    return AccountDeletionReceipt(
      receipt: value['receipt'] as String,
      userId: value['userId'] as int,
      sessionHash: value['sessionHash'] as String,
    );
  }

  Future<AccountDeletionReceipt> prepare(int userId, String sessionToken) =>
      _exclusive(() async {
        if (userId < 1 || sessionToken.isEmpty) {
          throw ArgumentError('A current account is required');
        }
        final existing = await _read();
        if (existing != null && existing.userId != userId) {
          throw StateError(
            'Another deletion receipt is still pending on this device',
          );
        }
        final random = Random.secure();
        final receipt =
            existing?.receipt ??
            List.generate(
              32,
              (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
            ).join();
        final record = AccountDeletionReceipt(
          receipt: receipt,
          userId: userId,
          sessionHash: AccountDeletionReceipt.hashSession(sessionToken),
        );
        await _storage.write(
          key: _key,
          value: jsonEncode({
            'receipt': record.receipt,
            'userId': record.userId,
            'sessionHash': record.sessionHash,
          }),
        );
        return record;
      });

  Future<void> clear(String receipt) => _exclusive(() async {
    if ((await _read())?.receipt == receipt) await _storage.delete(key: _key);
  });
}
