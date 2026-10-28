import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_image.dart';

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
    this.navigationMode = 'drilldown',
    this.rootViewAllMode = 'hidden',
    this.viewAllStyle = 'outline',
    this.gridColumns = 2,
    this.cardRadius = 17,
    this.cardGap = 10,
    this.cardWidthPercent = 100,
    this.cardHeight = 0,
    this.marginTop = 0,
    this.marginBottom = 0,
    this.spaceUp = 0,
    this.spaceDown = 0,
    this.pageBackgroundColor = '#F7F8FA',
    this.elementBackgroundColor = '#FFFFFF',
    this.cardStyle = 'outlined',
    this.cardBackgroundColor = '#FFFFFF',
    this.cardShadowColor = '#000000',
    this.cardShadowStrength = 0.10,
    this.cardShadowBlur = 12,
    this.cardShadowOffsetY = 4,
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
    this.nameHighlightEnabled = false,
    this.nameHighlightColor = '#EFF8F5',
    this.nameVerticalPadding = 7,
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
  final String navigationMode;
  final String rootViewAllMode;
  final String viewAllStyle;
  final int gridColumns;
  final double cardRadius;
  final double cardGap;
  final double cardWidthPercent;
  final double cardHeight;
  final double marginTop;
  final double marginBottom;
  final double spaceUp;
  final double spaceDown;
  final String pageBackgroundColor;
  final String elementBackgroundColor;
  final String cardStyle;
  final String cardBackgroundColor;
  final String cardShadowColor;
  final double cardShadowStrength;
  final double cardShadowBlur;
  final double cardShadowOffsetY;
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
  final bool nameHighlightEnabled;
  final String nameHighlightColor;
  final double nameVerticalPadding;
  final int fontWeight;
  final String textAlign;
  final int textMaxLines;
  final double lineHeight;

  CatalogCategory withPresentation(CatalogCategory presentation) {
    return CatalogCategory(
      id: id,
      name: name,
      slug: slug,
      parentId: parentId,
      description: description,
      count: count,
      image: image,
      permalink: permalink,
      categoryLayout: presentation.categoryLayout,
      navigationMode: presentation.navigationMode,
      rootViewAllMode: presentation.rootViewAllMode,
      viewAllStyle: presentation.viewAllStyle,
      gridColumns: presentation.gridColumns,
      cardRadius: presentation.cardRadius,
      cardGap: presentation.cardGap,
      cardWidthPercent: presentation.cardWidthPercent,
      cardHeight: presentation.cardHeight,
      marginTop: presentation.marginTop,
      marginBottom: presentation.marginBottom,
      spaceUp: presentation.spaceUp,
      spaceDown: presentation.spaceDown,
      pageBackgroundColor: presentation.pageBackgroundColor,
      elementBackgroundColor: presentation.elementBackgroundColor,
      cardStyle: presentation.cardStyle,
      cardBackgroundColor: presentation.cardBackgroundColor,
      cardShadowColor: presentation.cardShadowColor,
      cardShadowStrength: presentation.cardShadowStrength,
      cardShadowBlur: presentation.cardShadowBlur,
      cardShadowOffsetY: presentation.cardShadowOffsetY,
      showArrow: presentation.showArrow,
      imageSize: presentation.imageSize,
      imageShape: presentation.imageShape,
      imageRadius: presentation.imageRadius,
      imageFit: presentation.imageFit,
      imageEffect: presentation.imageEffect,
      imageScale: presentation.imageScale,
      imagePosition: presentation.imagePosition,
      imageBorderWidth: presentation.imageBorderWidth,
      imageBorderColor: presentation.imageBorderColor,
      imageBackgroundColor: presentation.imageBackgroundColor,
      imageTextGap: presentation.imageTextGap,
      fontSize: presentation.fontSize,
      fontColor: presentation.fontColor,
      nameHighlightEnabled: presentation.nameHighlightEnabled,
      nameHighlightColor: presentation.nameHighlightColor,
      nameVerticalPadding: presentation.nameVerticalPadding,
      fontWeight: presentation.fontWeight,
      textAlign: presentation.textAlign,
      textMaxLines: presentation.textMaxLines,
      lineHeight: presentation.lineHeight,
    );
  }

  bool get isRoot => parentId == 0;
}
