import 'dart:convert';

class CmsPageLayout {
  const CmsPageLayout({
    required this.page,
    required this.header,
    required this.elements,
    required this.footer,
    this.settings = const <String, dynamic>{},
  });

  final String page;
  final CmsPageComponent header;
  final List<CmsPageComponent> elements;
  final CmsPageComponent footer;
  final Map<String, dynamic> settings;

  String string(String key, String fallback) =>
      _string(settings[key], fallback: fallback);

  CmsPageComponent element(String id) {
    return elements.firstWhere(
      (CmsPageComponent element) => element.id == id,
      orElse: () => CmsPageComponent(
        id: id,
        type: id,
        enabled: true,
        settings: const <String, dynamic>{},
      ),
    );
  }

  factory CmsPageLayout.fromJson(Map<String, dynamic> json) {
    final dynamic rawElements = json['elements'];
    return CmsPageLayout(
      page: _string(json['page'], fallback: 'catalog'),
      settings: _map(json['settings']),
      header: CmsPageComponent.fromJson(
        _map(json['header']),
        fallbackId: 'header',
      ),
      elements: rawElements is List
          ? rawElements
                .whereType<Map>()
                .map(
                  (Map<dynamic, dynamic> value) => CmsPageComponent.fromJson(
                    Map<String, dynamic>.from(value),
                  ),
                )
                .toList(growable: false)
          : const <CmsPageComponent>[],
      footer: CmsPageComponent.fromJson(
        _map(json['footer']),
        fallbackId: 'footer',
      ),
    );
  }

