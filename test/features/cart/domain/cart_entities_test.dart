import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';

void main() {
  group('CartItemQuantityLimits', () {
    const CartItemQuantityLimits limits = CartItemQuantityLimits(
      minimum: 2,
      maximum: 8,
      multipleOf: 2,
      editable: true,
    );

    test('accepts only valid editable quantities', () {
      expect(limits.accepts(2), isTrue);
      expect(limits.accepts(6), isTrue);
      expect(limits.accepts(1), isFalse);
      expect(limits.accepts(7), isFalse);
      expect(limits.accepts(10), isFalse);
    });

    test('rejects changes when the server marks quantity non-editable', () {
      const CartItemQuantityLimits fixed = CartItemQuantityLimits(
        minimum: 1,
        maximum: 1,
        multipleOf: 1,
        editable: false,
      );
      expect(fixed.accepts(1), isFalse);
    });
  });
}
