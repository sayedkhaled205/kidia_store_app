import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_order_result.dart';

/// A dispatch marker is not evidence that an order was created or rejected.
/// It has no expiry: only a known response/recovery contract can resolve it.
class CheckoutPendingAttempt {
  const CheckoutPendingAttempt({
    required this.idempotencyKey,
    required this.createdAtMicros,
    this.confirmedResult,
  });

  final String idempotencyKey;
  final int createdAtMicros;

  /// A positive order receipt, without the potentially secret redirect URL.
  /// The server's payment status is retained; this does not complete payment.
  final CheckoutOrderResult? confirmedResult;
  bool get isUnresolved => confirmedResult == null;

  @override
  String toString() => 'CheckoutPendingAttempt(details redacted)';
}

abstract class CheckoutPendingAttemptStore {
  /// Shared by all instances using this namespace in this Dart isolate.
  /// This is not a cross-process atomic lock or server-side idempotency.
  String get namespace;
  static final Map<String, Future<void>> _tails = <String, Future<void>>{};

  Future<T> exclusive<T>(Future<T> Function() operation) async {
    final Future<void> previous = _tails[namespace] ?? Future<void>.value();
    final Completer<void> release = Completer<void>();
    final Future<void> tail = release.future;
    _tails[namespace] = tail;
    await previous;
    try {
      return await operation();
    } finally {
      release.complete();
      if (identical(_tails[namespace], tail)) _tails.remove(namespace);
    }
  }

  Future<CheckoutPendingAttempt?> read();
  Future<void> write(CheckoutPendingAttempt attempt);

  /// Repository-only release after a proven pre-dispatch/validation rejection.
  /// Never use this to let a customer dismiss an unknown outcome.
  Future<void> clearKnownRejection(String expectedIdempotencyKey);
}

/// An isolated fixture/default for legacy repository host tests only.
/// Configured Native checkout must inject its secure customer-scoped store.
class MemoryCheckoutPendingAttemptStore extends CheckoutPendingAttemptStore {
  CheckoutPendingAttempt? value;

  @override
  late final String namespace = 'checkout-memory-${identityHashCode(this)}';
  @override
  Future<CheckoutPendingAttempt?> read() async => value;
  @override
  Future<void> write(CheckoutPendingAttempt attempt) async => value = attempt;
  @override
  Future<void> clearKnownRejection(String expectedIdempotencyKey) async {
    if (value?.idempotencyKey == expectedIdempotencyKey) value = null;
  }
}

/// Injectable narrow adapter: host tests never invoke OS storage channels.
abstract interface class CheckoutAttemptStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureCheckoutAttemptStorage implements CheckoutAttemptStorage {
  SecureCheckoutAttemptStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: _androidOptions,
            iOptions: _iosOptions,
          );

  // A storage failure must never erase an unresolved dispatch and make it
  // appear safe to retry. The namespace isolates data, key preferences and
  // Android KeyStore aliases from the auth/social adapters' default bucket.
  static const AndroidOptions _androidOptions = AndroidOptions(
    resetOnError: false,
    storageNamespace: 'mobishop_checkout_attempts_v1',
  );
  // Keep the recovery marker in a separate Keychain service, not the auth
  // bucket. Locked/unavailable Keychain reads propagate and fail closed.
  static const IOSOptions _iosOptions = IOSOptions(
    accountName: 'mobishop_checkout_attempts_v1',
    synchronizable: false,
  );
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read(String key) =>
      _storage.read(key: key, aOptions: _androidOptions, iOptions: _iosOptions);
  @override
  Future<void> write(String key, String value) => _storage.write(
    key: key,
    value: value,
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );
  @override
  Future<void> delete(String key) => _storage.delete(
    key: key,
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );
}

/// The stable identity scope survives logout/login, a fresh cart, and restart.
/// Store install paths are included; tokens, addresses, cart bodies, email and
/// redirect URLs are neither stored nor used as keys. No marker auto-expiry.
class SecureCheckoutPendingAttemptStore extends CheckoutPendingAttemptStore {
  SecureCheckoutPendingAttemptStore({
    required Uri storeUri,
    required int customerId,
    CheckoutAttemptStorage? storage,
  }) : _storage = storage ?? SecureCheckoutAttemptStorage(),
       namespace = _scopeKey(storeUri, customerId);

