import 'package:kidia_store_app/features/cart/data/models/cart_json.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_coupon.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_totals.dart';

class CartCurrencyModel {
  const CartCurrencyModel({
    required this.code,
    required this.symbol,
    required this.minorUnit,
    required this.decimalSeparator,
    required this.thousandSeparator,
    required this.prefix,
    required this.suffix,
  });

  factory CartCurrencyModel.fromJson(Map<String, dynamic> json) {
    return CartCurrencyModel(
      code: CartJson.text(json['currency_code']),
      symbol: CartJson.text(json['currency_symbol']),
      minorUnit: CartJson.integer(json['currency_minor_unit'], fallback: 2),
      decimalSeparator: CartJson.text(
        json['currency_decimal_separator'],
        fallback: '.',
      ),
      thousandSeparator: CartJson.text(
        json['currency_thousand_separator'],
        fallback: ',',
      ),
      prefix: CartJson.text(json['currency_prefix']),
      suffix: CartJson.text(json['currency_suffix']),
    );
  }

  final String code;
  final String symbol;
  final int minorUnit;
  final String decimalSeparator;
  final String thousandSeparator;
  final String prefix;
  final String suffix;

  CartCurrency toEntity() => CartCurrency(
    code: code,
    symbol: symbol,
    minorUnit: minorUnit,
    decimalSeparator: decimalSeparator,
    thousandSeparator: thousandSeparator,
    prefix: prefix,
    suffix: suffix,
  );
}

class CartTotalsModel {
  const CartTotalsModel({
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
  });

  factory CartTotalsModel.fromJson(Map<String, dynamic> json) {
    return CartTotalsModel(
      itemsMinor: CartJson.minorUnits(
        json['total_items'],
        'totals.total_items',
      ),
      itemsTaxMinor: CartJson.minorUnits(
        json['total_items_tax'],
        'totals.total_items_tax',
      ),
      feesMinor: CartJson.minorUnits(json['total_fees'], 'totals.total_fees'),
      feesTaxMinor: CartJson.minorUnits(
        json['total_fees_tax'],
        'totals.total_fees_tax',
      ),
      discountMinor: CartJson.minorUnits(
        json['total_discount'],
        'totals.total_discount',
      ),
      discountTaxMinor: CartJson.minorUnits(
        json['total_discount_tax'],
        'totals.total_discount_tax',
      ),
      shippingMinor: CartJson.minorUnits(
        json['total_shipping'],
        'totals.total_shipping',
      ),
      shippingTaxMinor: CartJson.minorUnits(
        json['total_shipping_tax'],
        'totals.total_shipping_tax',
      ),
      priceMinor: CartJson.minorUnits(
        json['total_price'],
        'totals.total_price',
      ),
      taxMinor: CartJson.minorUnits(json['total_tax'], 'totals.total_tax'),
      currency: CartCurrencyModel.fromJson(json),
    );
  }

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
  final CartCurrencyModel currency;

  CartTotals toEntity() => CartTotals(
    itemsMinor: itemsMinor,
    itemsTaxMinor: itemsTaxMinor,
    feesMinor: feesMinor,
    feesTaxMinor: feesTaxMinor,
    discountMinor: discountMinor,
    discountTaxMinor: discountTaxMinor,
    shippingMinor: shippingMinor,
    shippingTaxMinor: shippingTaxMinor,
    priceMinor: priceMinor,
    taxMinor: taxMinor,
    currency: currency.toEntity(),
  );
}

class CartItemPricesModel {
  const CartItemPricesModel({
    required this.priceMinor,
    required this.regularPriceMinor,
    required this.salePriceMinor,
    required this.currency,
  });

  factory CartItemPricesModel.fromJson(Map<String, dynamic> json) {
    return CartItemPricesModel(
      priceMinor: CartJson.minorUnits(json['price'], 'item.prices.price'),
      regularPriceMinor: CartJson.minorUnits(
        json['regular_price'],
        'item.prices.regular_price',
      ),
      salePriceMinor: CartJson.minorUnits(
        json['sale_price'],
        'item.prices.sale_price',
      ),
      currency: CartCurrencyModel.fromJson(json),
    );
  }

  final String priceMinor;
  final String regularPriceMinor;
  final String salePriceMinor;
  final CartCurrencyModel currency;

  CartItemPrices toEntity() => CartItemPrices(
    priceMinor: priceMinor,
    regularPriceMinor: regularPriceMinor,
    salePriceMinor: salePriceMinor,
    currency: currency.toEntity(),
  );
}

class CartItemTotalsModel {
  const CartItemTotalsModel({
    required this.subtotalMinor,
    required this.subtotalTaxMinor,
    required this.totalMinor,
    required this.totalTaxMinor,
    required this.currency,
  });

  factory CartItemTotalsModel.fromJson(Map<String, dynamic> json) {
    return CartItemTotalsModel(
      subtotalMinor: CartJson.minorUnits(
        json['line_subtotal'],
        'item.totals.line_subtotal',
      ),
      subtotalTaxMinor: CartJson.minorUnits(
        json['line_subtotal_tax'],
        'item.totals.line_subtotal_tax',
      ),
      totalMinor: CartJson.minorUnits(
        json['line_total'],
        'item.totals.line_total',
      ),
      totalTaxMinor: CartJson.minorUnits(
        json['line_total_tax'],
        'item.totals.line_total_tax',
      ),
      currency: CartCurrencyModel.fromJson(json),
    );
  }

  final String subtotalMinor;
  final String subtotalTaxMinor;
  final String totalMinor;
  final String totalTaxMinor;
  final CartCurrencyModel currency;

  CartItemTotals toEntity() => CartItemTotals(
    subtotalMinor: subtotalMinor,
    subtotalTaxMinor: subtotalTaxMinor,
    totalMinor: totalMinor,
    totalTaxMinor: totalTaxMinor,
    currency: currency.toEntity(),
  );
}

class CartCouponTotalsModel {
  const CartCouponTotalsModel({
    required this.discountMinor,
    required this.discountTaxMinor,
    required this.currency,
  });

  factory CartCouponTotalsModel.fromJson(Map<String, dynamic> json) {
    return CartCouponTotalsModel(
      discountMinor: CartJson.minorUnits(
        json['total_discount'],
        'coupon.totals.total_discount',
      ),
      discountTaxMinor: CartJson.minorUnits(
        json['total_discount_tax'],
        'coupon.totals.total_discount_tax',
      ),
      currency: CartCurrencyModel.fromJson(json),
    );
  }

  final String discountMinor;
  final String discountTaxMinor;
  final CartCurrencyModel currency;

  CartCouponTotals toEntity() => CartCouponTotals(
    discountMinor: discountMinor,
    discountTaxMinor: discountTaxMinor,
    currency: currency.toEntity(),
  );
}
