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
      HomeBlockType.appHeader => _parseAppHeader(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.heroSlider => _parseHeroSlider(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.categoryGrid => _parseCategoryGrid(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.imageBanner => _parseImageBanner(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.productCarousel => _parseProductCarousel(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.productGrid => _parseProductGrid(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.sectionHeader => _parseSectionHeader(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.brandCarousel => _parseBrandCarousel(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.promoStrip => _parsePromoStrip(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.couponBanner => _parseCouponBanner(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.countdown => _parseCountdown(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.videoBanner => _parseVideoBanner(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.textBlock => _parseTextBlock(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.divider => _parseDivider(
        id: id,
        enabled: enabled,
        data: data,
      ),
      HomeBlockType.spacer => _parseSpacer(
        id: id,
        enabled: enabled,
        data: data,
      ),
    };
  }

  static AppHeaderBlock _parseAppHeader({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    final String layout = _optionalString(data, 'layout') ?? 'center';
    if (layout != 'center' && layout != 'start') {
      throw FormatException('Unsupported app header layout: $layout');
    }
    return AppHeaderBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      logoUrl: _optionalUrl(data, 'logo_url'),
      title: _requiredString(data, 'title'),
      subtitle: _optionalString(data, 'subtitle'),
      layout: layout,
      height: _boundedDouble(
        data,
        'height',
        fallback: 64,
        minimum: 48,
        maximum: 120,
      ),
      logoHeight: _boundedDouble(
        data,
        'logo_height',
        fallback: 38,
        minimum: 20,
        maximum: 80,
      ),
      showSearch: _optionalBool(data, 'show_search', fallback: true),
      showCart: _optionalBool(data, 'show_cart', fallback: true),
      showAccount: _optionalBool(data, 'show_account', fallback: false),
      titleColor: _hexColor(data, 'title_color', fallback: '#1F2933'),
      iconColor: _hexColor(data, 'icon_color', fallback: '#1F2933'),
    );
  }

  static HeroSliderBlock _parseHeroSlider({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    final List<Map<String, dynamic>> items = _requiredMapList(data, 'items');

    if (items.isEmpty) {
      throw const FormatException(
        'Hero slider must contain at least one item.',
      );
    }

    return HeroSliderBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      items: items.map(_parseHeroSlide).toList(growable: false),
      aspectRatio: _positiveDouble(data, 'aspect_ratio', fallback: 1.8),
      autoPlay: _optionalBool(data, 'auto_play', fallback: true),
      intervalMilliseconds: _positiveInt(data, 'interval_ms', fallback: 4500),
    );
  }

  static HeroSlide _parseHeroSlide(Map<String, dynamic> json) {
    return HeroSlide(
      id: _requiredString(json, 'id'),
      imageUrl: _requiredUrl(json, 'image_url'),
      title: _optionalString(json, 'title'),
      subtitle: _optionalString(json, 'subtitle'),
      action: _parseAction(json['action']),
    );
  }

  static CategoryGridBlock _parseCategoryGrid({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    final List<Map<String, dynamic>> items = _requiredMapList(data, 'items');

    return CategoryGridBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      title: _optionalString(data, 'title'),
      subtitle: _optionalString(data, 'subtitle'),
      items: items.map(_parseCategoryItem).toList(growable: false),
      columns: _boundedInt(
        data,
        'columns',
        fallback: 4,
        minimum: 2,
        maximum: 6,
      ),
      showNames: _optionalBool(data, 'show_names', fallback: true),
    );
  }

  static CategoryItem _parseCategoryItem(Map<String, dynamic> json) {
    return CategoryItem(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      imageUrl: _requiredUrl(json, 'image_url'),
      action: _parseAction(json['action']),
    );
  }

  static ImageBannerBlock _parseImageBanner({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    return ImageBannerBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      imageUrl: _requiredUrl(data, 'image_url'),
      aspectRatio: _positiveDouble(data, 'aspect_ratio', fallback: 2.4),
      borderRadius: _nonNegativeDouble(data, 'border_radius', fallback: 16),
      semanticLabel: _optionalString(data, 'semantic_label'),
      action: _parseAction(data['action']),
    );
  }

  static ProductCarouselBlock _parseProductCarousel({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
    return ProductCarouselBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      title: _optionalString(data, 'title'),
      items: _parseProducts(data),
      showViewAll: _optionalBool(data, 'show_view_all', fallback: false),
      viewAllAction: _parseAction(data['view_all_action']),
    );
  }

  static ProductGridBlock _parseProductGrid({
    required String id,
    required bool enabled,
    required Map<String, dynamic> data,
  }) {
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
    );
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

    return BrandCarouselBlock(
      id: id,
      enabled: enabled,
      presentation: _parsePresentation(data),
      title: _optionalString(data, 'title'),
      items: items.map(_parseBrandItem).toList(growable: false),
      itemWidth: _positiveDouble(data, 'item_width', fallback: 92),
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
        minimum: 1,
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

    if (title == null && content == null) {
      throw const FormatException(
        'Text block must contain a title or content.',
      );
    }

    if (alignment == null) {
      throw FormatException('Unsupported text alignment: $alignmentValue');
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