  final CheckoutAttemptStorage _storage;
  @override
  final String namespace;

  static String _scopeKey(Uri storeUri, int customerId) {
    if (customerId <= 0 ||
        storeUri.scheme.toLowerCase() != 'https' ||
        !storeUri.hasAuthority ||
        storeUri.host.isEmpty ||
        storeUri.userInfo.isNotEmpty ||
        storeUri.hasQuery ||
        storeUri.hasFragment) {
      throw const FormatException('Checkout requires a stable customer scope.');
    }
    final String host = storeUri.host.toLowerCase();
    final int port = storeUri.hasPort ? storeUri.port : 443;
    final String install = storeUri.pathSegments
        .where((String segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    final String scope = jsonEncode(<Object>[
      'woocommerce',
      'https',
      host,
      port,
      install,
      customerId,
    ]);
    return 'mobishop.checkout_attempt.v1.${sha256.convert(utf8.encode(scope))}';
  }

  @override
  Future<CheckoutPendingAttempt?> read() async {
    final String? raw = await _storage.read(namespace);
    if (raw == null) return null;
    final dynamic data = jsonDecode(raw);
    if (data is! Map ||
        data['v'] != 1 ||
        data['key'] is! String ||
        !_validKey(data['key'] as String) ||
        data['created_at_micros'] is! int ||
        (data['created_at_micros'] as int) <= 0) {
      throw const FormatException(
        'Unable to verify the stored checkout attempt.',
      );
    }
    CheckoutOrderResult? result;
    if (data['receipt'] != null) {
      final dynamic receipt = data['receipt'];
      if (receipt is! Map ||
          receipt['order_id'] is! int ||
          (receipt['order_id'] as int) <= 0 ||
          !_validStatus(receipt['status']) ||
          !_validStatus(receipt['payment_status'])) {
        throw const FormatException('Unable to verify the checkout receipt.');
      }
      result = CheckoutOrderResult(
        orderId: receipt['order_id'] as int,
        status: receipt['status'] as String,
        paymentStatus: receipt['payment_status'] as String,
      );
    }
    return CheckoutPendingAttempt(
      idempotencyKey: data['key'] as String,
      createdAtMicros: data['created_at_micros'] as int,
      confirmedResult: result,
    );
  }

  @override
  Future<void> write(CheckoutPendingAttempt attempt) async {
    final CheckoutOrderResult? result = attempt.confirmedResult;
    if (!_validKey(attempt.idempotencyKey) ||
        attempt.createdAtMicros <= 0 ||
        (result != null &&
            (result.orderId <= 0 ||
                !_validStatus(result.status) ||
                !_validStatus(result.paymentStatus)))) {
      throw const FormatException('Invalid checkout attempt marker.');
    }
    await _storage.write(
      namespace,
      jsonEncode(<String, Object>{
        'v': 1,
        'key': attempt.idempotencyKey,
        'created_at_micros': attempt.createdAtMicros,
        if (result != null)
          'receipt': <String, Object>{
            'order_id': result.orderId,
            'status': result.status,
            'payment_status': result.paymentStatus,
          },
      }),
    );
    final CheckoutPendingAttempt? stored = await read();
    if (stored?.idempotencyKey != attempt.idempotencyKey ||
        stored?.createdAtMicros != attempt.createdAtMicros ||
        stored?.confirmedResult?.orderId != result?.orderId ||
        stored?.confirmedResult?.status != result?.status ||
        stored?.confirmedResult?.paymentStatus != result?.paymentStatus) {
      throw const FormatException('The checkout marker could not be verified.');
    }
  }

  @override
  Future<void> clearKnownRejection(String expectedIdempotencyKey) async {
    final CheckoutPendingAttempt? attempt = await read();
    if (attempt == null) return;
    if (attempt.idempotencyKey != expectedIdempotencyKey ||
        !attempt.isUnresolved) {
      throw const FormatException(
        'The checkout attempt changed before release.',
      );
    }
    await _storage.delete(namespace);
    if (await read() != null) {
      throw const FormatException(
        'The checkout attempt release was not verified.',
      );
    }
  }

  static bool _validKey(String key) =>
      RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(key);
  static bool _validStatus(dynamic value) =>
      value is String && RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(value);
  @override
  String toString() => 'SecureCheckoutPendingAttemptStore(scope redacted)';
}
