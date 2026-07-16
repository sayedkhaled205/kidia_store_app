import 'package:kidia_store_app/features/catalog/data/models/catalog_attribute_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_category_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_image_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_json.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_money_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_variation_model.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';

class CatalogProductModel extends CatalogProduct {
  const CatalogProductModel({
    required super.id,
    required super.name,
    required super.slug,
    required super.type,
    required super.prices,
    super.parentId,
    super.variationLabel,
    super.permalink,
    super.sku,
    super.summary,
    super.description,
    super.isFeatured,
    super.isOnSale,
    super.isPurchasable,
    super.isInStock,
    super.stockStatus,
    super.averageRating,
    super.reviewCount,
    super.images,
    super.categories,
    super.brands,
    super.attributes,
    super.variations,
  });

  factory CatalogProductModel.fromJson(Map<String, dynamic> json) {
    final int id = CatalogJson.integer(json['id']);
    if (id <= 0) {
      throw const FormatException('A catalog product must have a valid id.');
    }

    final bool isInStock = CatalogJson.boolean(json['is_in_stock']);
    final bool isOnBackorder = CatalogJson.boolean(json['is_on_backorder']);
    final double rawAverageRating = CatalogJson.decimal(json['average_rating']);
    final double averageRating = rawAverageRating < 0
        ? 0
        : rawAverageRating > 5
        ? 5
        : rawAverageRating;

    return CatalogProductModel(
      id: id,
      name: CatalogJson.string(json['name'], fallback: 'Product $id'),
      slug: CatalogJson.string(json['slug'], fallback: id.toString()),
      type: CatalogJson.string(json['type'], fallback: 'simple'),
      parentId: CatalogJson.integer(json['parent']),
      variationLabel: CatalogJson.string(json['variation']),
      permalink: CatalogJson.webUri(json['permalink']),
      sku: CatalogJson.string(json['sku']),
      summary: CatalogJson.string(json['summary'] ?? json['short_description']),
      description: CatalogJson.string(json['description']),
      isFeatured: CatalogJson.boolean(json['is_featured']),
      isOnSale: CatalogJson.boolean(json['on_sale']),
      isPurchasable: CatalogJson.boolean(json['is_purchasable']),
      isInStock: isInStock,
      stockStatus: _parseStockStatus(
        json['stock_status'],
        isInStock: isInStock,
        isOnBackorder: isOnBackorder,
        hasAvailability: json.containsKey('is_in_stock'),
      ),
      averageRating: averageRating,
      reviewCount: _nonNegativeCount(json['review_count']),
      prices: CatalogMoneyModel.fromJson(json['prices']),
      images: _parseImages(json['images']),
      categories: _parseCategories(json['categories']),
      brands: _parseCategories(_brandPayload(json)),
      attributes: _parseAttributes(json['attributes']),
      variations: _parseVariations(json['variations']),
    );
  }

  static dynamic _brandPayload(Map<String, dynamic> json) {
    final List<CatalogCategory> nativeBrands = _parseCategories(json['brands']);
    if (nativeBrands.isNotEmpty) {
      return json['brands'];
    }
    final Map<String, dynamic>? extensions = CatalogJson.object(
      json['extensions'],
    );
    final Map<String, dynamic>? bridge = CatalogJson.object(
      extensions?['woo_mobile_cms'],
    );
    return bridge?['brands'];
  }

  CatalogProduct toEntity() {
    return CatalogProduct(
      id: id,
      name: name,
      slug: slug,
      type: type,
      parentId: parentId,
      variationLabel: variationLabel,
      permalink: permalink,
      sku: sku,
      summary: summary,
      description: description,
      isFeatured: isFeatured,
      isOnSale: isOnSale,
      isPurchasable: isPurchasable,
      isInStock: isInStock,
      stockStatus: stockStatus,
      averageRating: averageRating,
      reviewCount: reviewCount,
      prices: prices,
      images: images,
      categories: categories,
      brands: brands,
      attributes: attributes,
      variations: variations,
    );
  }

  static List<CatalogImage> _parseImages(dynamic value) {
    final List<CatalogImage> result = <CatalogImage>[];
    for (final dynamic rawImage in CatalogJson.list(value)) {
      final CatalogImageModel? image = CatalogImageModel.tryParse(rawImage);
      if (image != null) {
        result.add(image);
      }
    }
    return List<CatalogImage>.unmodifiable(result);
  }

  static List<CatalogCategory> _parseCategories(dynamic value) {
    final List<CatalogCategory> result = <CatalogCategory>[];
    for (final dynamic rawCategory in CatalogJson.list(value)) {
      final Map<String, dynamic>? category = CatalogJson.object(rawCategory);
      if (category == null) {
        continue;
      }
      try {
        result.add(CatalogCategoryModel.fromJson(category).toEntity());
      } on FormatException {
        continue;
      }
    }
    return List<CatalogCategory>.unmodifiable(result);
  }

  static List<CatalogProductAttribute> _parseAttributes(dynamic value) {
    final List<CatalogProductAttribute> result = <CatalogProductAttribute>[];
    for (final dynamic rawAttribute in CatalogJson.list(value)) {
      final CatalogProductAttribute? attribute =
          CatalogAttributeModel.tryParseProduct(rawAttribute);
      if (attribute != null) {
        result.add(attribute);
      }
    }
    return List<CatalogProductAttribute>.unmodifiable(result);
  }

  static List<CatalogVariation> _parseVariations(dynamic value) {
    final List<CatalogVariation> result = <CatalogVariation>[];
    for (final dynamic rawVariation in CatalogJson.list(value)) {
      final Map<String, dynamic>? variation = CatalogJson.object(rawVariation);
      if (variation == null) {
        continue;
      }
      try {
        result.add(CatalogVariationModel.fromJson(variation).toEntity());
      } on FormatException {
        continue;
      }
    }
    return List<CatalogVariation>.unmodifiable(result);
  }

  static CatalogStockStatus _parseStockStatus(
    dynamic rawStatus, {
    required bool isInStock,
    required bool isOnBackorder,
    required bool hasAvailability,
  }) {
    switch (CatalogJson.string(rawStatus).toLowerCase()) {
      case 'instock':
      case 'in_stock':
        return CatalogStockStatus.inStock;
      case 'outofstock':
      case 'out_of_stock':
        return CatalogStockStatus.outOfStock;
      case 'onbackorder':
      case 'on_backorder':
        return CatalogStockStatus.onBackorder;
      default:
        if (isOnBackorder) {
          return CatalogStockStatus.onBackorder;
        }
        if (!hasAvailability) {
          return CatalogStockStatus.unknown;
        }
        return isInStock
            ? CatalogStockStatus.inStock
            : CatalogStockStatus.outOfStock;
    }
  }

  static int _nonNegativeCount(dynamic value) {
    final int parsed = CatalogJson.integer(value);
    if (parsed < 0) {
      return 0;
    }
    return parsed > 0x7fffffff ? 0x7fffffff : parsed;
  }
}
