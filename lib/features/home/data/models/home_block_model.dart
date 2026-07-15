import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';

abstract final class HomeBlockModel {
  const HomeBlockModel._();

  static HomeBlock fromJson(Map<String, dynamic> json) {
    final String id = _requiredString(json, 'id');
    final String rawType = _requiredString(json, 'type');
    final HomeBlockType? type = HomeBlockType.tryParse(rawType);
    final bool enabled = _optionalBool(json, 'enabled', fallback: true);
    final Map<String, dynamic> data = _requiredMap(json, 'data');

    if (type == null) {
      throw FormatException('Unsupported home block type: $rawType');
    }

    return switch (type) {
      HomeBlockType.heroSlider => _parseHeroSlider(id, enabled, data),
      HomeBlockType.categoryGrid => _parseCategoryGrid(id, enabled, data),
      HomeBlockType.imageBanner => _parseImageBanner(id, enabled, data),
      HomeBlockType.productCarousel => _parseProductCarousel(id, enabled, data),
      HomeBlockType.productGrid => _parseProductGrid(id, enabled, data),
      HomeBlockType.sectionHeader => _parseSectionHeader(id, enabled, data),
      HomeBlockType.brandCarousel => _parseBrandCarousel(id, enabled, data),
      HomeBlockType.promoStrip => _parsePromoStrip(id, enabled, data),
      HomeBlockType.couponBanner => _parseCouponBanner(id, enabled, data),
      HomeBlockType.countdown => _parseCountdown(id, enabled, data),
      HomeBlockType.videoBanner => _parseVideoBanner(id, enabled, data),
      HomeBlockType.textBlock => _parseTextBlock(id, enabled, data),
      HomeBlockType.divider => _parseDivider(id, enabled, data),
      HomeBlockType.spacer => _parseSpacer(id, enabled, data),
    };
  }

  static HeroSliderBlock _parseHeroSlider(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    final List<Map<String, dynamic>> rawItems = _mapList(data, 'items');
    final List<HeroSlide> items = rawItems
        .map(_parseHeroSlide)
        .whereType<HeroSlide>()
        .toList(growable: false);

    if (items.isEmpty) {
      throw const FormatException('Hero slider has no renderable images.');
    }

    return HeroSliderBlock(
      id: id,
      enabled: enabled,
      items: items,
      aspectRatio: _boundedDouble(
        data,
        'aspect_ratio',
        fallback: 1.8,
        minimum: 0.5,
        maximum: 5,
      ),
      autoPlay: _optionalBool(data, 'auto_play', fallback: true),
      intervalMilliseconds: _boundedInt(
        data,
        'interval_ms',
        fallback: 4500,
        minimum: 1000,
        maximum: 60000,
      ),
      loop: _optionalBool(data, 'loop', fallback: true),
      showArrows: _optionalBool(data, 'show_arrows', fallback: true),
      showDots: _optionalBool(data, 'show_dots', fallback: true),
      transition: _choice(
        data,
        'transition',
        fallback: 'slide',
        allowed: const <String>{'slide', 'fade'},
      ),
      slideDirection: _choice(
        data,
        'slide_direction',
        fallback: 'horizontal',
        allowed: const <String>{'horizontal', 'vertical'},
      ),
    );
  }

  static HeroSlide? _parseHeroSlide(Map<String, dynamic> json) {
    final String? imageUrl = _optionalUrl(json, 'image_url');
    if (imageUrl == null) {
      return null;
    }

    return HeroSlide(
      id: _optionalString(json, 'id') ?? imageUrl,
      imageUrl: imageUrl,
      title: _optionalString(json, 'title'),
      subtitle: _optionalString(json, 'subtitle'),
      action: _parseAction(json['action']),
    );
  }