  factory CmsPageLayout.fallback(String page) {
    const Map<String, List<String>> ids = <String, List<String>>{
      'home': <String>[],
      'category': <String>[],
      'catalog': <String>[
        'filter_bar',
        'product_grid',
      ],
      'product': <String>[
		'product_tabs',
        'image_gallery',
        'product_summary',
        'variations',
        'purchase_bar',
        'description',
        'reviews',
        'related_products',
      ],
      'wishlist': <String>[
        'sign_in_state',
        'sign_in_recommendations',
        'empty_state',
        'empty_recommendations',
        'wishlist_grid',
        'products_recommendations',
      ],
      'account': <String>[
        'account_summary',
        'account_menu',
        'logout_button',
      ],
    };
	final Map<String, dynamic> headerSettings = <String, dynamic>{
		'layout_json': jsonEncode(_fallbackHeaderLayout(page)),
		'compact_layout_json': jsonEncode(<String, dynamic>{'rows': <Map<String, dynamic>>[<String, dynamic>{'columns': <Map<String, dynamic>>[<String, dynamic>{'width': 84, 'align': 'left', 'items': <String>['search_bar']}, <String, dynamic>{'width': 16, 'align': 'right', 'items': <String>['cart']}]}]}),
		'collapse_on_scroll': page == 'home',
		'collapse_transition': page == 'home' ? 'smooth_compact' : 'fade_slide',
		'collapse_speed': 'medium',
		'compact_height': 60,
		'compact_style': 'standard',
		'compact_background_color': '#FFFFFF',
		'compact_horizontal_padding': 16,
		'compact_side_margin': 0,
		'compact_radius': 0,
		'compact_border_width': 0,
		'compact_border_color': '#E2E6E4',
		'compact_shadow': 'subtle',
		'height': page == 'home' ? 120 : page == 'wishlist' ? 76 : 64,
		'margin_top': 0,
		'margin_bottom': 0,
		'row_gap': 8,
		'header_position': 'center',
		'row_1_height': 48,
		'row_1_position': 'center',
		'row_2_height': 48,
		'row_2_position': 'center',
		'row_merge': 0,
		'vertical_padding': 8,
		'horizontal_padding': 16,
		'background_color': '#FFFFFF',
		'icon_color': '#1F2933',
		'icon_size': 24,
		'icon_gap': 6,
		'title_font_size': 18,
		'title_font_weight': page == 'wishlist' ? '600' : '700',
		'title_alignment': 'center',
		'title_max_width_percent': 100,
		'title_letter_spacing': 0,
		'title_line_height': 1.2,
		'title_offset_x': 0,
		'title_offset_y': 0,
		'title_transform': 'none',
		'logo_text': 'Kidia',
		'logo_text_color': '#1F2933',
		'logo_width': page == 'home' ? 132 : 118,
		'logo_height': page == 'home' ? 42 : 38,
		'logo_offset_x': 0,
		'logo_offset_y': 0,
		'search_icon_offset_x': 0,
		'search_icon_offset_y': 0,
		'search_bar_offset_x': 0,
		'search_bar_offset_y': 0,
		'back_offset_x': 0,
		'back_offset_y': 0,
		'cart_offset_x': 0,
		'cart_offset_y': 0,
		'wishlist_offset_x': 0,
		'wishlist_offset_y': 0,
		'account_offset_x': 0,
		'account_offset_y': 0,
		'orders_offset_x': 0,
		'orders_offset_y': 0,
		'support_offset_x': 0,
		'support_offset_y': 0,
		'menu_offset_x': 0,
		'menu_offset_y': 0,
		'search_style': page == 'home' ? 'bar' : 'icon',
		'search_width_percent': 100,
		'search_height': page == 'home' ? 44 : 40,
		'search_radius': page == 'home' ? 22 : 14,
		'show_cart_badge': page == 'wishlist',
		'cart_badge_shape': 'circle',
		'cart_badge_size': 18,
		'cart_badge_background': '#E94B5F',
		'cart_badge_text_color': '#FFFFFF',
	};
	final Map<String, dynamic> footerSettings = <String, dynamic>{
		'layout_json': jsonEncode(_fallbackFooterLayout(page)),
		'style': page == 'product' ? 'product_action' : 'navigation',
		'height': page == 'product' ? 84 : 64,
		'margin_top': 0,
		'margin_bottom': 0,
		'space_up': 0,
		'space_down': 0,
		'horizontal_padding': 0,
		'side_spacing_percent': 0,
		'icon_size': 24,
		'label_size': 11,
		'icon_label_gap': 3,
		'show_labels': true,
		'active_color': '#1F6F61',
		'inactive_color': '#6B7280',
		'background_color': '#FFFFFF',
		'hide_on_scroll': false,
		'button_color': page == 'product' ? '#1D1D1D' : '#2F806E',
		'button_text_color': '#FFFFFF',
		'button_width_percent': page == 'product' ? 62 : 58,
		'button_height': page == 'product' ? 56 : 52,
		'button_style': 'filled',
		'button_shape': 'custom',
		'button_radius': 28,
		'button_border_color': '#1F2933',
		'button_border_width': 0,
		'add_to_cart_label': page == 'product' ? 'Add to bag' : 'Add to cart',
		'share_label': 'Share',
		'like_label': 'Like',
	};
    return CmsPageLayout(
      page: page,
      settings: <String, dynamic>{
        'page_background_color': '#FFFFFF',
        if (page == 'wishlist') ...<String, dynamic>{
          'wishlist_access_mode': 'sign_in_required',
          'wishlist_preview_state': 'products',
        },
      },
	  header: CmsPageComponent(
        id: 'header',
        type: 'app_header',
        enabled: true,
		settings: headerSettings,
      ),
      elements: (ids[page] ?? const <String>[])
          .map(
            (String id) => CmsPageComponent(
              id: id,
              type: id,
              enabled: true,
			  settings: page == 'product'
			      ? _fallbackProductSettings(id)
			      : page == 'wishlist'
			      ? _fallbackWishlistSettings(id)
			      : const <String, dynamic>{'background_color': '#FFFFFF'},
            ),
          )
          .toList(growable: false),
	  footer: CmsPageComponent(
        id: 'footer',
        type: 'app_footer',
        enabled: true,
		settings: footerSettings,
      ),
    );
  }

