import 'package:mobishop_store_app/features/cart/data/models/cart_address_model.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_coupon_model.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_error_model.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_item_model.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_json.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_totals_model.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';

import '../../domain/entities/cart_shipping.dart';

class CartModel {
  CartModel({
    List<CartShippingPackage> shippingPackages = const [],
    required List<CartItemModel> items,
    required List<CartCouponModel> coupons,
    required this.totals,
    required this.shippingAddress,
    required this.billingAddress,
    required this.itemsCount,
    required this.itemsWeight,
    required this.needsPayment,
    required this.needsShipping,
    required this.hasCalculatedShipping,
    required List<String> paymentMethods,
    required List<CartErrorModel> errors,
  }) : shippingPackages = List.unmodifiable(shippingPackages),
       items = List<CartItemModel>.unmodifiable(items),
       coupons = List<CartCouponModel>.unmodifiable(coupons),
       paymentMethods = List<String>.unmodifiable(paymentMethods),
       errors = List<CartErrorModel>.unmodifiable(errors);

  factory CartModel.fromJson(Map<String, dynamic> json) {
    final List<CartItemModel> items = _parseList<CartItemModel>(
      json['items'],
      'items',
      CartItemModel.fromJson,
    );
    final List<CartCouponModel> coupons = _parseList<CartCouponModel>(
      json['coupons'],
      'coupons',
      CartCouponModel.fromJson,
    );
    final List<CartErrorModel> errors = _parseList<CartErrorModel>(
      json['errors'],
      'errors',
      CartErrorModel.fromJson,
    );
    final List<String> paymentMethods =
        CartJson.list(json['payment_methods'], 'payment_methods')
            .map(CartJson.text)
            .map((String method) => method.trim())
            .where((String method) => method.isNotEmpty)
            .toList(growable: false);

    return CartModel(
      shippingPackages: _parseList<CartShippingPackage>(
        json['shipping_rates'],
        'shipping_rates',
        (package) {
          final id = CartJson.nullableInteger(package['package_id']);
          if (id == null || id < 0) {
            throw const FormatException('Invalid shipping package.');
          }
          return CartShippingPackage(
            id: id,
            name: CartJson.text(package['name']),
            rates: _parseList<CartShippingRate>(
              package['shipping_rates'],
              'shipping_rates[]',
              (rate) {
                final id = CartJson.text(rate['rate_id']).trim();
                if (id.isEmpty) {
                  throw const FormatException('Invalid shipping rate.');
                }
                return CartShippingRate(
                  id: id,
                  name: CartJson.text(rate['name']),
                  priceMinor: CartJson.minorUnits(
                    rate['price'],
                    'shipping.price',
                  ),
                  taxMinor: CartJson.minorUnits(
                    rate['taxes'],
                    'shipping.taxes',
                  ),
                  currency: CartCurrencyModel.fromJson(rate).toEntity(),
                  selected: CartJson.boolean(rate['selected']),
                  description: CartJson.text(rate['description']),
                  deliveryTime: CartJson.text(rate['delivery_time']),
                );
              },
            ),
          );
        },
      ),
      items: items,
      coupons: coupons,
      totals: CartTotalsModel.fromJson(
        CartJson.object(json['totals'], 'totals'),
      ),
      shippingAddress: CartAddressModel.fromJson(
        CartJson.optionalObject(json['shipping_address'], 'shipping_address'),
      ),
      billingAddress: CartAddressModel.fromJson(
        CartJson.optionalObject(json['billing_address'], 'billing_address'),
      ),
      itemsCount: CartJson.integer(json['items_count']),
      itemsWeight: CartJson.decimal(json['items_weight']),
      needsPayment: CartJson.boolean(json['needs_payment']),
      needsShipping: CartJson.boolean(json['needs_shipping']),
      hasCalculatedShipping: CartJson.boolean(json['has_calculated_shipping']),
      paymentMethods: paymentMethods,
      errors: errors,
    );
  }

  final List<CartShippingPackage> shippingPackages;
  final List<CartItemModel> items;
  final List<CartCouponModel> coupons;
  final CartTotalsModel totals;
  final CartAddressModel shippingAddress;
  final CartAddressModel billingAddress;
  final int itemsCount;
  final double itemsWeight;
  final bool needsPayment;
  final bool needsShipping;
  final bool hasCalculatedShipping;
  final List<String> paymentMethods;
  final List<CartErrorModel> errors;

  Cart toEntity() => Cart(
    shippingPackages: shippingPackages,
    items: items.map((CartItemModel item) => item.toEntity()).toList(),
    coupons: coupons
        .map((CartCouponModel coupon) => coupon.toEntity())
        .toList(),
    totals: totals.toEntity(),
    shippingAddress: shippingAddress.toEntity(),
    billingAddress: billingAddress.toEntity(),
    itemsCount: itemsCount,
    itemsWeight: itemsWeight,
    needsPayment: needsPayment,
    needsShipping: needsShipping,
    hasCalculatedShipping: hasCalculatedShipping,
    paymentMethods: paymentMethods,
    errors: errors.map((CartErrorModel error) => error.toEntity()).toList(),
  );

  static List<T> _parseList<T>(
    dynamic raw,
    String field,
    T Function(Map<String, dynamic> json) parser,
  ) {
    return CartJson.list(raw, field)
        .map((dynamic item) => parser(CartJson.object(item, '$field[]')))
        .toList(growable: false);
  }
}