  static CategoryGridBlock _parseCategoryGrid(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    final List<CategoryItem> items = _mapList(
      data,
      'items',
    ).map(_parseCategoryItem).whereType<CategoryItem>().toList(growable: false);

    return CategoryGridBlock(
      id: id,
      enabled: enabled,
      items: items,
      columns: _boundedInt(
        data,
        data.containsKey('columns_mobile') ? 'columns_mobile' : 'columns',
        fallback: 4,
        minimum: 2,
        maximum: 6,
      ),
      layout: _choice(
        data,
        'layout',
        fallback: 'grid',
        allowed: const <String>{'grid', 'compact', 'carousel'},
      ),
      style: _choice(
        data,
        'style',
        fallback: 'circle',
        allowed: const <String>{
          'simple',
          'badge',
          'overlay',
          'grid',
          'circle',
          'square',
          'card',
        },
      ),
      gap: _boundedDouble(data, 'gap', fallback: 10, minimum: 0, maximum: 48),
      imageRatio: _boundedDouble(
        data,
        'image_ratio',
        fallback: 1,
        minimum: 0.4,
        maximum: 3,
      ),
      showNames: _optionalBool(data, 'show_names', fallback: true),
      showCount: _optionalBool(data, 'show_count', fallback: false),
    );
  }

  static CategoryItem? _parseCategoryItem(Map<String, dynamic> json) {
    final int? id = _optionalInt(json, 'id');
    final String? name = _optionalString(json, 'name');
    final String? imageUrl = _optionalUrl(json, 'image_url');
    if (id == null || id <= 0 || name == null || imageUrl == null) {
      return null;
    }

    return CategoryItem(
      id: id,
      name: name,
      imageUrl: imageUrl,
      count: (_optionalInt(json, 'count') ?? 0).clamp(0, 1 << 31).toInt(),
      action: _parseAction(json['action']),
    );
  }

  static ImageBannerBlock _parseImageBanner(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    return ImageBannerBlock(
      id: id,
      enabled: enabled,
      imageUrl: _requiredUrl(data, 'image_url'),
      aspectRatio: _boundedDouble(
        data,
        'aspect_ratio',
        fallback: 2.4,
        minimum: 0.5,
        maximum: 5,
      ),
      borderRadius: _boundedDouble(
        data,
        'border_radius',
        fallback: 16,
        minimum: 0,
        maximum: 80,
      ),
      semanticLabel: _optionalString(data, 'semantic_label'),
      title: _optionalString(data, 'title'),
      subtitle: _optionalString(data, 'subtitle'),
      buttonLabel: _optionalString(data, 'button_label'),
      imageFit: _choice(
        data,
        'image_fit',
        fallback: 'cover',
        allowed: const <String>{'cover', 'contain', 'fill'},
      ),
      focalX: _focalPoint(data, 'focal_x'),
      focalY: _focalPoint(data, 'focal_y'),
      overlayColor: _color(data, 'overlay_color', fallback: '#000000'),
      overlayOpacity: _boundedDouble(
        data,
        'overlay_opacity',
        fallback: 0,
        minimum: 0,
        maximum: 1,
      ),
      action: _blockAction(data),
    );
  }

  static ProductCarouselBlock _parseProductCarousel(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    final Map<String, dynamic> layout = _optionalMap(data, 'layout');

    return ProductCarouselBlock(
      id: id,
      enabled: enabled,
      title: _optionalString(data, 'title'),
      items: _parseProducts(data),
      showViewAll: _optionalBool(data, 'show_view_all', fallback: false),
      viewAllAction: _parseAction(data['view_all_action']),
      display: ProductDisplaySettings(
        cardsVisible: _boundedDouble(
          layout,
          'cards_visible',
          fallback: 2.15,
          minimum: 1,
          maximum: 5,
        ),
        gap: _boundedDouble(
          layout,
          'gap',
          fallback: 12,
          minimum: 0,
          maximum: 48,
        ),
        cardStyle: _choice(
          layout,
          'card_style',
          fallback: 'standard',
          allowed: const <String>{'standard', 'compact', 'outlined'},
        ),
        imageRatio: _boundedDouble(
          layout,
          'image_ratio',
          fallback: 1,
          minimum: 0.4,
          maximum: 3,
        ),
        showRating: _optionalBool(layout, 'show_rating', fallback: true),
        showCategory: _optionalBool(layout, 'show_category', fallback: false),
        showBadge: _optionalBool(layout, 'show_badge', fallback: true),
        showStock: _optionalBool(layout, 'show_stock', fallback: true),
        showArrows: _optionalBool(layout, 'show_arrows', fallback: false),
        showDots: _optionalBool(layout, 'show_dots', fallback: false),
      ),
    );
  }

