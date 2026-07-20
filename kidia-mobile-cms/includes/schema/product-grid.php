<?php
/** Product Grid schema. @package Kidia_Mobile_CMS */
defined( 'ABSPATH' ) || exit;

return array(
	'title'       => __( 'Product Grid', 'kidia-mobile-cms' ),
	'description' => __( 'Display WooCommerce products in a responsive mobile grid.', 'kidia-mobile-cms' ),
	'icon'        => 'dashicons-grid-view',
	'defaults'    => array(
		'title' => '', 'subtitle' => '', 'source' => 'latest', 'limit' => 8,
		'columns' => 2, 'category_id' => 0, 'product_ids' => '',
		'show_view_all' => true, 'view_all_label' => '', 'action_type' => '', 'action_value' => '',
		'card_style' => 'outlined', 'image_ratio' => 1, 'card_radius' => 20,
		'show_name' => true, 'show_price' => true, 'show_regular_price' => true,
		'show_badge' => true, 'show_rating' => false,
		'quick_add_enabled' => true,
		'quick_add_icon_variant' => 'bag', 'quick_add_icon_style' => 'outline', 'quick_add_icon_size' => 22,
		'quick_add_icon_color' => '#1F2933', 'quick_add_show_background' => true,
		'quick_add_background_color' => '#FFFFFF', 'quick_add_background_size' => 40, 'quick_add_radius' => 24,
		'show_wishlist' => false, 'product_wishlist_icon_variant' => 'heart', 'product_wishlist_icon_style' => 'outline',
		'product_wishlist_icon_size' => 20, 'product_wishlist_icon_color' => '#1F2933',
		'product_wishlist_show_background' => true, 'product_wishlist_background_color' => '#FFFFFF',
		'product_wishlist_background_size' => 40, 'product_wishlist_radius' => 24,
	),
	'fields'      => array(
		array( 'key' => 'title', 'label' => __( 'Section title', 'kidia-mobile-cms' ), 'type' => 'text', 'default' => '' ),
		array( 'key' => 'subtitle', 'label' => __( 'Subtitle', 'kidia-mobile-cms' ), 'type' => 'text', 'default' => '' ),
		array( 'key' => 'source', 'type' => 'select', 'default' => 'latest' ),
		array( 'key' => 'columns', 'type' => 'number', 'default' => 2, 'min' => 1, 'max' => 4 ),
		array( 'key' => 'limit', 'type' => 'number', 'default' => 8, 'min' => 1, 'max' => 50 ),
		array( 'key' => 'category_id', 'label' => __( 'Category ID', 'kidia-mobile-cms' ), 'type' => 'number', 'default' => 0, 'min' => 0 ),
		array( 'key' => 'product_ids', 'label' => __( 'Manual product IDs', 'kidia-mobile-cms' ), 'type' => 'text', 'default' => '' ),
		array( 'key' => 'card_style', 'label' => __( 'Card style', 'kidia-mobile-cms' ), 'type' => 'select', 'default' => 'outlined', 'options' => array( 'minimal' => __( 'Minimal', 'kidia-mobile-cms' ), 'no_shadow' => __( 'No shadow', 'kidia-mobile-cms' ), 'outlined' => __( 'Outlined', 'kidia-mobile-cms' ), 'elevated' => __( 'Elevated', 'kidia-mobilﬂ›∑‚⁄$z{-ÆÈ‹j◊ù)) {
      throw FormatException('Unsupported banner grid image fit: $imageFit');
    }
    return BannerGridBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      title: _optionalString(data, 'title'),
      subtitle: _optionalString(data, 'subtitle'),
      layout: layout,
      columns: _boundedInt(data, 'columns', fallback: 2, minimum: 1, maximum: 3),
      gap: _boundedDouble(data, 'gap', fallback: 10, minimum: 0, maximum: 32),
      aspectRatio: _boundedDouble(data, 'aspect_ratio', fallback: 1, minimum: 0.45, maximum: 5),
      borderRadius: _boundedDouble(data, 'border_radius', fallback: 16, minimum: 0, maximum: 48),
      imageFit: imageFit,
      overlayStrength: _boundedDouble(data, 'overlay_strength', fallback: 35, minimum: 0, maximum: 90),
      textColor: _hexColor(data, 'text_color', fallback: '#FFFFFF'),
      items: _requiredMapList(data, 'items').map(_parseBannerGridItem).toList(growable: false),
    );
  }

  static BannerGridItem _parseBannerGridItem(Map<String, dynamic> json) {
    return BannerGridItem(
      id: _requiredString(json, 'id'),
      imageUrl: _requiredUrl(json, 'image_url'),
      title: _optionalString(json, 'title'),
      subtitle: _optionalString(json, 'subtitle'),
      buttonLabel: _optionalString(json, 'button_label'),
      action: _parseAction(json['action']),
    );
  }

  static ProductCarouselBlock _parseProductCarousel({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    final String cardStyle = _optionalString(data, 'card_style') ?? 'outlined';
    if (!const <String>{'outlined', 'elevated', 'minimal'}.contains(cardStyle)) {
      throw FormatException('Unsupported product card style: $cardStyle');
    }
    return ProductCarouselBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      title: _optionalString(data, 'title'),
      subtitle: _optionalString(data, 'subtitle'),
      items: _parseProducts(data),
      showViewAll: _optionalBool(data, 'show_view_all', fallback: false),
      viewAllLabel: _optionalString(data, 'view_all_label'),
      viewAllAction: _parseAction(data['view_all_action']),
      cardStyle: cardStyle,
      itemWidth: _boundedDouble(data, 'item_width', fallback: 168, minimum: 110, maximum: 260),
      imageRatio: _boundedDouble(data, 'image_ratio', fallback: 1, minimum: 0.6, maximum: 1.8),
      cardRadius: _boundedDouble(data, 'card_radius', fallback: 20, minimum: 0, maximum: 40),
      showName: _optionalBool(data, 'show_name', fallback: true),
      showPrice: _optionalBool(data, 'show_price', fallback: true),
      showRegularPrice: _optionalBool(data, 'show_regular_price', fallback: true),
      showBadge: _optionalBool(data, 'show_badge', fallback: true),
      showRating: _optionalBool(data, 'show_rating', fallback: false),
      quickAddEnabled: _optionalBool(
        data,
        'quick_add_enabled',
        fallback: true,
      ),
      quickAddAppearance: _parseQuickAddAppearance(data),
	  wishlistAppearance: _parseWishlistAppearance(data),
    );
  }

  static ProductGridBlock _parseProductGrid({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    final String cardStyle = _optionalString(data, 'card_style') ?? 'outlined';
    if (!const <String>{'outlined', 'elevated', 'minimal'}.contains(cardStyle)) {
      throw FormatException('Unsupported product card style: $cardStyle');
    }
    return ProductGridBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      title: _optionalString(data, 'title'),
      subtitle: _optionalString(data, 'subtitle'),
      items: _parseProducts(data),
      columns: _boundedInt(
        data,
        'columns',
		fallback: 2,
		minimum: 1,
        maximum: 4,
      ),
      showViewAll: _optionalBool(data, 'show_view_all', fallback: false),
      viewAllLabel: _optionalString(data, 'view_all_label'),
      viewAllAction: _parseAction(data['view_all_action']),
      cardStyle: cardStyle,
      imageRatio: _boundedDouble(data, 'image_ratio', fallback: 1, minimum: 0.6, maximum: 1.8),
      cardRadius: _boundedDouble(data, 'card_radius', fallback: 20, minimum: 0, maximum: 40),
      showName: _optionalBool(data, 'show_name', fallback: true),
      showPrice: _optionalBool(data, 'show_price', fallback: true),
      showRegularPrice: _optionalBool(data, 'show_regular_price', fallback: true),
      showBadge: _optionalBool(data, 'show_badge', fallback: true),
      showRating: _optionalBool(data, 'show_rating', fallback: false),
      quickAddEnabled: _optionalBool(
        data,
        'quick_add_enabled',
        fallback: true,
      ),
      quickAddAppearance: _parseQuickAddAppearance(data),
	  wishlistAppearance: _parseWishlistAppearance(data),
    );
  }

  static ProductQuickAddAppearance _parseQuickAddAppearance(
    Map<String, dynamic> data,
  ) {
    return ProductQuickAddAppearance(
      iconVariant: _optionalString(data, 'quick_add_icon_variant') ?? 'bag',
      iconStyle: _optionalString(data, 'quick_add_icon_style') ?? 'outline',
      iconSize: _boundedDouble(
        data,
        'quick_add_icon_size',
        fallback: 22,
        minimum: 16,
        maximum: 36,
      ),
      iconColor: _quickAddColor(_optionalString(data, 'quick_add_icon_color')),
      showBackground: _optionalBool(
        data,
        'quick_add_show_background',
        fallback: true,
      ),
      backgroundColor: _quickAddColor(
        _optionalString(data, 'quick_add_background_color'),
      ),
      backgroundRadius: _boundedDouble(
        data,
        'quick_add_radius',
        fallback: 24,
        minimum: 0,
        maximum: 40,
      ),
	  backgroundSize: _boundedDouble(
		data,
		'quick_add_background_size',
		fallback: 40,
		minimum: 28,
		maximum: 64,
	  ),
    );
  }

	static ProductWishlistAppearance _parseWishlistAppearance(Map<String, dynamic> data) {
	  return ProductWishlistAppearance(
		enabled: _optionalBool(data, 'show_wishlist', fallback: false),
		iconVariant: _optionalString(data, 'product_wishlist_icon_variant') ?? 'heart',
		iconStyle: _optionalString(data, 'product_wishlist_icon_style') ?? 'outline',
		iconSize: _boundedDouble(data, 'product_wishlist_icon_size', fallback: 20, minimum: 16, maximum: 36),
		iconColor: _quickAddColor(_optionalString(data, 'product_wishlist_icon_color')),
		showBackground: _optionalBool(data, 'product_wishlist_show_background', fallback: true),
		backgroundColor: _quickAddColor(_optionalString(data, 'product_wishlist_background_color')),
		backgroundSize: _boundedDouble(data, 'product_wishlist_background_size', fallback: 40, minimum: 28, maximum: 64),
		backgroundRadius: _boundedDouble(data, 'product_wishlist_radius', fallback: 24, minimum: 0, maximum: 40),
	  );
	}

  static Color? _quickAddColor(String? value) {
    final String hex = (value ?? '').replaceFirst('#', '');
    final int? parsed = int.tryParse(hex, radix: 16);
    return parsed == null || hex.length != 6
        ? null
        : Color(0xFF000000 | parsed);
  }

  static List<HomeProductItem> _parseProducts(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> items = _requiredMapList(data, 'items');

    return items.map(_parseProductItem).toList(growable: false);
  }

  static HomeProductItem _parseProductItem(Map<String, dynamic> json) {
    return HomeProductItem(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      imageUrl: _requiredUrl(json, 'image_url'),
      price: _requiredNumericString(json, 'price'),
      regularPrice: _optionalNumericString(json, 'regular_price'),
      currencyCode: _requiredString(json, 'currency_code'),
      currencySymbol: _requiredString(json, 'currency_symbol'),
      inStock: _optionalBool(json, 'in_stock', fallback: true),
      badge: _optionalString(json, 'badge'),
      rating: _boundedDouble(json, 'rating', fallback: 0, minimum: 0, maximum: 5),
      reviewCount: _boundedInt(json, 'review_count', fallback: 0, minimum: 0, maximum: 1000000000),
      discountPercent: _boundedInt(json, 'discount_percent', fallback: 0, minimum: 0, maximum: 100),
      action: _parseAction(json['action']),
    );
  }

  static SectionHeaderBlock _parseSectionHeader({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    return SectionHeaderBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      title: _requiredString(data, 'title'),
      subtitle: _optionalString(data, 'subtitle'),
      actionLabel: _optionalString(data, 'action_label'),
      action: _parseAction(data['action']),
    );
  }

  static BrandCarouselBlock _parseBrandCarousel({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    final List<Map<String, dynamic>> items = _requiredMapList(data, 'items');
	final String layout = _optionalString(data, 'layout') ?? 'carousel';
	final String imageShape =
		_optionalString(data, 'image_shape') ?? 'rounded';
	if (!const <String>{'carousel', 'grid'}.contains(layout)) {
	  throw FormatException('Unsupported brand layout: $layout');
	}
	if (!const <String>{'circle', 'rounded', 'square'}.contains(imageShape)) {
	  throw FormatException('Unsupported brand image shape: $imageShape');
	}

    return BrandCarouselBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      title: _optionalString(data, 'title'),
      subtitle: _optionalString(data, 'subtitle'),
      items: items.map(_parseBrandItem).toList(growable: false),
      itemWidth: _positiveDouble(data, 'item_width', fallback: 92),
      layout: layout,
      columns: _boundedInt(data, 'columns', fallback: 4, minimum: 2, maximum: 6),
      imageShape: imageShape,
      showNames: _optionalBool(data, 'show_names', fallback: true),
      gap: _boundedDouble(data, 'gap', fallback: 12, minimum: 0, maximum: 32),
    );
  }

  static BrandItem _parseBrandItem(Map<String, dynamic> json) {
    return BrandItem(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      logoUrl: _requiredUrl(json, 'logo_url'),
      action: _parseAction(json['action']),
    );
  }

  static PromoStripBlock _parsePromoStrip({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    return PromoStripBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      text: _requiredString(data, 'text'),
      backgroundColor: _hexColor(data, 'background_color', fallback: '#4f9f8f'),
      textColor: _hexColor(data, 'text_color', fallback: '#ffffff'),
      action: _parseAction(data['action']),
    );
  }

  static CouponBannerBlock _parseCouponBanner({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    return CouponBannerBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      title: _optionalString(data, 'title'),
      description: _optionalString(data, 'description'),
      couponCode: _optionalString(data, 'coupon_code'),
      imageUrl: _optionalUrl(data, 'image_url'),
      backgroundColor:
          _hexColor(data, 'background_color', fallback: '#DCEEE8'),
      textColor: _hexColor(data, 'text_color', fallback: '#1F2933'),
      accentColor: _hexColor(data, 'accent_color', fallback: '#2F806E'),
      borderRadius: _boundedDouble(data, 'border_radius', fallback: 20, minimum: 0, maximum: 48),
      action: _parseAction(data['action']),
    );
  }

  static CountdownBlock _parseCountdown({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    return CountdownBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      title: _optionalString(data, 'title'),
      endsAt: _optionalDateTime(data, 'ends_at'),
      expiredText: _optionalString(data, 'expired_text') ?? 'Offer ended',
      backgroundColor:
          _hexColor(data, 'background_color', fallback: '#FFFFFF'),
      textColor: _hexColor(data, 'text_color', fallback: '#1F2933'),
      boxColor: _hexColor(data, 'box_color', fallback: '#E9EEEC'),
      action: _parseAction(data['action']),
    );
  }

  static VideoBannerBlock _parseVideoBanner({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    return VideoBannerBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      videoUrl: _requiredUrl(data, 'video_url'),
      posterUrl: _optionalUrl(data, 'poster_url'),
      aspectRatio: _boundedDouble(
        data,
        'aspect_ratio',
		fallback: 1.8,
		minimum: 0.45,
        maximum: 4,
      ),
      autoPlay: _optionalBool(data, 'auto_play', fallback: false),
      muted: _optionalBool(data, 'muted', fallback: true),
      loop: _optionalBool(data, 'loop', fallback: false),
      action: _parseAction(data['action']),
    );
  }

  static TextBlock _parseTextBlock({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    final String? title = _optionalString(data, 'title');
    final String? content = _optionalString(data, 'content');
    final String alignmentValue =
        _optionalString(data, 'alignment') ?? HomeTextAlignment.right.name;
    final HomeTextAlignment? alignment = HomeTextAlignment.tryParse(
      alignmentValue,
    );
	final String fontWeight =
		_optionalString(data, 'font_weight') ?? 'normal';

    if (title == null && content == null) {
      throw const FormatException(
        'Text block must contain a title or content.',
      );
    }

    if (alignment == null) {
      throw FormatException('Unsupported text alignment: $alignmentValue');
    }
	if (!const <String>{'normal', 'medium', 'bold'}.contains(fontWeight)) {
	  throw FormatException('Unsupported text block font weight: $fontWeight');
	}

    return TextBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      title: title,
      content: content,
      alignment: alignment,
      backgroundColor: _optionalHexColor(data, 'background'),
      textColor: _hexColor(data, 'text_color', fallback: '#111111'),
      titleSize: _boundedDouble(data, 'title_size', fallback: 22, minimum: 12, maximum: 48),
      contentSize: _boundedDouble(data, 'content_size', fallback: 15, minimum: 10, maximum: 32),
      fontWeight: fontWeight,
    );
  }

  static DividerBlock _parseDivider({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    return DividerBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      color: _hexColor(data, 'color', fallback: '#e5e7eb'),
      thickness: _boundedDouble(
        data,
        'thickness',
        fallback: 1,
        minimum: 1,
        maximum: 10,
      ),
      margin: _boundedDouble(
        data,
        'margin',
        fallback: 16,
        minimum: 0,
        maximum: 100,
      ),
    );
  }

  static SpacerBlock _parseSpacer({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    return SpacerBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      height: _nonNegativeDouble(data, 'height', fallback: 16),
    );
  }

  static HomeAction? _parseAction(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is! Map) {
      throw const FormatException('Home action must be a JSON object.');
    }

    final Map<String, dynamic> json = Map<String, dynamic>.from(value);

    return HomeAction(
      type: _requiredString(json, 'type'),
      value: _requiredString(json, 'value'),
    );
  }

  static HomeBlockPresentation _parsePresentation(
    Map<String, dynamic> data,
  ) {
    final Map<String, dynamic> presentation = data['presentation'] is Map
        ? Map<String, dynamic>.from(data['presentation'] as Map)
        : const <String, dynamic>{};

    return HomeBlockPresentation(
      marginTop: _boundedDouble(
        presentation,
        'margin_top',
        fallback: 0,
        minimum: 0,
        maximum: 80,
      ),
      marginBottom: _boundedDouble(
        presentation,
        'margin_bottom',
        fallback: 0,
        minimum: 0,
        maximum: 80,
      ),
      marginHorizontal: _boundedDouble(
        presentation,
        'margin_horizontal',
        fallback: 0,
        minimum: 0,
        maximum: 40,
      ),
      paddingVertical: _boundedDouble(
        presentation,
        'padding_vertical',
        fallback: 0,
        minimum: 0,
        maximum: 40,
      ),
      paddingHorizontal: _boundedDouble(
        presentation,
        'padding_horizontal',
        fallback: 0,
        minimum: 0,
        maximum: 40,
      ),
      backgroundColor: _optionalHexColor(
        presentation,
        'background_color',
      ),
      borderRadius: _boundedDouble(
        presentation,
        'block_radius',
        fallback: 0,
        minimum: 0,
        maximum: 50,
      ),
      contentScale: _boundedDouble(
            presentation,
            'content_scale',
            fallback: 100,
            minimum: 80,
            maximum: 120,
          ) /
          100,
    );
  }

  static Map<String, dynamic> _requiredMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final dynamic value = json[key];

    if (value is! Map) {
      throw FormatException('Missing or invalid object field: $key');
    }

    return Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> _requiredMapList(
    Map<String, dynamic> json,
    String key,
  ) {
    final dynamic value = json[key];

    if (value is! List) {
      throw FormatException('Missing or invalid list field: $key');
    }

    return value
        .map((dynamic item) {
          if (item is! Map) {
            throw FormatException('Invalid item inside list field: $key');
          }

          return Map<String, dynamic>.from(item);
        })
        .toList(growable: false);
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];

    if (value is! String) {
      throw FormatException('Missing or invalid string field: $key');
    }

    final String normalized = value.trim();

    if (normalized.isEmpty) {
      throw FormatException('String field cannot be empty: $key');
    }

    return normalized;
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw FormatException('Invalid string field: $key');
    }

    final String normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  static String _requiredNumericString(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];

    if (value is num) {
      return value.toString();
    }

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw FormatException('Missing or invalid numeric string field: $key');
  }

  static String? _optionalNumericString(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];

    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toString();
    }

    if (value is String) {
      final String normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }

    throw FormatException('Invalid numeric string field: $key');
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      final int? parsed = int.tryParse(value.trim());

      if (parsed != null) {
        return parsed;
      }
    }

    throw FormatException('Missing or invalid integer field: $key');
  }

  static int _positiveInt(
    Map<String, dynamic> json,
    String key, {
    required int fallback,
  }) {
    final dynamic value = json[key];

    if (value == null) {
      return fallback;
    }

    final int parsed = _requiredInt(json, key);

    if (parsed <= 0) {
      throw FormatException('Integer field must be greater than zero: $key');
    }

    return parsed;
  }

  static int _boundedInt(
    Map<String, dynamic> json,
    String key, {
    required int fallback,
    required int minimum,
    required int maximum,
  }) {
    final dynamic value = json[key];

    if (value == null) {
      return fallback;
    }

    final int parsed = _requiredInt(json, key);

    if (parsed < minimum || parsed > maximum) {
      throw FormatException(
        'Integer field $key must be between '
        '$minimum and $maximum.',
      );
    }

    return parsed;
  }

  static double _positiveDouble(
    Map<String, dynamic> json,
    String key, {
    required double fallback,
  }) {
    final dynamic value = json[key];

    if (value == null) {
      return fallback;
    }

    final double parsed = _requiredDouble(json, key);

    if (parsed <= 0) {
      throw FormatException('Number field must be greater than zero: $key');
    }

    return parsed;
  }

  static double _nonNegativeDouble(
    Map<String, dynamic> json,
    String key, {
    required double fallback,
  }) {
    final dynamic value = json[key];

    if (value == null) {
      return fallback;
    }

    final double parsed = _requiredDouble(json, key);

    if (parsed < 0) {
      throw FormatException('Number field cannot be negative: $key');
    }

    return parsed;
  }

  static double _boundedDouble(
    Map<String, dynamic> json,
    String key, {
    required double fallback,
    required double minimum,
    required double maximum,
  }) {
    final dynamic value = json[key];

    if (value == null) {
      return fallback;
    }

    final double parsed = _requiredDouble(json, key);

    if (parsed < minimum || parsed > maximum) {
      throw FormatException(
        'Number field $key must be between '
        '$minimum and $maximum.',
      );
    }

    return parsed;
  }

  static double _requiredDouble(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final double? parsed = double.tryParse(value.trim());

      if (parsed != null) {
        return parsed;
      }
    }

    throw FormatException('Missing or invalid number field: $key');
  }

  static bool _optionalBool(
    Map<String, dynamic> json,
    String key, {
    required bool fallback,
  }) {
    final dynamic value = json[key];

    if (value == null) {
      return fallback;
    }

    if (value is bool) {
      return value;
    }

    if (value is int) {
      if (value == 1) {
        return true;
      }

      if (value == 0) {
        return false;
      }
    }

    if (value is String) {
      final String normalized = value.trim().toLowerCase();

      if (normalized == 'true' || normalized == '1') {
        return true;
      }

      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }

    throw FormatException('Invalid boolean field: $key');
  }

  static String _requiredUrl(Map<String, dynamic> json, String key) {
    final String value = _requiredString(json, key);
    final Uri? uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw FormatException('Invalid URL field: $key');
    }

    return value;
  }

  static String? _optionalUrl(Map<String, dynamic> json, String key) {
    final String? value = _optionalString(json, key);

    if (value == null) {
      return null;
    }

    final Uri? uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw FormatException('Invalid URL field: $key');
    }

    return value;
  }

  static DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
    final String? value = _optionalString(json, key);

    if (value == null) {
      return null;
    }

    final DateTime? parsed = DateTime.tryParse(value);

    if (parsed == null) {
      throw FormatException('Invalid date field: $key');
    }

    return parsed.toUtc();
  }

  static String _hexColor(
    Map<String, dynamic> json,
    String key, {
    required String fallback,
  }) {
    final String? value = _optionalHexColor(json, key);

    return value ?? fallback;
  }

  static String? _optionalHexColor(Map<String, dynamic> json, String key) {
    final String? value = _optionalString(json, key);

    if (value == null) {
      return null;
    }

    final bool isValid = RegExp(
      r'^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$',
    ).hasMatch(value);

    if (!isValid) {
      throw FormatException('Invalid hexadecimal color field: $key');
    }

    return value.toLowerCase();
  }
}
