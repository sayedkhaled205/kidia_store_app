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
      'catalog': <String>[
        'page_title',
        'search_bar',
        'filter_bar',
        'product_grid',
        'pagination',
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
      'wishlist': <String>['page_title', 'wishlist_grid', 'empty_state'],
      'account': <String>[
        'account_summary',
        'account_menu',
        'logout_button',
      ],
    };
    return CmsPageLayout(
      page: page,
      header: const CmsPageComponent(
        id: 'header',
        type: 'app_header',
        enabled: true,
        settings: <String, dynamic>{},
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
      footer: const CmsPageComponent(
        id: 'footer',
        type: 'app_footer',
        enabled: true,
        settings: <String, dynamic>{},
      ),
    );
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
