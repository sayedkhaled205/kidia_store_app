import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local evidence of a completed SDK operation, never an Apple token.
class AppleDeletionCheckpoint {
  const AppleDeletionCheckpoint({
    required this.receipt,
    required this.userId,
    required this.sessionHash,
    required this.intentId,
  });

  final String receipt;
  final int userId;
  final String sessionHash;
  final String intentId;

  static bool isDigest(Object? value) =>
      value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

  bool get isValid =>
      isDigest(receipt) &&
      userId > 0 &&
      isDigest(sessionHash) &&
      isDigest(intentId);

  Map<String, dynamic> toJson() => {
    'receipt': receipt,
    'userId': userId,
    'sessionHash': sessionHash,
    'intentId': intentId,
  };

  static AppleDeletionCheckpoint fromJson(Object? value) {
    if (value is! Map ||
        !isDigest(value['receipt']) ||
        value['userId'] is! int ||
        (value['userId'] as int) < 1 ||
        !isDigest(value['sessionHash']) ||
        !isDigest(value['intentId'])) {
      throw const FormatException('Invalid stored Apple deletion checkpoint');
    }
    return AppleDeletionCheckpoint(
      receipt: value['receipt'] as String,
      userId: value['userId'] as int,
      sessionHash: value['sessionHash'] as String,
      intentId: value['intentId'] as String,
    );
  }
}

class AccountDeletionReceipt {
  const AccountDeletionReceipt({
    required this.receipt,
    required this.userId,
    required this.sessionHash,
    this.appleCheckpoint,
  });

  final String receipt;
  final int userId;
  final String sessionHash;
  final AppleDeletionCheckpoint? appleCheckpoint;

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

  /// Version 1 was an implicit, unversioned single-record shape. Version 2
  /// stores a `records` list keyed by owner so unrelated owners never
  /// contend for the same durable capability.
  static const _collectionVersion = 2;

  /// Reads the receipt for [userId], or the first stored receipt when
  /// [userId] is omitted. Kept for legacy/single-record call sites; callers
  /// that know the acting user should always pass it explicitly.
  Future<AccountDeletionReceipt?> read({int? userId}) =>
      _exclusive(() => _readOne(userId));

  Future<List<AccountDeletionReceipt>> readAll() =>
      _exclusive(() async => List.unmodifiable(await _readAll()));

  Future<AccountDeletionReceipt?> _readOne(int? userId) async {
    final all = await _readAll();
    if (all.isEmpty) return null;
    if (userId == null) return all.first;
    for (final record in all) {
      if (record.userId == userId) return record;
    }
    return null;
  }

  Future<List<AccountDeletionReceipt>> _readAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return const [];
    final value = jsonDecode(raw);
    if (value is Map && value.containsKey('version')) {
      if (value['version'] is! int || value['version'] != _collectionVersion) {
        throw const FormatException(
          'Unsupported stored deletion receipt version',
        );
      }
      final records = value['records'];
      if (records is! List) {
        throw const FormatException(
          'Invalid stored deletion receipt collection',
        );
      }
      final parsed = <AccountDeletionReceipt>[];
      final seenUsers = <int>{};
      final seenReceipts = <String>{};
      for (final entry in records) {
        final record = _parseRecord(entry);
        if (!seenUsers.add(record.userId) ||
            !seenReceipts.add(record.receipt)) {
          throw const FormatException(
            'Duplicate stored deletion receipt entry',
          );
        }
        parsed.add(record);
      }
      return parsed;
    }
    // Legacy, unversioned singleton shape: a lone record at the top level.
    return [_parseRecord(value)];
  }

  AccountDeletionReceipt _parseRecord(Object? value) {
    if (value is! Map ||
        !AppleDeletionCheckpoint.isDigest(value['receipt']) ||
        value['userId'] is! int ||
        (value['userId'] as int) < 1 ||
        !AppleDeletionCheckpoint.isDigest(value['sessionHash'])) {
      throw const FormatException('Invalid stored deletion receipt');
    }
    final checkpoint = value.containsKey('appleCheckpoint')
        ? AppleDeletionCheckpoint.fromJson(value['appleCheckpoint'])
        : null;
    if (checkpoint != null &&
        (checkpoint.receipt != value['receipt'] ||
            checkpoint.userId != value['userId'])) {
      throw const FormatException(
        'Apple checkpoint belongs to another receipt',
      );
    }
    return AccountDeletionReceipt(
      receipt: value['receipt'] as String,
      userId: value['userId'] as int,
      sessionHash: value['sessionHash'] as String,
      appleCheckpoint: checkpoint,
    );
  }

  Future<AccountDeletionReceipt> prepare(int userId, String sessionToken) =>
      _exclusive(() async {
        if (userId < 1 || sessionToken.isEmpty) {
          throw ArgumentError('A current account is required');
        }
        final all = await _readAll();
        final existingIndex = all.indexWhere((r) => r.userId == userId);
        final existing = existingIndex == -1 ? null : all[existingIndex];
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
          // Reauthentication alone must not rebind the completed operation.
          // The server must first confirm the same owner and frozen intent.
          appleCheckpoint: existing?.appleCheckpoint,
        );
        final updated = [...all];
        if (existingIndex == -1) {
          updated.add(record);
        } else {
          updated[existingIndex] = record;
        }
        await _writeAll(updated);
        return record;
      });

  Future<AccountDeletionReceipt> saveAppleCheckpoint(
    AppleDeletionCheckpoint checkpoint,
  ) => _exclusive(() async {
    final all = await _readAll();
    final index = all.indexWhere((r) => r.userId == checkpoint.userId);
    final current = index == -1 ? null : all[index];
    if (!checkpoint.isValid ||
        current == null ||
        current.receipt != checkpoint.receipt ||
        current.sessionHash != checkpoint.sessionHash ||
        (current.appleCheckpoint != null &&
            current.appleCheckpoint!.intentId != checkpoint.intentId)) {
      throw StateError('The deletion receipt changed before saving completion');
    }
    final record = AccountDeletionReceipt(
      receipt: current.receipt,
      userId: current.userId,
      sessionHash: current.sessionHash,
      appleCheckpoint: checkpoint,
    );
    final updated = [...all];
    updated[index] = record;
    await _writeAll(updated);
    return record;
  });

  Future<void> _writeAll(List<AccountDeletionReceipt> records) =>
      _storage.write(
        key: _key,
        value: jsonEncode({
          'version': _collectionVersion,
          'records': records
              .map(
                (record) => {
                  'receipt': record.receipt,
                  'userId': record.userId,
                  'sessionHash': record.sessionHash,
                  if (record.appleCheckpoint != null)
                    'appleCheckpoint': record.appleCheckpoint!.toJson(),
                },
              )
              .toList(),
        }),
      );

  Future<void> clear(String receipt) => _exclusive(() async {
    final all = await _readAll();
    final updated = all.where((r) => r.receipt != receipt).toList();
    if (updated.length == all.length) return;
    if (updated.isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _writeAll(updated);
    }
  });
}
