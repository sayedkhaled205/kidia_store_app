import 'package:kidia_store_app/features/cart/data/models/cart_json.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_totals_model.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';

class CartItemQuantityLimitsModel {
  const CartItemQuantityLimitsModel({
    required this.minimum,
    required this.maximum,
    required this.multipleOf,
    required this.editable,
  });

  factory CartItemQuantityLimitsModel.fromJson(Map<String, dynamic> json) {
    final int minimum = CartJson.integer(json['minimum'], fallback: 1);
    final int maximum = CartJson.integer(json['maximum'], fallback: minimum);
    final int multipleOf = CartJson.integer(json['multiple_of'], fallback: 1);
    return CartItemQuantityLimitsModel(
      minimum: minimum < 1 ? 1 : minimum,
      maximum: maximum < minimum ? minimum : maximum,
      multipleOf: multipleOf < 1 ? 1 : multipleOf,
      editable: CartJson.boolean(json['editable'], fallback: true),
    );
  }

  final int minimum;
  final int maximum;
  final int multipleOf;
  final bool editable;

  CartItemQuantityLimits toEntity() => CartItemQuantityLimits(
    minimum: minimum,
    maximum: maximum,
    multipleOf: multipleOf,
    editable: editable,
  );
}

class CartItemImageModel {
  const CartItemImageModel({
    required this.id,
    required this.sourceUrl,
    required this.thumbnailUrl,
    required this.alt,
  });

  factory CartItemImageModel.fromJson(Map<String, dynamic> json) {
    return CartItemImageModel(
      id: CartJson.integer(json['id']),
      sourceUrl: CartJson.httpUrl(json['src']),
      thumbnailUrl: CartJson.httpUrl(json['thumbnail']),
      alt: CartJson.text(json['alt']),
    );
  }

  final int id;
  final String sourceUrl;
  final String thumbnailUrl;
  final String alt;

  CartItemImage toEntity() => CartItemImage(
    id: id,
    sourceUrl: sourceUrl,
    thumbnailUrl: thumbnailUrl,
    alt: alt,
  );
}

class CartItemVariationModel {
  const CartItemVariationModel({required this.attribute, required this.value});

  factory CartItemVariationModel.fromJson(Map<String, dynamic> json) {
    return CartItemVariationModel(
      attribute: CartJson.text(json['attribute']),
      value: CartJson.text(json['value']),
    );
  }

  final String attribute;
  final String value;

  CartItemVariation toEntity() =>
      CartItemVariation(attribute: attribute, value: value);
}

class CartItemModel {
  CartItemModel({
    required this.key,
    required this.productId,
    required this.quantity,
    required this.quantityLimits,
    required this.name,
    required this.shortDescription,
    required this.sku,
    required List<CartItemImageModel> images,
    required List<CartItemVariationModel> variation,
    required this.prices,
    required this.totals,
    required this.backordersAllowed,
    required this.showBackorderBadge,
    required this.soldIndividually,
    this.lowStockRemaining,
  }) : images = List<CartItemImageModel>.unmodifiable(images),
       variation = List<CartItemVariationModel>.unmodifiable(variation);

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final String key = CartJson.text(json['key']).trim();
    final int productId = CartJson.integer(json['id']);
    if (key.isEmpty || productId <= 0) {
      throw const FormatException(
        'A cart item must have a key and a positive product id.',
      );
    }

    final List<CartItemImageModel> images = <CartItemImageModel>[];
    for (final dynamic rawImage in CartJson.list(
      json['images'],
      'item.images',
    )) {
      final CartItemImageModel image = CartItemImageModel.fromJson(
        CartJson.object(rawImage, 'item.images[]'),
      );
      if (image.sourceUrl.isNotEmpty || image.thumbnailUrl.isNotEmpty) {
        images.add(image);
      }
    }

    final List<CartItemVariationModel> variation = <CartItemVariationModel>[];
    for (final dynamic rawVariation in CartJson.list(
      json['variation'],
      'item.variation',
    )) {
      final CartItemVariationModel value = CartItemVariationModel.fromJson(
        CartJson.object(rawVariation, 'item.variation[]'),
      );
      if (value.attribute.isNotEmpty && value.value.isNotEmpty) {
        variation.add(value);
      }
    }

    return CartItemModel(
      key: key,
      productId: productId,
      quantity: CartJson.integer(json['quantity']),
      quantityLimits: CartItemQuantityLimitsModel.fromJson(
        CartJson.optionalObject(
          json['quantity_limits'],
          'item.quantity_limits',
        ),
      ),
      name: CartJson.text(json['name']),
      shortDescription: CartJson.text(json['short_description']),
      sku: CartJson.text(json['sku']),
      images: images,
      variation: variation,
      prices: CartItemPricesModel.fromJson(
        CartJson.object(json['prices'], 'item.prices'),
      ),
      totals: CartItemTotalsModel.fromJson(
        CartJson.object(json['totals'], 'item.totals'),
      ),
      lowStockRemaining: CartJson.nullableInteger(json['low_stock_remaining']),
      backordersAllowed: CartJson.boolean(json['backorders_allowed']),
      showBackorderBadge: CartJson.boolean(json['show_backorder_badge']),
      soldIndividually: CartJson.boolean(json['sold_individually']),
    );
  }

  final String key;
  final int productId;
  final int quantity;
  final CartItemQuantityLimitsModel quantityLimits;
  final String name;
  final String shortDescription;
  final String sku;
  final List<CartItemImageModel> images;
  final List<CartItemVariationModel> variation;
  final CartItemPricesModel prices;
  final CartItemTotalsModel totals;
  final int? lowStockRemaining;
  final bool backordersAllowed;
  final bool showBackorderBadge;
  final bool soldIndividually;

  CartItem toEntity() => CartItem(
    key: key,
    productId: productId,
    quantity: quantity,
    quantityLimits: quantityLimits.toEntity(),
    name: name,
    shortDescription: shortDescription,
    sku: sku,
    images: images.map((CartItemImageModel image) => image.toEntity()).toList(),
    variation: variation
        .map((CartItemVariationModel value) => value.toEntity())
        .toList(),
    prices: prices.toEntity(),
    totals: totals.toEntity(),
    lowStockRemaining: lowStockRemaining,
    backordersAllowed: backordersAllowed,
    showBackorderBadge: showBackorderBadge,
    soldIndividually: soldIndividually,
  );
}
