import 'package:kidia_store_app/features/catalog/data/models/catalog_image_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_json.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';

class CatalogCategoryModel extends CatalogCategory {
  const CatalogCategoryModel({
    required super.id,
    required super.name,
    required super.slug,
    super.parentId,
    super.description,
    super.count,
    super.image,
    super.permalink,
  });

  factory CatalogCategoryModel.fromJson(Map<String, dynamic> json) {
    final int id = CatalogJson.integer(json['id']);
    if (id <= 0) {
      throw const FormatException('A catalog category must have a valid id.');
    }

    return CatalogCategoryModel(
      id: id,
      name: CatalogJson.string(json['name'], fallback: 'Category $id'),
      slug: CatalogJson.string(json['slug'], fallback: id.toString()),
      parentId: CatalogJson.integer(json['parent']),
      description: CatalogJson.string(json['description']),
      count: _nonNegativeCount(json['count']),
      image: CatalogImageModel.tryParse(json['image']),
      permalink: CatalogJson.webUri(json['permalink'] ?? json['link']),
    );
  }

  CatalogCategory toEntity() {
    return CatalogCategory(
      id: id,
      name: name,
      slug: slug,
      parentId: parentId,
      description: description,
      count: count,
      image: image,
      permalink: permalink,
    );
  }

  static int _nonNegativeCount(dynamic value) {
    final int parsed = CatalogJson.integer(value);
    if (parsed < 0) {
      return 0;
    }
    return parsed > 0x7fffffff ? 0x7fffffff : parsed;
  }
}
