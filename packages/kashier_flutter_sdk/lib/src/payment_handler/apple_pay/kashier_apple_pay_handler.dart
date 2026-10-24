import '../../../models/kashier_payment_error.dart';
import '../../../models/kashier_payment_pending.dart';
import '../../../models/kashier_payment_result.dart';
import '../../models/kashier_session.dart';
import '../../kashier_api.dart';
import '../../kashier_bridge.dart';
import '../../kashier_connectivity.dart';
import '../kashier_payment_handler.dart';

/// Apple Pay payment handler.
///
/// Orchestrates the Apple Pay payment flow across 3 bridge crossings:
/// 1. DOWN: Send payment config (incl. merchant ID) to native (present sheet)
/// 2. UP: Receive encrypted token from native (Apple Pay authorized)
/// 3. DOWN: Tell native to finalize the sheet (success/failure)
///
/// Native in-app Apple Pay needs no merchant-validation handshake: the app's
/// signed Apple Pay entitlement already establishes merchant trust.
class KashierApplePayHandler extends KashierPaymentHandler {
  final KashierApi _api;
  final KashierBridge _bridge;

  /// The merchant's own Apple Pay Merchant ID, passed to
  /// [KashierSDK.initialize]. Apple Pay is unavailable when this is null/empty.
  final String? _appleMerchantId;

  KashierApplePayHandler({
    required KashierApi api,
    required KashierBridge bridge,
    String? appleMerchantId,
  })  : _api = api,
        _bridge = bridge,
        _appleMerchantId = appleMerchantId;

  @override
  Future<bool> isAvailable() async {
    // Apple Pay requires a configured merchant ID; without it the SDK cannot
    // build a valid PKPaymentRequest, so don't offer it.
    if (_appleMerchantId == null || _appleMerchantId.isEmpty) return false;
    return _bridge.isApplePayAvailable();
  }

  @override
  Future<void> startPayment({
    required KashierSession session,
    required void Function(KashierPaymentResult result) onSuccess,
    required void Function(KashierPaymentError error) onFailure,
    void Function(KashierPaymentPending pending)? onPending,
  }) async {
    var paymentCompleted = false;

    void complete(KashierPaymentResult result) {
      if (paymentCompleted) return;
      paymentCompleted = true;
      onSuccess(result);
    }

    void fail(KashierPaymentError error) {
      if (paymentCompleted) return;
      paymentCompleted = true;
      onFailure(error);
    }

    // Apple Pay requires the merchant's own Apple Merchant ID. This should be
    // gated by [isAvailable], but guard here too so a misconfiguration fails
    // with a clear error instead of presenting an unusable sheet.
    final merchantId = _appleMerchantId;
    if (merchantId == null || merchantId.isEmpty) {
      fail(KashierPaymentError.fromCode(
        KashierErrorCode.applePayConfigError,
        message:
            'Apple Pay merchant ID not configured — pass appleMerchantId to '
            'KashierSDK.initialize().',
      ));
      return;
    }

    // Pre-flight connectivity check — fail fast before the native Apple Pay
    // sheet is presented so the user isn't asked to authenticate only to
    // hit a network error during token processing.
    if (!await KashierConnectivity.instance.hasInternet()) {
      fail(KashierPaymentError.fromCode(KashierErrorCode.networkError));
      return;
    }

    // Register Cross #2 UP: Handle encrypted token from native.
    _bridge.onTokenReceived((Map<String, dynamic> token) async {

      try {

        // Send token to Kashier FEP for processing.
        final result = await _api.processApplePayToken(
          session: session,
          applePayToken: token,
        );

        // Tell native to show success on the Apple Pay sheet.
        await _bridge.completePaymentAuthorization(success: true);

        complete(result);
      } catch (e) {

        // Tell native to show failure on the Apple Pay sheet.
        await _bridge.completePaymentAuthorization(success: false);

        if (e is KashierPaymentError) {
          fail(e);
        } else {
          fail(KashierPaymentError.fromCode(
            KashierErrorCode.tokenProcessingFailed,
            details: e,
          ));
        }
      }
    });

    // Register error handler for native-side errors.
    _bridge.onPaymentError((String errorCode) {
      final code = _mapNativeErrorCode(errorCode);
      fail(KashierPaymentError.fromCode(code));
    });

    // Cross #1 DOWN: Present the Apple Pay sheet.
    try {
      await _bridge.presentApplePay(
        amount: session.amount,
        currency: session.currency,
        storeName: session.storeName,
        supportedNetworks: session.supportedNetworks,
        merchantId: merchantId,
      );
    } catch (e) {
      fail(KashierPaymentError.fromCode(
        KashierErrorCode.applePayNotAvailable,
        details: e,
      ));
    }
  }

  /// Maps native error code strings to typed error codes.
  KashierErrorCode _mapNativeErrorCode(String code) {
    return switch (code) {
      'USER_CANCELLED' => KashierErrorCode.userCancelled,
      'APPLE_PAY_NOT_AVAILABLE' => KashierErrorCode.applePayNotAvailable,
      'APPLE_PAY_CONFIG_ERROR' => KashierErrorCode.applePayConfigError,
      'TOKEN_PROCESSING_FAILED' => KashierErrorCode.tokenProcessingFailed,
      _ => KashierErrorCode.unknownError,
    };
  }
}
