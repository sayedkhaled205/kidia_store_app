import 'package:kidia_store_app/features/cart/domain/entities/cart_totals.dart';

class CartItemQuantityLimits {
  const CartItemQuantityLimits({
    required this.minimum,
    required this.maximum,
    required this.multipleOf,
    required this.editable,
  });

  final int minimum;
  final int maximum;
  final int multipleOf;
  final bool editable;

  bool accepts(int quantity) {
    return editable &&
        multipleOf > 0 &&
        quantity >= minimum &&
        quantity <= maximum &&
        quantity % multipleOf == 0;
  }
}

class CartItemImage {
  const CartItemImage({
    required this.id,
    required this.sourceUrl,
    required this.thumbnailUrl,
    required this.alt,
  });

  final int id;
  final String sourceUrl;
  final String thumbnailUrl;
  final String alt;
}

class CartItemVariation {
  const CartItemVariation({required this.attribute, required this.value});

  final String attribute;
  final String value;

  Map<String, String> toStoreApiJson() => <String, String>{
    'attribute': attribute,
    'value': value,
  };
}

class CartItemPrices {
  const CartItemPrices({
    required this.priceMinor,
    required this.regularPriceMinor,
    required this.salePriceMinor,
    required this.currency,
  });

  final String priceMinor;
  final String regularPriceMinor;
  final String salePriceMinor;
  final CartCurrency currency;
}

class CartItemTotals {
  const CartItemTotals({
    required this.subtotalMinor,
    required this.subtotalTaxMinor,
    required this.totalMinor,
    required this.totalTaxMinor,
    required this.currency,
  });

  final String subtotalMinor;
  final String subtotalTaxMinor;
  final String totalMinor;
  final String totalTaxMinor;
  final CartCurrency currency;
}

class CartItem {
  CartItem({
    required this.key,
    required this.productId,
    required this.quantity,
    required this.quantityLimits,
    required this.name,
    required this.shortDescription,
    required this.sku,
    required List<CartItemImage> images,
    required List<CartItemVariation> variation,
    required this.prices,
    required this.totals,
    required this.backordersAllowed,
    required this.showBackorderBadge,
    required this.soldIndividually,
    this.lowStockRemaining,
  }) : images = List<CartItemImage>.unmodifiable(images),
       variation = List<CartItemVariation>.unmodifiable(variation);

  final String key;
  final int productId;
  final int quantity;
  final CartItemQuantityLimits quantityLimits;
  final String name;
  final String shortDescription;
  final String sku;
  final List<CartItemImage> images;
  final List<CartItemVariation> variation;
  final CartItemPrices prices;
  final CartItemTotals totals;
  final int? lowStockRemaining;
  final bool backordersAllowed;
  final bool showBackorderBadge;
  final bool soldIndividually;
}
