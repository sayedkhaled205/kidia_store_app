import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';

typedef KashierPaymentRunner92 =
    Future<void> Function({
      required String sessionId,
      required void Function(KashierPaymentResult result) onSuccess,
      required void Function(KashierPaymentError error) onFailure,
      void Function(KashierPaymentPending pending)? onPending,
    });

/// Keep SDK failure/cancellation distinct from a completed payment presentation.
/// Never retry a payment automatically or expose provider payloads/card details.
Future<void> presentKashierSession92(
  String session,
  String mode,
  bool arabic, {
  KashierPaymentRunner92? runner,
}) async {
  KashierSDK.initialize(
    mode: mode == 'live' ? KashierMode.live : KashierMode.test,
    language: arabic ? KashierLanguage.ar : KashierLanguage.en,
  );
  final finished = Completer<void>();
  KashierErrorCode? failure;
  void complete() {
    if (!finished.isCompleted) finished.complete();
  }

  await (runner ?? KashierSDK.startPayment)(
    sessionId: session,
    onSuccess: (_) => complete(),
    onPending: (_) => complete(),
    onFailure: (error) {
      if (finished.isCompleted) return;
      failure = error.code;
      complete();
    },
  );
  await finished.future;
  if (failure != null) throw StateError('Native payment: ${failure!.name}');
}

/// One customer, one merchant, one existing order. No website checkout fallback.
class NativePaymentClient92 {
  NativePaymentClient92({
    required this.store,
    required this.token,
    Dio? dio,
    Future<void> Function(Duration duration)? wait,
    Future<void> Function(String session, String mode, bool arabic)?
    presentSession,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 35),
             ),
           ),
       _presentSession = presentSession ?? presentKashierSession92,
       _wait = wait ?? Future<void>.delayed;
  final Uri store;
  final String? Function() token;
  final Dio _dio;
  final Future<void> Function(Duration duration) _wait;
  final Future<void> Function(String session, String mode, bool arabic)
  _presentSession;

  Future<Map<String, dynamic>> _request(int id, {bool prepare = false}) async {
    final session = token();
    if (id <= 0 ||
        session == null ||
        session.isEmpty ||
        store.scheme != 'https' ||
        store.userInfo.isNotEmpty ||
        store.hasQuery ||
        store.hasFragment) {
      throw StateError('A current customer and HTTPS merchant are required.');
    }
    final prefix = store.path.replaceFirst(RegExp(r'/+$'), '');
    final uri = store.replace(
      path:
          '$prefix/wp-json/mobishop/v1/customer/orders/$id/native-payment${prepare ? '' : '/status'}',
    );
    final response = await _dio.requestUri<dynamic>(
      uri,
      options: Options(
        method: prepare ? 'POST' : 'GET',
        followRedirects: false,
        headers: {
          'Accept': 'application/json',
          'X-MobiShop-Channel': 'mobile',
          'X-MobiShop-Session': session,
        },
      ),
    );
    if (token() != session ||
        response.realUri.origin != store.origin ||
        response.statusCode != 200 ||
        response.data is! Map) {
      throw StateError('The merchant payment response could not be verified.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['order_id'] != id) {
      throw StateError('Payment belongs to another order.');
    }
    return data;
  }

  Future<void> reconcile(int id) async {
    await _request(id);
  }

  /// Read-only settlement window. Webhooks may arrive after the SDK callback.
  /// Never replay a charge; an unresolved result remains an existing order.
  Future<bool> confirmPayment(int id) async {
    final identity = token();
    for (var attempt = 0; attempt < 6; attempt++) {
      if (attempt > 0) await _wait(Duration(seconds: attempt));
      if (identity == null || token() != identity) {
        throw StateError('The payment customer changed.');
      }
      final status = await _request(id);
      if (status['paid'] == true && const {'processing', 'completed'}.contains(status['status'])) return true;
      if (const {'failed', 'cancelled', 'refunded'}.contains(status['status'])) return false;
    }
    return false;
  }

  /// Used by the inline SDK form after the buyer's single confirmation.
  /// The SDK result is provisional; only this authenticated merchant read can
  /// produce a paid result. No retry or second order is issued on any failure.
  Future<bool> payInline(
    int id, {
    required KashierInlineCardController card,
    required bool arabic,
    required String amount,
    required String currency,
  }) async {
    final identity = token();
    final data = await _request(id, prepare: true);
    if (data['adapter'] != 'kashier' ||
        data['session_id'] is! String ||
        !RegExp(r'^[a-f0-9]{24}$').hasMatch(data['session_id'] as String) ||
        !const {'live', 'test'}.contains(data['mode']) ||
        data['amount'] != amount ||
        data['currency'] != currency) {
      throw StateError('Payment no longer matches the confirmed total.');
    }
    // Even cancellation/timeout may settle. Never infer failure from a callback.
    try {
      await card.pay(
        sessionId: data['session_id'] as String,
        mode: data['mode'] == 'live' ? KashierMode.live : KashierMode.test,
        language: arabic ? KashierLanguage.ar : KashierLanguage.en,
        expectedAmount: amount,
        expectedCurrency: currency,
        canContinue: () => identity != null && token() == identity,
      );
    } catch (_) {
      // Do not expose SDK error payloads or raw card/provider responses.
    }
    if (token() != identity) throw StateError('The payment customer changed.');
    return confirmPayment(id);
  }

  Future<bool> present(int id, {required bool arabic}) async {
    final data = await _request(id, prepare: true);
    if (data['adapter'] != 'kashier' ||
        data['session_id'] is! String ||
        !RegExp(r'^[a-f0-9]{24}$').hasMatch(data['session_id'] as String) ||
        !const {'live', 'test'}.contains(data['mode'])) {
      throw StateError('This payment method has no verified native adapter.');
    }
    try {
      await _presentSession(
        data['session_id'] as String,
        data['mode'] as String,
        arabic,
      );
    } finally {
      // A failed/cancelled SDK flow can still be settling. Reconcile this order
      // too, without ever issuing another order or payment automatically.
      await reconcile(id);
    }
    return true;
  }
}

/// SDK owns card entry and 3DS only; addresses, shipping and order UI are Flutter.
class NativePaymentHost92 extends StatelessWidget {
  const NativePaymentHost92({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => KashierPaymentProvider(child: child);
}
