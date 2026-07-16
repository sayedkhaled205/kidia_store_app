import 'package:kidia_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';

enum CatalogStockStatus { inStock, outOfStock, onBackorder, unknown }

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.type,
    required this.prices,
    this.parentId = 0,
    this.variationLabel = '',
    this.permalink,
    this.sku = '',
    this.summary = '',
    this.description = '',
    this.isFeatured = false,
    this.isOnSale = false,
    this.isPurchasable = false,
    this.isInStock = false,
    this.stockStatus = CatalogStockStatus.unknown,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.images = const <CatalogImage>[],
    this.categories = const <CatalogCategory>[],
    this.brands = const <CatalogCategory>[],
    this.attributes = const <CatalogProductAttribute>[],
    this.variations = const <CatalogVariation>[],
  });

  final int id;
  final String name;
  final String slug;
  final String type;
  final int parentId;
  final String variationLabel;
  final Uri? permalink;
  final String sku;
  final String summary;
  final String description;
  final bool isFeatured;
  final bool isOnSale;
  final bool isPurchasable;
  final bool isInStock;
  final CatalogStockStatus stockStatus;
  final double averageRating;
  final int reviewCount;
  final CatalogMoney prices;
  final List<CatalogImage> images;
  final List<CatalogCategory> categories;

  /// Empty on older stores that do not expose WooCommerce product brands.
  final List<CatalogCategory> brands;
  final List<CatalogProductAttribute> attributes;
  final List<CatalogVariation> variations;

  CatalogImage? get primaryImage => images.isEmpty ? null : images.first;
  bool get hasVariations => variations.isNotEmpty || type == 'variable';
}
