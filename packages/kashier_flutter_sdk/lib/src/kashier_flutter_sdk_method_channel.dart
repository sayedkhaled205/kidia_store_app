import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'kashier_flutter_sdk_platform_interface.dart';

/// A [KashierFlutterSdkPlatform] implementation that uses method channels.
class MethodChannelKashierFlutterSdk extends KashierFlutterSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('kashier_flutter_sdk');

  void Function(Map<String, dynamic> token)? _onTokenReceived;
  void Function(String errorCode)? _onPaymentError;

  bool _handlerRegistered = false;

  void _ensureHandlerRegistered() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;

    // Listen for upward calls from native (Swift → Dart).
    methodChannel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onTokenReceived':
        final token = _deepCastMap(call.arguments);
        _onTokenReceived?.call(token);
      case 'onPaymentError':
        final args = _castMap(call.arguments);
        final errorCode = args['errorCode'] as String;
        _onPaymentError?.call(errorCode);
      default:
        throw MissingPluginException(
          'No handler for method ${call.method}',
        );
    }
  }

  @override
  Future<bool> isApplePayAvailable() async {
    final result =
        await methodChannel.invokeMethod<bool>('isApplePayAvailable');
    return result ?? false;
  }

  @override
  Future<void> presentApplePay(Map<String, dynamic> config) async {
    await methodChannel.invokeMethod<void>('presentApplePay', config);
  }

  @override
  void setOnTokenReceived(void Function(Map<String, dynamic> token) callback) {
    _ensureHandlerRegistered();
    _onTokenReceived = callback;
  }

  @override
  void setOnPaymentError(void Function(String errorCode) callback) {
    _ensureHandlerRegistered();
    _onPaymentError = callback;
  }

  @override
  Future<void> completePaymentAuthorization({required bool success}) async {
    await methodChannel.invokeMethod<void>(
      'completePaymentAuthorization',
      {'success': success},
    );
  }

  /// Safely casts platform arguments to a typed map.
  static Map<String, dynamic> _castMap(dynamic arguments) {
    if (arguments is Map<String, dynamic>) return arguments;
    if (arguments is Map) return Map<String, dynamic>.from(arguments);
    return <String, dynamic>{};
  }

  /// Recursively casts nested platform maps to typed maps.
  ///
  /// MethodChannel returns platform-native map types for nested objects.
  /// The Apple Pay token has deeply nested maps (paymentData.header, etc.)
  /// that must all be converted to typed Dart maps.
  static Map<String, dynamic> _deepCastMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(
            key.toString(),
            _deepCastValue(val),
          ));
    }
    return <String, dynamic>{};
  }

  static dynamic _deepCastValue(dynamic value) {
    if (value is Map) {
      return _deepCastMap(value);
    }
    if (value is List) {
      return value.map(_deepCastValue).toList();
    }
    return value;
  }
}
