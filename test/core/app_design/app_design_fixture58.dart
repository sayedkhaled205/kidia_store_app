import 'dart:convert';

const appDesignOrigin58 = 'https://odoo.example.invalid';

/// Design-only normalized public payload. No cached commerce/customer records.
Map<String, dynamic> appDesignFixture58() => <String, dynamic>{
  'schema_version': 1,
  'platform': 'odoo',
  'store_origin': appDesignOrigin58,
  'identity': <String, dynamic>{
    'app_name': 'Kidia saved design',
    'logo_url': '$appDesignOrigin58/assets/logo.png',
    'language': 'ar',
    'direction': 'rtl',
    'primary_color': '#4EA999',
    'secondary_color': '#256A77',
    'font_family': 'noto_sans_arabic',
  },
  'splash': <String, dynamic>{
    'enabled': true,
    'image_url': '$appDesignOrigin58/assets/splash.png',
    'background_color': '#91AEBB',
    'background_color_end': '#256A77',
    'duration_ms': 1250,
    'image_width': 180,
    'image_height': 150,
    'image_fit': 'contain',
    'image_shape': 'rounded',
    'show_store_name': true,
    'store_name': 'Kidia saved design',
    'text_color': '#FFFFFF',
    'show_loader': false,
    'loader_color': '#4EA999',
  },
  'home': <String, dynamic>{
    'version': 1,
    'page': 'home',
    'locale': 'ar',
    'updated_at': '2026-10-10T12:00:00Z',
    'blocks': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'saved-heading',
        'type': 'text_block',
        'enabled': true,
        'data': <String, dynamic>{
          'title': 'Saved heading',
          'content': 'Saved public brand copy',
          'alignment': 'center',
          'text_color': '#256A77',
          'title_size': 26,
          'presentation': <String, dynamic>{
            'margin_top': 11,
            'padding_horizontal': 17,
            'background_color': '#EAF4F5',
          },
        },
      },
      <String, dynamic>{
        'id': 'saved-products',
        'type': 'product_grid',
        'enabled': true,
        'catalog_query': <String, dynamic>{
          'kind': 'products',
          'mode': 'all',
          'limit': 8,
          'sort': 'name',
        },
        'data': <String, dynamic>{
          'title': 'Store products',
          'items': <dynamic>[],
          'columns': 3,
          'card_style': 'minimal',
          'card_radius': 7,
          'image_ratio': 0.82,
          'show_name': true,
          'show_price': true,
          'show_regular_price': false,
          'show_badge': false,
          'show_rating': false,
          'quick_add_enabled': false,
          'enable_image_swipe': true,
          'content_bottom_padding': 9,
        },
      },
      <String, dynamic>{
        'id': 'saved-categories',
        'type': 'category_grid',
        'enabled': true,
        'catalog_query': <String, dynamic>{
          'kind': 'categories',
          'mode': 'all',
          'limit': 6,
          'sort': 'name',
        },
        'data': <String, dynamic>{
          'title': 'Store departments',
          'items': <dynamic>[],
          'columns': 3,
          'layout': 'grid',
          'image_shape': 'rounded',
          'image_size': 88,
          'show_names': true,
          'label_color': '#256A77',
        },
      },
    ],
  },
  'pages': <String, dynamic>{
    for (final page in const <String>[
      'home',
      'category',
      'catalog',
      'product',
      'size_chart',
      'wishlist',
      'account',
    ])
      page: <String, dynamic>{
        'page': page,
        'enabled': true,
        'settings': <String, dynamic>{
          'page_background_color': '#EAF4F5',
          'content_horizontal_padding': 17,
          'font_family': 'noto_sans_arabic',
        },
        'header': <String, dynamic>{
          'id': 'header',
          'type': 'app_header',
          'enabled': true,
          'settings': <String, dynamic>{
            'height': 91,
            'logo_url': '$appDesignOrigin58/assets/logo.png',
            'background_color': '#EAF4F5',
            'layout_json': jsonEncode(<String, dynamic>{
              'rows': <Map<String, dynamic>>[
                <String, dynamic>{
                  'columns': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'width': 100,
                      'align': 'center',
                      'items': <String>['logo', 'title'],
                    },
                  ],
                },
              ],
            }),
          },
        },
        'elements': <Map<String, dynamic>>[],
        'footer': <String, dynamic>{
          'id': 'footer',
          'type': 'app_footer',
          'enabled': true,
          'settings': <String, dynamic>{
            'height': 74,
            'active_color': '#4EA999',
            'background_color': '#FFFFFF',
            'show_labels': true,
            'layout_json': jsonEncode(<String, dynamic>{
              'rows': <Map<String, dynamic>>[
                <String, dynamic>{
                  'columns': <Map<String, dynamic>>[
                    for (final item in const <String>[
                      'home',
                      'categories',
                      'wishlist',
                      'account',
                    ])
                      <String, dynamic>{
                        'width': 25,
                        'align': 'center',
                        'items': <String>[item],
                      },
                  ],
                },
              ],
            }),
          },
        },
      },
  },
};

String appDesignRawEncoded58(Map<String, dynamic> value) =>
    base64Encode(utf8.encode(jsonEncode(value)));

Map<String, dynamic> appDesignMap58(dynamic value) =>
    value as Map<String, dynamic>;

Map<String, dynamic> appDesignBlock58(
  Map<String, dynamic> fixture,
  String id,
) => (appDesignMap58(fixture['home'])['blocks'] as List)
    .cast<Map<String, dynamic>>()
    .singleWhere((block) => block['id'] == id);
