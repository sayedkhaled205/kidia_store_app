import 'package:kidia_store_app/features/catalog/domain/entities/catalog_image.dart';

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId = 0,
    this.description = '',
    this.count = 0,
    this.image,
    this.permalink,
  });

  final int id;
  final String name;
  final String slug;
  final int parentId;
  final String description;
  final int count;
  final CatalogImage? image;
  final Uri? permalink;

  bool get isRoot => parentId == 0;
}
