import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'kashier_flutter_sdk_method_channel.dart';

/// The interface that platform-specific implementations of kashier_flutter_sdk
/// must extend.
abstract class KashierFlutterSdkPlatform extends PlatformInterface {
  KashierFlutterSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static KashierFlutterSdkPlatform _instance = MethodChannelKashierFlutterSdk();

  /// The default instance of [KashierFlutterSdkPlatform] to use.
  static KashierFlutterSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [KashierFlutterSdkPlatform] when
  /// they register themselves.
  static set instance(KashierFlutterSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Checks whether Apple Pay is available on this device.
  Future<bool> isApplePayAvailable() {
    throw UnimplementedError('isApplePayAvailable() has not been implemented.');
  }

  /// Presents the Apple Pay payment sheet with the given configuration.
  Future<void> presentApplePay(Map<String, dynamic> config) {
    throw UnimplementedError('presentApplePay() has not been implemented.');
  }

  /// Registers a callback for when Apple Pay returns an encrypted token.
  void setOnTokenReceived(void Function(Map<String, dynamic> token) callback) {
    throw UnimplementedError('setOnTokenReceived() has not been implemented.');
  }

  /// Registers a callback for when a payment error occurs on the native side.
  void setOnPaymentError(void Function(String errorCode) callback) {
    throw UnimplementedError('setOnPaymentError() has not been implemented.');
  }

  /// Tells native to finalize the Apple Pay sheet with success or failure.
  Future<void> completePaymentAuthorization({required bool success}) {
    throw UnimplementedError(
      'completePaymentAuthorization() has not been implemented.',
    );
  }
}
