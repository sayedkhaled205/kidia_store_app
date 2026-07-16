import 'package:kidia_store_app/features/catalog/data/models/catalog_attribute_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_image_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_json.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_money_model.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';

class CatalogVariationModel extends CatalogVariation {
  const CatalogVariationModel({
    required super.id,
    required super.attributes,
    super.isPurchasable,
    super.isInStock,
    super.prices,
    super.image,
  });

  factory CatalogVariationModel.fromJson(Map<String, dynamic> json) {
    final int id = CatalogJson.integer(json['id']);
    if (id <= 0) {
      throw const FormatException('A product variation must have a valid id.');
    }

    final List<CatalogVariationAttribute> attributes =
        <CatalogVariationAttribute>[];
    for (final dynamic rawAttribute in CatalogJson.list(json['attributes'])) {
      final CatalogVariationAttribute? attribute =
          CatalogAttributeModel.tryParseVariation(rawAttribute);
      if (attribute != null) {
        attributes.add(attribute);
      }
    }

    return CatalogVariationModel(
      id: id,
      attributes: List<CatalogVariationAttribute>.unmodifiable(attributes),
      isPurchasable: CatalogJson.boolean(
        json['is_purchasable'],
        fallback: true,
      ),
      isInStock: CatalogJson.boolean(json['is_in_stock'], fallback: true),
      prices: CatalogJson.object(json['prices']) == null
          ? null
          : CatalogMoneyModel.fromJson(json['prices']),
      image: CatalogImageModel.tryParse(json['image']),
    );
  }

  CatalogVariation toEntity() {
    return CatalogVariation(
      id: id,
      attributes: attributes,
      isPurchasable: isPurchasable,
      isInStock: isInStock,
      prices: prices,
      image: image,
    );
  }
}
