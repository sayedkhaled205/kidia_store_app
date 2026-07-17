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
    this.imageSize = 68,
    this.imageShape = 'rounded',
    this.imageFit = 'contain',
    this.imageEffect = 'none',
    this.imageScale = 1,
    this.imagePosition = 'center',
    this.imageBorderWidth = 0,
    this.imageBorderColor = '#DDE5E2',
    this.imageBackgroundColor = '#FFFFFF',
  });

  final int id;
  final String name;
  final String slug;
  final int parentId;
  final String description;
  final int count;
  final CatalogImage? image;
  final Uri? permalink;
  final double imageSize;
  final String imageShape;
  final String imageFit;
  final String imageEffect;
  final double imageScale;
  final String imagePosition;
  final double imageBorderWidth;
  final String imageBorderColor;
  final String imageBackgroundColor;

  bool get isRoot => parentId == 0;
}
