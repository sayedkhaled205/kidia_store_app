class CartCurrency {
  const CartCurrency({
    required this.code,
    required this.symbol,
    required this.minorUnit,
    required this.decimalSeparator,
    required this.thousandSeparator,
    required this.prefix,
    required this.suffix,
  });

  final String code;
  final String symbol;
  final int minorUnit;
  final String decimalSeparator;
  final String thousandSeparator;
  final String prefix;
  final String suffix;
}

/// Every monetary value is kept in exact minor units as a string.
/// An empty string is unavailable, not a calculated zero. Shopify does not
/// expose every WooCommerce breakdown field through CartCost.
///
/// This deliberately avoids floating-point conversion in the cart layer. The
/// UI can format the value using [currency] without losing zero-decimal or
/// three-decimal currencies.
class CartTotals {
  const CartTotals({
    required this.itemsMinor,
    required this.itemsTaxMinor,
    required this.feesMinor,
    required this.feesTaxMinor,
    required this.discountMinor,
    required this.discountTaxMinor,
    required this.shippingMinor,
    required this.shippingTaxMinor,
    required this.priceMinor,
    required this.taxMinor,
    required this.currency,
    this.subtotalEstimated = false,
    this.totalEstimated = false,
  });

  final String itemsMinor;
  final String itemsTaxMinor;
  final String feesMinor;
  final String feesTaxMinor;
  final String discountMinor;
  final String discountTaxMinor;
  final String shippingMinor;
  final String shippingTaxMinor;
  final String priceMinor;
  final String taxMinor;
  final CartCurrency currency;
  final bool subtotalEstimated;
  final bool totalEstimated;
}
