import 'package:kidia_store_app/features/cart/data/models/cart_json.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_totals_model.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_coupon.dart';

class CartCouponModel {
  const CartCouponModel({
    required this.code,
    required this.discountType,
    required this.totals,
  });

  factory CartCouponModel.fromJson(Map<String, dynamic> json) {
    final String code = CartJson.text(json['code']).trim();
    if (code.isEmpty) {
      throw const FormatException('A cart coupon must have a code.');
    }
    return CartCouponModel(
      code: code,
      discountType: CartJson.text(json['discount_type']),
      totals: CartCouponTotalsModel.fromJson(
        CartJson.object(json['totals'], 'coupon.totals'),
      ),
    );
  }

  final String code;
  final String discountType;
  final CartCouponTotalsModel totals;

  CartCoupon toEntity() => CartCoupon(
    code: code,
    discountType: discountType,
    totals: totals.toEntity(),
  );
}
