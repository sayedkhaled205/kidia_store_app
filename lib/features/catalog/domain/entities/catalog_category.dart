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
    this.categoryLayout = 'default',
    this.gridColumns = 2,
    this.cardRadius = 17,
    this.cardGap = 10,
    this.showArrow = true,
    this.imageSize = 68,
    this.imageShape = 'rounded',
    this.imageRadius = 0.18,
    this.imageFit = 'contain',
    this.imageEffect = 'none',
    this.imageScale = 1,
    this.imagePosition = 'center',
    this.imageBorderWidth = 0,
    this.imageBorderColor = '#DDE5E2',
    this.imageBackgroundColor = '#FFFFFF',
    this.imageTextGap = 10,
    this.fontSize = 16,
    this.fontColor = '#1F2933',
    this.fontWeight = 800,
    this.textAlign = 'start',
    this.textMaxLines = 2,
    this.lineHeight = 1.25,
  });

  final int id;
  final String name;
  final String slug;
  final int parentId;
  final String description;
  final int count;
  final CatalogImage? image;
  final Uri? permalink;
  final String categoryLayout;
  final int gridColumns;
  final double cardRadius;
  final double cardGap;
  final bool showArrow;
  final double imageSize;
  final String imageShape;
  final double imageRadius;
  final String imageFit;
  final String imageEffect;
  final double imageScale;
  final String imagePosition;
  final double imageBorderWidth;
  final String imageBorderColor;
  final String imageBackgroundColor;
  final double imageTextGap;
  final double fontSize;
  final String fontColor;
  final int fontWeight;
  final String textAlign;
  final int textMaxLines;
  final double lineHeight;

  bool get isRoot => parentId == 0;
}