  static ProductGridBlock _parseProductGrid(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    return ProductGridBlock(
      id: id,
      enabled: enabled,
      title: _optionalString(data, 'title'),
      items: _parseProducts(data),
      columns: _boundedInt(
        data,
        data.containsKey('columns_mobile') ? 'columns_mobile' : 'columns',
        fallback: 2,
        minimum: 1,
        maximum: 4,
      ),
      gap: _boundedDouble(data, 'gap', fallback: 12, minimum: 0, maximum: 48),
      cardStyle: _choice(
        data,
        'card_style',
        fallback: 'standard',
        allowed: const <String>{'standard', 'compact', 'outlined'},
      ),
      imageRatio: _boundedDouble(
        data,
        'image_ratio',
        fallback: 1,
        minimum: 0.4,
        maximum: 3,
      ),
      showRating: _optionalBool(data, 'show_rating', fallback: true),
      showBadge: _optionalBool(data, 'show_badge', fallback: true),
      showStock: _optionalBool(data, 'show_stock', fallback: true),
      showViewAll: _optionalBool(data, 'show_view_all', fallback: false),
      viewAllAction: _parseAction(data['view_all_action']),
    );
  }

  static List<HomeProductItem> _parseProducts(Map<String, dynamic> data) {
    return _mapList(data, 'items')
        .map(_parseProductItem)
        .whereType<HomeProductItem>()
        .toList(growable: false);
  }

  static HomeProductItem? _parseProductItem(Map<String, dynamic> json) {
    final int? id = _optionalInt(json, 'id');
    final String? name = _optionalString(json, 'name');
    final String? imageUrl = _optionalUrl(json, 'image_url');
    final String? price = _numericString(json['price']);
    final String? currencyCode = _optionalString(json, 'currency_code');
    final String? currencySymbol = _optionalString(json, 'currency_symbol');
    final String stockStatus =
        _optionalString(json, 'stock_status') ??
        (_optionalBool(json, 'in_stock', fallback: true)
            ? 'instock'
            : 'outofstock');
    final bool inStock = _optionalBool(
      json,
      'in_stock',
      fallback: stockStatus != 'outofstock',
    );

    if (id == null ||
        id <= 0 ||
        name == null ||
        imageUrl == null ||
        price == null ||
        currencyCode == null ||
        currencySymbol == null) {
      return null;
    }

    return HomeProductItem(
      id: id,
      name: name,
      imageUrl: imageUrl,
      price: price,
      regularPrice: _numericString(json['regular_price']),
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      inStock: inStock,
      stockStatus: stockStatus,
      badge: _optionalString(json, 'badge'),
      rating: _boundedDouble(
        json,
        'rating',
        fallback: 0,
        minimum: 0,
        maximum: 5,
      ),
      ratingCount: _boundedInt(
        json,
        'rating_count',
        fallback: 0,
        minimum: 0,
        maximum: 1 << 31,
      ),
      reviewCount: _boundedInt(
        json,
        'review_count',
        fallback: _optionalInt(json, 'rating_count') ?? 0,
        minimum: 0,
        maximum: 1 << 31,
      ),
      category: _optionalString(json, 'category'),
      action: _parseAction(json['action']),
    );
  }

  static SectionHeaderBlock _parseSectionHeader(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    final String? legacyActionLabel = _optionalString(data, 'action_label');
    final String? viewAllLabel =
        _optionalString(data, 'view_all_label') ?? legacyActionLabel;

    return SectionHeaderBlock(
      id: id,
      enabled: enabled,
      title: _requiredString(data, 'title'),
      subtitle: _optionalString(data, 'subtitle'),
      showViewAll: _optionalBool(
        data,
        'show_view_all',
        fallback: viewAllLabel != null,
      ),
      viewAllLabel: viewAllLabel,
      alignment: _choice(
        data,
        'alignment',
        fallback: 'start',
        allowed: const <String>{'start', 'center', 'end'},
      ),
      icon: _optionalString(data, 'icon'),
      dividerStyle: _choice(
        data,
        'divider_style',
        fallback: 'none',
        allowed: const <String>{'none', 'line', 'underline'},
      ),
      action: _blockAction(data),
    );
  }

