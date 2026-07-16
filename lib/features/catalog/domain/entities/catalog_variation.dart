import 'package:kidia_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';

class CatalogVariation {
  const CatalogVariation({
    required this.id,
    required this.attributes,
    this.isPurchasable = true,
    this.isInStock = true,
    this.prices,
    this.image,
  });

  final int id;
  final List<CatalogVariationAttribute> attributes;
  final bool isPurchasable;
  final bool isInStock;
  final CatalogMoney? prices;
  final CatalogImage? image;
}