	static Map<String, dynamic> _fallbackProductSettings(String id) {
		const Map<String, Map<String, dynamic>> settings = <String, Map<String, dynamic>>{
			'product_tabs': <String, dynamic>{'sticky': true, 'tabs_json': '[{"label":"Overview","target":"overview","enabled":true},{"label":"Reviews","target":"reviews","enabled":true},{"label":"Recommend","target":"recommend","enabled":true}]', 'active_color': '#1D1D1D', 'inactive_color': '#6B6B6B', 'indicator_width': 96, 'height': 64},
			'image_gallery': <String, dynamic>{'aspect_ratio': .75, 'fit': 'contain', 'background_color': '#FFFFFF', 'show_thumbnails': false, 'show_indicators': false, 'show_counter': true, 'counter_background': '#8A8585', 'counter_text_color': '#FFFFFF', 'enable_zoom': false},
			'product_summary': <String, dynamic>{'show_name': true, 'show_price': true, 'show_regular_price': true, 'show_rating': true, 'show_review_count': true, 'show_sku': false, 'show_stock': false, 'show_badge': false, 'show_selected_color': true, 'price_size': 25, 'name_size': 18},
			'variations': <String, dynamic>{'style': 'chips', 'show_size_chart': true, 'size_chart_label': 'Size chart', 'chip_radius': 22, 'chip_height': 38},
			'purchase_bar': <String, dynamic>{'show_quantity': false},
			'description': <String, dynamic>{'accordion': true, 'details_label': 'Product Details', 'show_description': true, 'show_attributes': true},
			'reviews': <String, dynamic>{'title': 'Reviews', 'show_summary': true, 'show_fit_summary': true, 'fit_small_percent': 1, 'fit_true_percent': 99, 'fit_large_percent': 0},
			'related_products': <String, dynamic>{'title': 'You may also like', 'columns': 2, 'gap': 2, 'image_ratio': .75, 'enable_image_swipe': false, 'show_price': true, 'show_quick_add': true},
		};
		return settings[id] ?? const <String, dynamic>{'background_color': '#FFFFFF'};
	}

	static Map<String, dynamic> _fallbackWishlistSettings(String id) {
		const Map<String, dynamic> messageBase = <String, dynamic>{
			'illustration_url': '',
			'illustration_size': 104,
			'top_spacing': 56,
			'title_size': 18,
			'title_weight': '700',
			'description_size': 14,
			'content_gap': 16,
			'show_button': true,
			'button_width': 220,
			'button_height': 52,
			'button_radius': 26,
			'button_style': 'outline',
			'button_color': '#FFFFFF',
			'button_text_color': '#1D1D1D',
			'button_border_color': '#1D1D1D',
			'button_border_width': 1.5,
			'bottom_spacing': 96,
			'background_color': '#FFFFFF',
		};
		const Map<String, dynamic> recommendations = <String, dynamic>{
			'title': 'You may also like',
			'title_size': 20,
			'title_weight': '700',
			'columns': 2,
			'gap': 8,
			'image_ratio': .82,
			'enable_image_swipe': false,
			'limit': 4,
			'show_name': false,
			'show_price': true,
			'show_quick_add': true,
			'section_padding': 16,
			'title_bottom_spacing': 18,
			'background_color': '#FFFFFF',
		};
		if (id == 'sign_in_state') {
			return <String, dynamic>{
				...messageBase,
				'title': 'Sign in to view your wishlist',
				'description': '',
				'show_description': false,
				'button_label': 'Sign In',
				'button_action': 'sign_in',
			};
		}
		if (id == 'empty_state') {
			return <String, dynamic>{
				...messageBase,
				'title': 'Your wishlist is empty',
				'description': 'Add items here by clicking the little heart!',
				'show_description': true,
				'button_label': 'Go Shopping',
				'button_action': 'shopping',
			};
		}
		if (id.endsWith('_recommendations')) return recommendations;
		if (id == 'wishlist_grid') {
			return const <String, dynamic>{
				'columns': 2,
				'gap': 8,
				'card_style': 'minimal',
				'card_radius': 0,
				'image_ratio': .82,
				'enable_image_swipe': false,
				'show_price': true,
				'show_regular_price': false,
				'show_rating': false,
				'show_badge': false,
				'quick_add_enabled': true,
				'background_color': '#FFFFFF',
			};
		}
		return const <String, dynamic>{'background_color': '#FFFFFF'};
	}