  static BrandCarouselBlock _parseBrandCarousel(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    final List<BrandItem> items = _mapList(
      data,
      'items',
    ).map(_parseBrandItem).whereType<BrandItem>().toList(growable: false);

    return BrandCarouselBlock(
      id: id,
      enabled: enabled,
      title: _optionalString(data, 'title'),
      items: items,
      itemWidth: _boundedDouble(
        data,
        'item_width',
        fallback: 92,
        minimum: 48,
        maximum: 240,
      ),
      layout: _choice(
        data,
        'layout',
        fallback: 'carousel',
        allowed: const <String>{'carousel', 'grid'},
      ),
      columns: _boundedInt(
        data,
        data.containsKey('columns_mobile') ? 'columns_mobile' : 'columns',
        fallback: 3,
        minimum: 1,
        maximum: 8,
      ),
      gap: _boundedDouble(data, 'gap', fallback: 12, minimum: 0, maximum: 48),
      showNames: _optionalBool(data, 'show_names', fallback: true),
    );
  }

  static BrandItem? _parseBrandItem(Map<String, dynamic> json) {
    final int? id = _optionalInt(json, 'id');
    final String? name = _optionalString(json, 'name');
    final String? logoUrl = _optionalUrl(json, 'logo_url');
    if (id == null || id <= 0 || name == null || logoUrl == null) {
      return null;
    }

    return BrandItem(
      id: id,
      name: name,
      logoUrl: logoUrl,
      action: _parseAction(json['action']),
    );
  }

  static PromoStripBlock _parsePromoStrip(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    return PromoStripBlock(
      id: id,
      enabled: enabled,
      text: _requiredString(data, 'text'),
      backgroundColor: _color(data, 'background_color', fallback: '#4f9f8f'),
      textColor: _color(data, 'text_color', fallback: '#ffffff'),
      buttonLabel: _optionalString(data, 'button_label'),
      dismissible: _optionalBool(data, 'dismissible', fallback: false),
      borderRadius: _boundedDouble(
        data,
        'border_radius',
        fallback: 12,
        minimum: 0,
        maximum: 80,
      ),
      padding: _boundedDouble(
        data,
        'padding',
        fallback: 12,
        minimum: 0,
        maximum: 64,
      ),
      action: _blockAction(data),
    );
  }

  static CouponBannerBlock _parseCouponBanner(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    return CouponBannerBlock(
      id: id,
      enabled: enabled,
      title: _requiredString(data, 'title'),
      description: _optionalString(data, 'description'),
      couponCode: _optionalString(data, 'coupon_code'),
      imageUrl: _optionalUrl(data, 'image_url'),
      copyButtonLabel:
          _optionalString(data, 'copy_button_label') ?? 'نسخ الكود',
      expiresAt: _optionalDate(data, 'expires_at'),
      backgroundColor: _color(data, 'background_color', fallback: '#f3f4f6'),
      textColor: _color(data, 'text_color', fallback: '#111827'),
      buttonLabel: _optionalString(data, 'button_label'),
      action: _blockAction(data),
    );
  }

  static CountdownBlock _parseCountdown(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    final DateTime? endsAt = _optionalDate(data, 'ends_at');
    if (endsAt == null) {
      throw const FormatException('Countdown has an invalid end date.');
    }

    return CountdownBlock(
      id: id,
      enabled: enabled,
      title: _optionalString(data, 'title'),
      endsAt: endsAt,
      expiredText: _optionalString(data, 'expired_text') ?? 'انتهى العرض',
      endBehavior: _choice(
        data,
        'end_behavior',
        fallback: 'message',
        allowed: const <String>{'message', 'hide'},
      ),
      daysLabel: _optionalString(data, 'days_label') ?? 'يوم',
      hoursLabel: _optionalString(data, 'hours_label') ?? 'ساعة',
      minutesLabel: _optionalString(data, 'minutes_label') ?? 'دقيقة',
      secondsLabel: _optionalString(data, 'seconds_label') ?? 'ثانية',
      backgroundColor: _color(data, 'background_color', fallback: '#111827'),
      textColor: _color(data, 'text_color', fallback: '#ffffff'),
      action: _blockAction(data),
    );
  }

