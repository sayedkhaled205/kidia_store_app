import 'package:kidia_store_app/features/cart/domain/entities/cart_totals.dart';

class CartCouponTotals {
  const CartCouponTotals({
    required this.discountMinor,
    required this.discountTaxMinor,
    required this.currency,
  });

  final String discountMinor;
  final String discountTaxMinor;
  final CartCurrency currency;
}

class CartCoupon {
  const CartCoupon({
    required this.code,
    required this.discountType,
    required this.totals,
  });

  final String code;
  final String discountType;
  final CartCouponTotals totals;
}
