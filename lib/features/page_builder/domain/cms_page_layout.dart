import 'dart:convert';

class CmsPageLayout {
  const CmsPageLayout({
    required this.page,
    required this.header,
    required this.elements,
    required this.footer,
  });

  final String page;
  final CmsPageComponent header;
  final List<CmsPageComponent> elements;
  final CmsPageComponent footer;

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
        'image_gallery',
        'product_summary',
        'variations',
        'purchase_bar',
        'description',
        'reviews',
        'related_products',
      ],
      'wishlist': <String>['wishlist_grid', 'empty_state'],
      'account': <String>[
        'account_summary',
        'account_menu',
        'logout_button',
      ],
    };
	final Map<String, dynamic> headerSettings = <String, dynamic>{
		'layout_json': jsonEncode(_fallbackHeaderLayout(page)),
		'height': page == 'home' ? 112 : 64,
		'margin_top': 0,
		'margin_bottom': 0,
		'row_gap': page == 'home' ? 4 : 8,
		'vertical_padding': 8,
		'horizontal_padding': 16,
		'background_color': '#FFFFFF',
		'icon_color': '#1F2933',
		'icon_size': 24,
		'icon_gap': 6,
		'search_style': page == 'home' ? 'bar' : 'icon',
		'search_width_percent': 100,
		'search_height': 40,
		'search_radius': page == 'home' ? 18 : 14,
		'show_cart_badge': false,
	};
	final Map<String, dynamic> footerSettings = <String, dynamic>{
		'layout_json': jsonEncode(_fallbackFooterLayout(page)),
		'style': page == 'product' ? 'product_action' : 'navigation',
		'height': page == 'product' ? 84 : 76,
		'margin_top': 0,
		'margin_bottom': 0,
		'side_spacing_percent': 0,
		'icon_size': 24,
		'label_size': 11,
		'icon_label_gap': 3,
		'show_labels': true,
		'active_color': '#1F6F61',
		'inactive_color': '#6B7280',
		'background_color': '#FFFFFF',
		'button_color': '#2F806E',
	};
    return CmsPageLayout(
      page: page,
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
              settings: const <String, dynamic>{},
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

	static Map<String, dynamic> _fallbackHeaderLayout(String page) {
		Map<String, dynamic> column(double width, List<String> items, [String align = 'center']) => <String, dynamic>{'width': width, 'align': align, 'items': items};
		Map<String, dynamic> row(List<Map<String, dynamic>> columns) => <String, dynamic>{'columns': columns};
		final Map<String, Map<String, dynamic>> layouts = <String, Map<String, dynamic>>{
			'home': <String, dynamic>{'rows': <Map<String, dynamic>>[row(<Map<String, dynamic>>[column(33.33, <String>['logo'], 'left'), column(33.34, <String>[]), column(33.33, <String>['cart'], 'right')]), row(<Map<String, dynamic>>[column(100, <String>['search_bar'])])]},
			'catalog': <String, dynamic>{'rows': <Map<String, dynamic>>[row(<Map<String, dynamic>>[column(33.33, <String>['cart', 'search'], 'left'), column(33.34, <String>['title']), column(33.33, <String>['back'], 'right')])]},
			'product': <String, dynamic>{'rows': <Map<String, dynamic>>[row(<Map<String, dynamic>>[column(33.33, <String>['back'], 'left'), column(33.34, <String>[]), column(33.33, <String>['support', 'cart'], 'right')])]},
			'category': <String, dynamic>{'rows': <Map<String, dynamic>>[row(<Map<String, dynamic>>[column(33.33, <String>['search', 'cart'], 'left'), column(33.34, <String>['title']), column(33.33, <String>[], 'right')])]},
			'wishlist': <String, dynamic>{'rows': <Map<String, dynamic>>[row(<Map<String, dynamic>>[column(33.33, <String>['back'], 'left'), column(33.34, <String>['title']), column(33.33, <String>['cart'], 'right')])]},
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