  static VideoBannerBlock _parseVideoBanner(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    return VideoBannerBlock(
      id: id,
      enabled: enabled,
      videoUrl: _requiredUrl(data, 'video_url'),
      posterUrl: _optionalUrl(data, 'poster_url'),
      aspectRatio: _boundedDouble(
        data,
        'aspect_ratio',
        fallback: 1.8,
        minimum: 0.5,
        maximum: 5,
      ),
      autoPlay: _optionalBool(data, 'auto_play', fallback: false),
      muted: _optionalBool(data, 'muted', fallback: true),
      loop: _optionalBool(data, 'loop', fallback: false),
      showControls: _optionalBool(data, 'show_controls', fallback: true),
      title: _optionalString(data, 'title'),
      subtitle: _optionalString(data, 'subtitle'),
      buttonLabel: _optionalString(data, 'button_label'),
      overlayColor: _color(data, 'overlay_color', fallback: '#000000'),
      overlayOpacity: _boundedDouble(
        data,
        'overlay_opacity',
        fallback: 0,
        minimum: 0,
        maximum: 1,
      ),
      action: _blockAction(data),
    );
  }

  static TextBlock _parseTextBlock(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    final String? title = _optionalString(data, 'title');
    final String content = _optionalString(data, 'content') ?? '';
    if (title == null && content.isEmpty) {
      throw const FormatException('Text block has no content.');
    }

    return TextBlock(
      id: id,
      enabled: enabled,
      title: title,
      content: content,
      alignment: _choice(
        data,
        'alignment',
        fallback: 'right',
        allowed: const <String>{'left', 'center', 'right'},
      ),
      backgroundColor: _optionalColor(data, 'background'),
      textColor: _color(data, 'text_color', fallback: '#111111'),
      fontSize: _boundedDouble(
        data,
        'font_size',
        fallback: 16,
        minimum: 8,
        maximum: 64,
      ),
      padding: _boundedDouble(
        data,
        'padding',
        fallback: 16,
        minimum: 0,
        maximum: 96,
      ),
      borderRadius: _boundedDouble(
        data,
        'border_radius',
        fallback: 12,
        minimum: 0,
        maximum: 80,
      ),
    );
  }

  static DividerBlock _parseDivider(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    return DividerBlock(
      id: id,
      enabled: enabled,
      color: _color(data, 'color', fallback: '#e5e7eb'),
      thickness: _boundedDouble(
        data,
        'thickness',
        fallback: 1,
        minimum: 1,
        maximum: 20,
      ),
      margin: _boundedDouble(
        data,
        'margin',
        fallback: 16,
        minimum: 0,
        maximum: 100,
      ),
      style: _choice(
        data,
        'style',
        fallback: 'solid',
        allowed: const <String>{'solid', 'dashed', 'dotted'},
      ),
      widthPercent: _boundedDouble(
        data,
        'width_percent',
        fallback: 100,
        minimum: 10,
        maximum: 100,
      ),
      alignment: _choice(
        data,
        'alignment',
        fallback: 'center',
        allowed: const <String>{'left', 'center', 'right'},
      ),
    );
  }

  static SpacerBlock _parseSpacer(
    String id,
    bool enabled,
    Map<String, dynamic> data,
  ) {
    final double height = _boundedDouble(
      data,
      'height',
      fallback: 24,
      minimum: 0,
      maximum: 300,
    );

    return SpacerBlock(
      id: id,
      enabled: enabled,
      height: height,
      tabletHeight: _boundedDouble(
        data,
        'height_tablet',
        fallback: height,
        minimum: 0,
        maximum: 300,
      ),
      desktopHeight: _boundedDouble(
        data,
        'height_desktop',
        fallback: height,
        minimum: 0,
        maximum: 300,
      ),
    );
  }

