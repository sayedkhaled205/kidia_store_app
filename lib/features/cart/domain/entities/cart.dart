import 'package:kidia_store_app/features/cart/domain/entities/cart_address.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_coupon.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_totals.dart';

class Cart {
  Cart({
    required List<CartItem> items,
    required List<CartCoupon> coupons,
    required this.totals,
    required this.shippingAddress,
    required this.billingAddress,
    required this.itemsCount,
    required this.itemsWeight,
    required this.needsPayment,
    required this.needsShipping,
    required this.hasCalculatedShipping,
    required List<String> paymentMethods,
    required List<CartError> errors,
  }) : items = List<CartItem>.unmodifiable(items),
       coupons = List<CartCoupon>.unmodifiable(coupons),
       paymentMethods = List<String>.unmodifiable(paymentMethods),
       errors = List<CartError>.unmodifiable(errors);

  final List<CartItem> items;
  final List<CartCoupon> coupons;
  final CartTotals totals;
  final CartAddress shippingAddress;
  final CartAddress billingAddress;
  final int itemsCount;
  final double itemsWeight;
  final bool needsPayment;
  final bool needsShipping;
  final bool hasCalculatedShipping;
  final List<String> paymentMethods;
  final List<CartError> errors;

  bool get isEmpty => items.isEmpty;
}
