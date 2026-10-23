import 'cart_totals.dart';

/// The merchant's current shipping quote, scoped to one Store API package.
class CartShippingPackage {
  CartShippingPackage({
    required this.id,
    required this.name,
    required List<CartShippingRate> rates,
  }) : rates = List.unmodifiable(rates);
  final int id;
  final String name;
  final List<CartShippingRate> rates;
  bool get hasSelection => rates.where((rate) => rate.selected).length == 1;
}

class CartShippingRate {
  const CartShippingRate({
    required this.id,
    required this.name,
    required this.priceMinor,
    required this.taxMinor,
    required this.currency,
    required this.selected,
    this.description = '',
    this.deliveryTime = '',
  });
  final String id;
  final String name;
  final String priceMinor;
  final String taxMinor;
  final CartCurrency currency;
  final bool selected;
  final String description;
  final String deliveryTime;
}