	static Map<String, dynamic> _fallbackHeaderLayout(String page) {
		Map<String, dynamic> column(double width, List<String> items, [String align = 'center']) => <String, dynamic>{'width': width, 'align': align, 'items': items};
		Map<String, dynamic> row(List<Map<String, dynamic>> columns) => <String, dynamic>{'columns': columns};
		final Map<String, Map<String, dynamic>> layouts = <String, Map<String, dynamic>>{
			'home': <String, dynamic>{'rows': <Map<String, dynamic>>[row(<Map<String, dynamic>>[column(33.33, <String>['logo'], 'left'), column(33.34, <String>[]), column(33.33, <String>['cart'], 'right')]), row(<Map<String, dynamic>>[column(100, <String>['search_bar'])])]},
			'catalog': <String, dynamic>{'rows': <Map<String, dynamic>>[row(<Map<String, dynamic>>[column(33.33, <String>['cart', 'search'], 'left'), column(33.34, <String>['title']), column(33.33, <String>['back'], 'right')])]},
			'product': <String, dynamic>{'rows': <Map<String, dynamic>>[row(<Map<String, dynamic>>[column(33.33, <String>['back'], 'left'), column(33.34, <String>[]), column(33.33, <String>['support', 'cart'], 'right')])]},
			'category': <String, dynamic>{'rows': <Map<String, dynamic>>[row(<Map<String, dynamic>>[column(33.33, <String>['search', 'cart'], 'left'), column(33.34, <String>['title']), column(33.33, <String>[], 'right')])]},
			'wishlist': <String, dynamic>{'rows': <Map<String, dynamic>>[row(<Map<String, dynamic>>[column(33.33, <String>[], 'left'), column(33.34, <String>['title']), column(33.33, <String>['cart'], 'right')])]},
			'account': <String, dynamic>{'rows': <Map<String, dynamic>>[row(<Map<String, dynamic>>[column(33.33, <String>[], 'left'), column(33.34, <String>['title']), column(33.33, <String>['orders'], 'right')])]},
		};
		return layouts[page] ?? layouts['catalog']!;
	}

	static Map<String, dynamic> _fallbackFooterLayout(String page) {
		final List<String> items = page == 'product' ? <String>['share', 'like', 'add_to_cart'] : <String>['home', 'categories', 'wishlist', 'account'];
		final double width = 100 / items.length;
		return <String, dynamic>{'rows': <Map<String, dynamic>>[<String, dynamic>{'columns': items.indexed.map((entry) => <String, dynamic>{'width': entry.$1 == items.length - 1 ? 100 - width * (items.length - 1) : width, 'align': 'center', 'items': <String>[entry.$2]}).toList()}]};
	}
}

class CmsPageComponent {
  const CmsPageComponent({
    required this.id,
    required this.type,
    required this.enabled,
    required this.settings,
  });

  final String id;
  final String type;
  final bool enabled;
  final Map<String, dynamic> settings;

  factory CmsPageComponent.fromJson(
    Map<String, dynamic> json, {
    String fallbackId = '',
  }) {
    final String id = _string(json['id'], fallback: fallbackId);
    return CmsPageComponent(
      id: id,
      type: _string(json['type'], fallback: id),
      enabled: _boolean(json['enabled'], fallback: true),
      settings: _map(json['settings']),
    );
  }

  String string(String key, String fallback) =>
      _string(settings[key], fallback: fallback);

  bool boolean(String key, bool fallback) =>
      _boolean(settings[key], fallback: fallback);

  double number(String key, double fallback) {
    final dynamic value = settings[key];
    return value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
  }

  Map<String, dynamic> json(String key) {
	final dynamic value = settings[key];
	if (value is Map) return Map<String, dynamic>.from(value);
	if (value is String && value.isNotEmpty) {
		try { final dynamic decoded = jsonDecode(value); if (decoded is Map) return Map<String, dynamic>.from(decoded); } catch (_) {}
	}
	return <String, dynamic>{};
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

String _string(dynamic value, {required String fallback}) {
  final String normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

bool _boolean(dynamic value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    if (const <String>{'1', 'true', 'yes', 'on'}.contains(value.toLowerCase())) {
      return true;
    }
    if (const <String>{'0', 'false', 'no', 'off', ''}.contains(value.toLowerCase())) {
      return false;
    }
  }
  return fallback;
}
