import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_api_transport.dart';

void main() {
  const expected = String.fromEnvironment('EXPECTED_MATRIX_PLATFORM');
  if (expected.isEmpty) return;

  test('matrix compiled platform and merchant are explicit', () {
    const origin = String.fromEnvironment('EXPECTED_MATRIX_ORIGIN');
    final platform = switch (expected) {
      'woocommerce' => CommercePlatform.wooCommerce,
      'shopify' => CommercePlatform.shopify,
      'odoo' => CommercePlatform.odoo,
      _ => throw StateError('Unknown test platform'),
    };
    expect(AppConfig.commercePlatform, platform);
    expect(AppConfig.commerceConnection.storeOrigin.toString(), origin);
    expect(AppConfig.isCmsPreview, isFalse);
    expect(AppConfig.useMockHomeLayout, isFalse);
    if (platform != CommercePlatform.wooCommerce) {
      expect(
        () => StoreApiCheckoutTransport.forConfiguredStore(),
        throwsA(isA<AppConfigurationException>()),
      );
    }
  });
}
