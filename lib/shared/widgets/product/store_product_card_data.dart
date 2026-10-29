import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';

/// Display data only. Commerce IDs, selection and wishlist persistence stay
/// with their existing controllers.
class StoreProductCardData {
  const StoreProductCardData({
    required this.id,
    required this.name,
    required this.images,
    required this.currentPrice,
    required this.regularPrice,
    required this.isDiscounted,
    required this.isInStock,
    required this.isOnSale,
    required this.averageRating,
    required this.reviewCount,
    this.imageAlt = '',
  });
  final int id;
  final String name, currentPrice, regularPrice, imageAlt;
  final List<String> images;
  final bool isDiscounted, isInStock, isOnSale;
  final double averageRating;
  final int reviewCount;

  static String priceText(String amount, String currency) {
    var value = amount.trim();
    if (value.isEmpty) return '';
    if (RegExp(r'^-?\d+\.\d+$').hasMatch(value)) {
      value = value
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return '$value ${currency.trim()}'.trim();
  }

  factory StoreProductCardData.catalog(
    CatalogProduct product, {
    bool shared = false,
  }) {
    final money = product.prices;
    String display(String minor) => shared
        ? priceText(
            money.decimalAmount(minor),
            money.currencySymbol.isEmpty
                ? money.currencyCode
                : money.currencySymbol,
          )
        : money.displayAmount(minor);
    return StoreProductCardData(
      id: product.id,
      name: product.name,
      images: product.images
          .map((image) => image.cardSource.toString())
          .toSet()
          .toList(),
      imageAlt: product.primaryImage?.alt ?? '',
      currentPrice: display(money.priceMinor),
      regularPrice: display(money.regularPriceMinor),
      isDiscounted: money.isDiscounted,
      isInStock: product.isInStock,
      isOnSale: product.isOnSale,
      averageRating: product.averageRating,
      reviewCount: product.reviewCount,
    );
  }

  factory StoreProductCardData.home(HomeProductItem product) =>
      StoreProductCardData(
        id: product.id,
        name: product.name,
        images: [
          product.imageUrl,
          ...product.imageUrls,
        ].where((url) => url.isNotEmpty).toSet().toList(),
        currentPrice: priceText(product.price, product.currencySymbol),
        regularPrice: priceText(
          product.regularPrice ?? '',
          product.currencySymbol,
        ),
        isDiscounted:
            product.regularPrice != null &&
            (num.tryParse(product.regularPrice!) ?? 0) >
                (num.tryParse(product.price) ?? 0),
        isInStock: product.inStock,
        isOnSale: product.discountPercent > 0,
        averageRating: product.rating,
        reviewCount: product.reviewCount,
      );
}
