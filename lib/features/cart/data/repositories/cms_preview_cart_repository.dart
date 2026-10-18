import 'dart:convert';
import '../../domain/entities/cart.dart';
import '../../domain/entities/cart_error.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/cart_repository.dart';
import '../models/cart_model.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';

/// Isolated builder basket. Reads the preview catalog, never a customer cart.
/// Not registered in the native application entry point.
class CmsPreviewCartRepository implements CartRepository {
  CmsPreviewCartRepository(this.catalog);
  final CatalogRepository catalog;
  final Map<String, Map<String, dynamic>> _items = {};

  @override
  Future<Cart> getCart() async => _snapshot();

  @override
  Future<Cart> addItem({
    required int productId,
    int quantity = 1,
    List<CartItemVariation> variation = const [],
  }) async {
    _quantity(quantity);
    final product = await catalog.getProduct(productId);
    final price = product.prices;
    final options = variation.map((v) => v.toStoreApiJson()).toList()
      ..sort((a, b) => a['attribute']!.compareTo(b['attribute']!));
    final key = 'preview:$productId:${jsonEncode(options)}';
    final count = (_items[key]?['quantity'] as int? ?? 0) + quantity;
    _quantity(count);
    _items[key] = {
      'key': key,
      'id': productId,
      'quantity': count,
      'name': product.name,
      'sku': product.sku,
      'short_description': product.summary,
      'quantity_limits': {
        'minimum': 1,
        'maximum': 999,
        'multiple_of': 1,
        'editable': true,
      },
      'images': product.images
          .map(
            (image) => {
              'src': image.source.toString(),
              'thumbnail': (image.thumbnail ?? image.source).toString(),
              'alt': image.alt,
            },
          )
          .toList(),
      'variation': options,
      'prices': {
        'price': price.priceMinor,
        'regular_price': price.regularPriceMinor,
        'sale_price': price.salePriceMinor,
        'currency_code': price.currencyCode,
        'currency_symbol': price.currencySymbol,
        'currency_minor_unit': price.currencyMinorUnit,
        'currency_prefix': price.currencyPrefix,
        'currency_suffix': price.currencySuffix,
      },
    };
    return _snapshot();
  }

  @override
  Future<Cart> updateItem({required String key, required int quantity}) async {
    _quantity(quantity);
    if (!_items.containsKey(key))
      throw const CartRepositoryException(
        kind: CartFailureKind.notFound,
        message: 'Preview item no longer exists.',
      );
    _items[key]!['quantity'] = quantity;
    return _snapshot();
  }

  @override
  Future<Cart> removeItem(String key) async {
    _items.remove(key);
    return _snapshot();
  }

  @override
  Future<Cart> applyCoupon(
    String code,
  ) async => throw const CartRepositoryException(
    kind: CartFailureKind.configuration,
    message:
        'Coupon validation is available in the connected application, not the builder preview.',
  );

  @override
  Future<Cart> removeCoupon(String code) async => _snapshot();

  void _quantity(int count) {
    if (count < 1 || count > 999)
      throw const CartRepositoryException(
        kind: CartFailureKind.invalidInput,
        message: 'Choose a quantity between 1 and 999.',
      );
  }

  Cart _snapshot() {
    var sum = BigInt.zero;
    var count = 0;
    final rows = <Map<String, dynamic>>[];
    for (final item in _items.values) {
      final price = item['prices'] as Map<String, dynamic>;
      final quantity = item['quantity'] as int;
      final total =
          (BigInt.tryParse('${price['price']}') ?? BigInt.zero) *
          BigInt.from(quantity);
      sum += total;
      count += quantity;
      rows.add({
        ...item,
        'totals': {...price, 'line_subtotal': '$total', 'line_total': '$total'},
      });
    }
    return CartModel.fromJson({
      'items': rows,
      'items_count': count,
      'totals': {
        ...?_items.values.firstOrNull?['prices'] as Map<String, dynamic>?,
        'total_items': '$sum',
        'total_price': '$sum',
      },
      'needs_payment': false,
      'needs_shipping': false,
    }).toEntity();
  }
}
