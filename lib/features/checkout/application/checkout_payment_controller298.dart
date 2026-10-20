import 'package:flutter/foundation.dart';
import 'package:mobishop_store_app/features/orders/domain/entities/customer_order.dart';

enum CheckoutPaymentState298 {
  checking,
  pending,
  paid,
  received,
  closed,
  unavailable,
}

/// Only the store's authenticated order lookup supplies a payment destination.
/// A gateway redirect in the checkout response is never itself an allowlist.
abstract final class CheckoutPaymentPolicy298 {
  static Uri? destination(Uri store, CustomerOrder order) {
    final uri = order.paymentUri;
    if (order.id <= 0 ||
        order.isPaid != false ||
        order.needsPayment != true ||
        uri == null ||
        store.scheme != 'https' ||
        store.host.isEmpty ||
        store.userInfo.isNotEmpty ||
        store.hasQuery ||
        store.hasFragment ||
        uri.scheme != 'https' ||
        uri.host != store.host ||
        uri.port != store.port ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.toString().length > 4096) {
      return null;
    }
    final prefix = store.path.replaceFirst(RegExp(r'/+$'), '');
    // The authenticated server derives this path from its Woo endpoint
    // configuration. Keep custom/localized slugs without trusting a gateway's
    // arbitrary path or widening origin/query trust.
    final expectedPath = order.paymentEndpointPath;
    if (!expectedPath.startsWith('$prefix/') ||
        expectedPath.startsWith('//') ||
        expectedPath.contains('//') ||
        !RegExp('/${order.id}/?\$').hasMatch(expectedPath) ||
        expectedPath.split('/').any((part) {
          final dots = part.replaceAll(
            RegExp('%2e', caseSensitive: false),
            '.',
          );
          return dots == '.' || dots == '..';
        }) ||
        RegExp(
          r'[%](?:25|2f|5c|3f|23)',
          caseSensitive: false,
        ).hasMatch(expectedPath)) {
      return null;
    }
    try {
      final canonical = Uri.parse(expectedPath);
      final decoded = Uri.decodeComponent(canonical.path);
      if (RegExp(r'[\\?#\x00-\x20\x7f]').hasMatch(decoded) ||
          decoded.split('/').any((p) => p == '.' || p == '..') ||
          canonical.hasQuery ||
          canonical.hasFragment ||
          uri.path != canonical.path) {
        return null;
      }
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
    final query = uri.queryParametersAll;
    if (query.length != 2 ||
        query['pay_for_order']?.length != 1 ||
        query['pay_for_order']?.single != 'true' ||
        query['key']?.length != 1 ||
        !RegExp(
          r'^wc_order_[A-Za-z0-9]+$',
        ).hasMatch(query['key']?.single ?? '')) {
      return null;
    }
    return uri;
  }
}

/// Reads one existing order. This class has no order/payment write dependency.
class CheckoutPaymentController298 extends ChangeNotifier {
  CheckoutPaymentController298({
    required this.orderId,
    required this.storeUri,
    required this.readOrder,
    required this.launch,
    required this.sessionIsCurrent,
  });

  final int orderId;
  final Uri storeUri;
  final Future<CustomerOrder> Function(int orderId) readOrder;
  final Future<bool> Function(Uri destination) launch;
  final bool Function() sessionIsCurrent;
  CheckoutPaymentState298 state = CheckoutPaymentState298.checking;
  CustomerOrder? order;
  bool busy = false;
  bool openFailed = false;
  bool waitingForReturn = false;
  bool _resumePending = false;
  bool _disposed = false;

  bool get canPay =>
      !busy &&
      state == CheckoutPaymentState298.pending &&
      order != null &&
      CheckoutPaymentPolicy298.destination(storeUri, order!) != null;

  bool get _current => !_disposed && sessionIsCurrent();

  Future<bool> _read() async {
    if (!_current) return false;
    final fresh = await readOrder(orderId);
    if (!_current) return false;
    if (fresh.id != orderId ||
        fresh.isPaid == null ||
        fresh.needsPayment == null ||
        (fresh.isPaid! && fresh.needsPayment!)) {
      throw const FormatException('Unverified payment status.');
    }
    order = fresh;
    final offline = const {
      'cod',
      'bacs',
      'cheque',
    }.contains(fresh.paymentMethod);
    state = const {'cancelled', 'refunded', 'trash'}.contains(fresh.status)
        ? CheckoutPaymentState298.closed
        : fresh.isPaid! && !offline
        ? CheckoutPaymentState298.paid
        : fresh.needsPayment!
        ? CheckoutPaymentState298.pending
        : const {'processing', 'completed', 'on-hold'}.contains(fresh.status)
        ? CheckoutPaymentState298.received
        : CheckoutPaymentState298.closed;
    return true;
  }

  Future<void> refresh() async {
    if (busy || _disposed) return;
    busy = true;
    openFailed = false;
    _notify();
    try {
      if (!await _read()) _unavailable();
    } catch (_) {
      _unavailable();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> openPayment() async {
    if (busy || _disposed) return;
    busy = true;
    openFailed = false;
    var verified = false;
    _notify();
    try {
      // Fresh ownership/payment facts before every explicit launch. This also
      // prevents reopening a stale payment link for an already-paid order.
      if (!await _read()) {
        _unavailable();
        return;
      }
      verified = true;
      final uri = state == CheckoutPaymentState298.pending
          ? CheckoutPaymentPolicy298.destination(storeUri, order!)
          : null;
      if (uri == null) {
        openFailed = state == CheckoutPaymentState298.pending;
        return;
      }
      if (!_current) {
        _unavailable();
        return;
      }
      waitingForReturn = true;
      final opened = await launch(uri);
      if (!_current) {
        _unavailable();
        return;
      }
      openFailed = !opened;
      if (!opened) waitingForReturn = false;
      // Browser dispatch/closure is NOT proof of payment. Only refresh() can
      // reconcile the same order with current authenticated server evidence.
    } catch (_) {
      openFailed = true;
      waitingForReturn = false;
      if (!verified || !_current) _unavailable();
    } finally {
      busy = false;
      _notify();
      if (_resumePending) {
        _resumePending = false;
        await returnedToApp();
      }
    }
  }

  Future<void> returnedToApp() async {
    if (!waitingForReturn || _disposed) return;
    if (busy) {
      _resumePending = true;
      return;
    }
    waitingForReturn = false;
    await refresh();
  }

  void _unavailable() {
    order = null;
    state = CheckoutPaymentState298.unavailable;
    waitingForReturn = false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