  static HomeAction? _blockAction(Map<String, dynamic> data) {
    return _parseAction(data['action']) ??
        _parseFlatAction(data['action_type'], data['action_value']);
  }

  static HomeAction? _parseAction(dynamic value) {
    if (value is! Map) {
      return null;
    }

    final Map<String, dynamic> json = Map<String, dynamic>.from(value);
    return _parseFlatAction(json['type'], json['value']);
  }

  static HomeAction? _parseFlatAction(dynamic rawType, dynamic rawValue) {
    final String type = rawType?.toString().trim() ?? '';
    final String value = rawValue?.toString().trim() ?? '';
    if (type.isEmpty || value.isEmpty) {
      return null;
    }

    const Set<String> allowed = <String>{
      'product',
      'category',
      'collection',
      'brand',
      'brands',
      'search',
      'external',
    };

    return allowed.contains(type) ? HomeAction(type: type, value: value) : null;
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

  static Map<String, dynamic> _optionalMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final dynamic value = json[key];
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _mapList(
    Map<String, dynamic> json,
    String key,
  ) {
    final dynamic value = json[key];
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final String? value = _optionalString(json, key);
    if (value == null) {
      throw FormatException('Missing or empty string field: $key');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value == null) {
      return null;
    }
    final String normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String? _numericString(dynamic value) {
    if (value is num) {
      return value.toString();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static int? _optionalInt(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '');
  }

  static int _boundedInt(
    Map<String, dynamic> json,
    String key, {
    required int fallback,
    required int minimum,
    required int maximum,
  }) {
    final int parsed = _optionalInt(json, key) ?? fallback;
    return parsed.clamp(minimum, maximum).toInt();
  }

  static double? _optionalDouble(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString().trim() ?? '');
  }

  static double _boundedDouble(
    Map<String, dynamic> json,
    String key, {
    required double fallback,
    required double minimum,
    required double maximum,
  }) {
    final double parsed = _optionalDouble(json, key) ?? fallback;
    return parsed.clamp(minimum, maximum).toDouble();
  }

  static double _focalPoint(Map<String, dynamic> json, String key) {
    final double raw = _optionalDouble(json, key) ?? 50;
    final double normalized = raw > 1 ? raw / 100 : raw;
    return normalized.clamp(0, 1).toDouble();
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
    if (value is num) {
      return value != 0;
    }
    final String normalized = value.toString().trim().toLowerCase();
    if (<String>{'1', 'true', 'yes', 'on'}.contains(normalized)) {
      return true;
    }
    if (<String>{'0', 'false', 'no', 'off', ''}.contains(normalized)) {
      return false;
    }
    return fallback;
  }

  static String _choice(
    Map<String, dynamic> json,
    String key, {
    required String fallback,
    required Set<String> allowed,
  }) {
    final String? value = _optionalString(json, key)?.toLowerCase();
    return value != null && allowed.contains(value) ? value : fallback;
  }

  static String _requiredUrl(Map<String, dynamic> json, String key) {
    final String? value = _optionalUrl(json, key);
    if (value == null) {
      throw FormatException('Missing or invalid URL field: $key');
    }
    return value;
  }

  static String? _optionalUrl(Map<String, dynamic> json, String key) {
    final String? value = _optionalString(json, key);
    if (value == null) {
      return null;
    }
    final Uri? uri = Uri.tryParse(value);
    return uri != null &&
            uri.hasScheme &&
            (uri.scheme == 'http' || uri.scheme == 'https')
        ? value
        : null;
  }

  static DateTime? _optionalDate(Map<String, dynamic> json, String key) {
    final String? value = _optionalString(json, key);
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  static String _color(
    Map<String, dynamic> json,
    String key, {
    required String fallback,
  }) {
    return _optionalColor(json, key) ?? fallback;
  }

  static String? _optionalColor(Map<String, dynamic> json, String key) {
    final String? value = _optionalString(json, key);
    if (value == null) {
      return null;
    }
    return RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(value)
        ? value
        : null;
  }
}
