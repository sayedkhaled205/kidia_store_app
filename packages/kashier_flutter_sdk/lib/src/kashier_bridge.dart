import 'kashier_flutter_sdk_platform_interface.dart';

/// Typed convenience wrapper around the platform interface.
///
/// Provides a cleaner internal API using domain types instead of raw maps.
/// This class is internal and not exported to merchants.
class KashierBridge {
  KashierFlutterSdkPlatform get _platform => KashierFlutterSdkPlatform.instance;

  /// Checks whether Apple Pay is available on this device.
  Future<bool> isApplePayAvailable() {
    return _platform.isApplePayAvailable();
  }

  /// Presents the Apple Pay payment sheet. (Cross #1 DOWN)
  Future<void> presentApplePay({
    required double amount,
    required String currency,
    required String storeName,
    required List<String> supportedNetworks,
    required String merchantId,
  }) {
    return _platform.presentApplePay({
      'amount': amount,
      'currency': currency,
      'storeName': storeName,
      'supportedNetworks': supportedNetworks,
      'merchantId': merchantId,
    });
  }

  /// Registers a callback for when Apple Pay returns an encrypted token.
  /// (Cross #2 UP)
  void onTokenReceived(void Function(Map<String, dynamic> token) callback) {
    _platform.setOnTokenReceived(callback);
  }

  /// Registers a callback for native payment errors.
  void onPaymentError(void Function(String errorCode) callback) {
    _platform.setOnPaymentError(callback);
  }

  /// Tells native to finalize the Apple Pay sheet with success or failure.
  Future<void> completePaymentAuthorization({required bool success}) {
    return _platform.completePaymentAuthorization(success: success);
  }
}
