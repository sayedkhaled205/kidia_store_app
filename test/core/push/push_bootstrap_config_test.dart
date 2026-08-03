import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/core/push/push_bootstrap_config.dart';

void main() {
  test('accepts a complete managed Firebase bootstrap', () {
    final PushBootstrapConfig config = PushBootstrapConfig.fromJson(
      <String, dynamic>{
        'enabled': true,
        'clientReady': true,
        'registrationUrl': 'https://store.example/wp-json/woo-mobile/v1/push/devices',
        'eventsUrl': 'https://store.example/wp-json/woo-mobile/v1/push/events',
        'firebaseOptions': <String, dynamic>{
          'apiKey': 'public-api-key',
          'appId': '1:123:android:abc',
          'messagingSenderId': '123',
          'projectId': 'wm-store-123',
          'storageBucket': 'wm-store-123.firebasestorage.app',
        },
      },
    );

    expect(config.canRegister, isTrue);
    expect(config.firebase?.projectId, 'wm-store-123');
    expect(config.registrationUrl?.scheme, 'https');
  });

  test('rejects incomplete options and non-HTTPS endpoints', () {
    final PushBootstrapConfig config = PushBootstrapConfig.fromJson(
      <String, dynamic>{
        'enabled': true,
        'clientReady': true,
        'registrationUrl': 'http://store.example/push/devices',
        'firebaseOptions': <String, dynamic>{'projectId': 'wm-store-123'},
      },
    );

    expect(config.canRegister, isFalse);
    expect(config.registrationUrl, isNull);
    expect(config.firebase?.isComplete, isFalse);
  });
}
