import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_model.dart';

import 'cart_test_fixture.dart';

void main() {
  group('CartModel', () {
    test('parses Store API cart values without floating-point conversion', () {
      final CartModel model = CartModel.fromJson(
        cartJsonFixture(totalPrice: '123456789012345678901'),
      );
      final cart = model.toEntity();

      expect(cart.totals.priceMinor, '123456789012345678901');
      expect(cart.totals.currency.code, 'KWD');
      expect(cart.totals.currency.minorUnit, 3);
      expect(cart.items.single.prices.priceMinor, '1800');
      expect(cart.items.single.variation.single.attribute, 'pa_color');
      expect(cart.coupons.single.totals.discountMinor, '100');
      expect(cart.billingAddress.email, 'shopper@example.com');
      expect(cart.paymentMethods, <String>['cod']);
    });

    test('rejects decimal monetary values instead of rounding them', () {
      final Map<String, dynamic> json = cartJsonFixture();
      (json['totals'] as Map<String, dynamic>)['total_price'] = '82.56';

      expect(() => CartModel.fromJson(json), throwsFormatException);
    });

    test('does not expose non-http image URLs', () {
      final Map<String, dynamic> json = cartJsonFixture();
      final Map<String, dynamic> item =
          (json['items'] as List<dynamic>).single as Map<String, dynamic>;
      item['images'] = <dynamic>[
        <String, dynamic>{'id': 1, 'src': 'javascript:alert(1)'},
      ];

      expect(CartModel.fromJson(json).items.single.images, isEmpty);
    });
  });
}
