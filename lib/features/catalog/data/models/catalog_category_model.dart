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
    super.categoryLayout,
    super.navigationMode,
    super.gridColumns,
    super.cardRadius,
    super.cardGap,
    super.cardWidthPercent,
    super.cardHeight,
    super.marginTop,
    super.marginBottom,
    super.spaceUp,
    super.spaceDown,
    super.pageBackgroundColor,
    super.elementBackgroundColor,
    super.cardStyle,
    super.cardBackgroundColor,
    super.cardShadowColor,
    super.cardShadowStrength,
    super.cardShadowBlur,
    super.cardShadowOffsetY,
    super.showArrow,
    super.imageSize,
    super.imageShape,
    super.imageRadius,
    super.imageFit,
    super.imageEffect,
    super.imageScale,
    super.imagePosition,
    super.imageBorderWidth,
    super.imageBorderColor,
    super.imageBackgroundColor,
    super.imageTextGap,
    super.fontSize,
    super.fontColor,
    super.fontWeight,
    super.textAlign,
    super.textMaxLines,
    super.lineHeight,
  });

  factory CatalogCategoryModel.fromJson(Map<String, dynamic> json) {
    final int id = CatalogJson.integer(json['id']);
    if (id <= 0) {
      throw const FormatException('A catalog category must have a valid id.');
    }

    final Map<String, dynamic> presentation =
        CatalogJson.object(json['presentation']) ?? <String, dynamic>{};
    return CatalogCategoryModel(
      id: id,
      name: CatalogJson.string(json['name'], fallback: 'Category $id'),
      slug: CatalogJson.string(json['slug'], fallback: id.toString()),
      parentId: CatalogJson.integer(json['parent']),
      description: CatalogJson.string(json['description']),
      count: _nonNegativeCount(json['count']),
      image: CatalogImageModel.tryParse(json['image']),
      permalink: CatalogJson.webUri(json['permalink'] ?? json['link']),
      categoryLayout: _choice(
        presentation['category_layout'],
        const <String>{
          'default',
          'visual_grid',
          'circular_grid',
          'compact_grid',
          'sidebar',
        },
        'default',
      ),
      navigationMode: _choice(
        presentation['navigation_mode'],
        const <String>{'expand_inline', 'separate_page'},
        'expand_inline',
      ),
      gridColumns: _boundedDouble(
        presentation['grid_columns'],
        2,
        4,
        2,
      ).round(),
      cardRadius: _boundedDouble(presentation['card_radius'], 0, 32, 17),
      cardGap: _boundedDouble(presentation['card_gap'], 0, 24, 10),
      cardWidthPercent: _boundedDouble(
        presentation['card_width_percent'],
        40,
        100,
        100,
      ),
      cardHeight: _boundedDouble(presentation['card_height'], 0, 320, 0),
      marginTop: _boundedDouble(presentation['margin_top'], 0, 80, 0),
      marginBottom: _boundedDouble(presentation['margin_bottom'], 0, 80, 0),
      spaceUp: _boundedDouble(presentation['space_up'], 0, 80, 0),
      spaceDown: _boundedDouble(presentation['space_down'], 0, 80, 0),
      pageBackgroundColor: _hexColor(
        presentation['page_background_color'],
        '#F7F8FA',
      ),
      elementBackgroundColor: _hexColor(
        presentation['element_background_color'],
        '#FFFFFF',
      ),
      cardStyle: _choice(
        presentation['card_style'],
        const <String>{'minimal', 'no_shadow', 'outlined', 'elevated'},
        'outlined',
      ),
      cardBackgroundColor: _hexColor(
        presentation['card_background_color'],
        '#FFFFFF',
      ),
      cardShadowColor: _hexColor(
        presentation['card_shadow_color'],
        '#000000',
      ),
      cardShadowStrength: _boundedDouble(
        presentation['card_shadow_strength'],
        0,
        40,
        10,
      ) / 100,
      cardShadowBlur: _boundedDouble(
        presentation['card_shadow_blur'],
        0,
        40,
        12,
      ),
      cardShadowOffsetY: _boundedDouble(
        presentation['card_shadow_offset_y'],
        -20,
        20,
        4,
      ),
      showArrow: presentation['show_arrow'] is bool
          ? presentation['show_arrow'] as bool
          : true,
      imageSize: _boundedDouble(presentation['image_size'], 32, 120, 68),
      imageShape: _choice(
        presentation['image_shape'],
        const <String>{'square', 'rounded', 'circle'},
        'rounded',
      ),
      imageRadius:
          _boundedDouble(presentation['image_radius'], 0, 50, 18) / 100,
      imageFit: _choice(
        presentation['image_fit'],
        const <String>{'contain', 'cover'},
        'contain',
      ),
      imageEffect: _choice(
        presentation['image_effect'],
        const <String>{'none', 'shadow', 'grayscale'},
        'none',
      ),
      imageScale:
          _boundedDouble(presentation['image_scale'], 80, 150, 100) / 100,
      imagePosition: _choice(
        presentation['image_position'],
        const <String>{'center', 'top', 'bottom', 'left', 'right'},
        'center',
      ),
      imageBorderWidth: _boundedDouble(
        presentation['border_width'],
        0,
        8,
        0,
      ),
      imageBorderColor: _hexColor(
        presentation['border_color'],
        '#DDE5E2',
      ),
      imageBackgroundColor: _hexColor(
        presentation['background_color'],
        '#FFFFFF',
      ),
      imageTextGap: _boundedDouble(
        presentation['image_text_gap'],
        0,
        40,
        10,
      ),
      fontSize: _boundedDouble(presentation['font_size'], 10, 30, 16),
      fontColor: _hexColor(presentation['font_color'], '#1F2933'),
      fontWeight: _fontWeight(presentation['font_weight']),
      textAlign: _choice(
        presentation['text_align'],
        const <String>{'start', 'center', 'end'},
        'start',
      ),
      textMaxLines: _boundedDouble(
        presentation['text_max_lines'],
        1,
        3,
        2,
      ).round(),
      lineHeight:
          _boundedDouble(presentation['line_height'], 100, 200, 125) / 100,
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
      categoryLayout: categoryLayout,
      navigationMode: navigationMode,
      gridColumns: gridColumns,
      cardRadius: cardRadius,
      cardGap: cardGap,
      cardWidthPercent: cardWidthPercent,
      cardHeight: cardHeight,
      marginTop: marginTop,
      marginBottom: marginBottom,
      spaceUp: spaceUp,
      spaceDown: spaceDown,
      pageBackgroundColor: pageBackgroundColor,
      elementBackgroundColor: elementBackgroundColor,
      cardStyle: cardStyle,
      cardBackgroundColor: cardBackgroundColor,
      cardShadowColor: cardShadowColor,
      cardShadowStrength: cardShadowStrength,
      cardShadowBlur: cardShadowBlur,
      cardShadowOffsetY: cardShadowOffsetY,
      showArrow: showArrow,
      imageSize: imageSize,
      imageShape: imageShape,
      imageRadius: imageRadius,
      imageFit: imageFit,
      imageEffect: imageEffect,
      imageScale: imageScale,
      imagePosition: imagePosition,
      imageBorderWidth: imageBorderWidth,
      imageBorderColor: imageBorderColor,
      imageBackgroundColor: imageBackgroundColor,
      imageTextGap: imageTextGap,
      fontSize: fontSize,
      fontColor: fontColor,
      fontWeight: fontWeight,
      textAlign: textAlign,
      textMaxLines: textMaxLines,
      lineHeight: lineHeight,
    );
  }

  static int _nonNegativeCount(dynamic value) {
    final int parsed = CatalogJson.integer(value);
    if (parsed < 0) {
      return 0;
    }
    return parsed > 0x7fffffff ? 0x7fffffff : parsed;
  }

  static double _boundedDouble(
    dynamic value,
    double minimum,
    double maximum,
    double fallback,
  ) {
    final double? parsed = double.tryParse(value?.toString() ?? '');
    return parsed == null
        ? fallback
        : parsed.clamp(minimum, maximum).toDouble();
  }

  static String _choice(
    dynamic value,
    Set<String> choices,
    String fallback,
  ) {
    final String parsed = CatalogJson.string(value).toLowerCase();
    return choices.contains(parsed) ? parsed : fallback;
  }

  static String _hexColor(dynamic value, String fallback) {
    final String parsed = CatalogJson.string(value).toUpperCase();
    return RegExp(r'^#[0-9A-F]{6}$').hasMatch(parsed) ? parsed : fallback;
  }

  static int _fontWeight(dynamic value) {
    final int parsed = CatalogJson.integer(value, fallback: 800);
    return const <int>{400, 500, 600, 700, 800, 900}.contains(parsed)
        ? parsed
        : 800;
  }
}
