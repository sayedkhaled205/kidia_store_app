import 'dart:convert';

import '../../features/catalog/domain/repositories/catalog_repository.dart';
import '../../features/home/data/models/home_block_model.dart';
import '../../features/home/data/models/home_layout_model.dart';
import '../../features/home/domain/entities/home_layout.dart';
import '../../features/page_builder/domain/cms_page_layout.dart';
import '../../features/splash/domain/splash_config.dart';
import '../commerce/commerce_connection.dart';
import 'app_design_hydration58.dart';
import 'category_overrides83.dart';

/// Public, caller-supplied *saved normalized* Builder design. Base64 is packaging,
/// not encryption or authentication: no credentials or commerce records belong
/// here. There is deliberately no guessed remote design endpoint or fallback.
class AppDesignBundle58 {
  AppDesignBundle58._(this._json, this.platform, this.storeOrigin);
  static const pages = <String>{
    'home',
    'category',
    'catalog',
    'product',
    'size_chart',
    'wishlist',
    'account',
  };
  static const _maximumBytes = 1024 * 1024;
  final Map<String, dynamic> _json;
  final CommercePlatform platform;
  final Uri storeOrigin;

  Map<String, dynamic> get identity =>
      _json['identity'] as Map<String, dynamic>;
  SplashConfig get splash => SplashConfig.fromJson(_map(_json['splash']));
  CmsPageLayout pageLayout(String page) {
    if (!pages.contains(page)) throw _invalid();
    return CmsPageLayout.fromJson(_map(_map(_json['pages'])[page]));
  }

  Map<String, dynamic> toJson() => _copy(_json);

  factory AppDesignBundle58.fromEncoded(
    String encoded, {
    required CommercePlatform platform,
    required Uri storeOrigin,
  }) {
    if (encoded.isEmpty) {
      throw const FormatException(
        'APP_DESIGN_BUNDLE is required for this platform. Supply a saved public Builder design.',
      );
    }
    try {
      if (encoded.length > _maximumBytes * 2 ||
          encoded.contains(RegExp(r'\s'))) {
        throw _invalid();
      }
      final bytes = base64Decode(encoded);
      if (bytes.length > _maximumBytes) throw _invalid();
      final json = _map(jsonDecode(utf8.decode(bytes)));
      final origin = CommerceConnection(
        platform: platform,
        storeOrigin: storeOrigin,
      ).storeOrigin;
      _keys(json, const {
        'schema_version',
        'platform',
        'store_origin',
        'identity',
        'splash',
        'home',
        'pages',
      }, required: true);
      if (json['schema_version'] is! int ||
          json['schema_version'] != 1 ||
          json['platform'] != _platformName(platform) ||
          json['store_origin'] is! String ||
          CommerceConnection(
                platform: platform,
                storeOrigin: Uri.parse(json['store_origin'] as String),
              ).storeOrigin !=
              origin) {
        throw _invalid();
      }
      _scanPublic(json);
      _validateIdentity(_map(json['identity']));
      _validateSplash(_map(json['splash']));
      _validateHome(_map(json['home']), platform);
      _validatePages(_map(json['pages']), platform);
      return AppDesignBundle58._(_freeze(json), platform, origin);
    } catch (_) {
      // Never place raw JSON, a supplied secret, URL credentials, or parser
      // details in logs/customer error screens.
      throw _invalid();
    }
  }

  Future<HomeLayout> hydrateHome(
    CatalogRepository repository, {
    required String locale,
  }) => hydrateSavedHome58(_map(_json['home']), repository, locale: locale);

  static void _validateIdentity(Map<String, dynamic> value) {
    _keys(value, const {
      'app_name',
      'logo_url',
      'language',
      'direction',
      'primary_color',
      'secondary_color',
      'font_family',
    }, required: true);
    _text(value['app_name'], 240);
    for (final key in ['primary_color', 'secondary_color']) {
      if (value.containsKey(key) &&
          (value[key] is! String ||
              !RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(value[key] as String))) {
        throw _invalid();
      }
    }
    for (final key in ['logo_url', 'language', 'direction', 'font_family']) {
      if (value.containsKey(key) && value[key] is! String) throw _invalid();
    }
    if (value.containsKey('direction') &&
        !{'rtl', 'ltr'}.contains(value['direction'])) {
      throw _invalid();
    }
    if (value.containsKey('language') &&
        !RegExp(
          r'^[a-zA-Z]{2,3}([_-][a-zA-Z]{2})?$',
        ).hasMatch(value['language'] as String)) {
      throw _invalid();
    }
  }

  static void _validateSplash(Map<String, dynamic> value) {
    _keys(value, const {
      'enabled',
      'image_url',
      'background_color',
      'background_color_end',
      'duration_ms',
      'image_width',
      'image_height',
      'image_aspect_ratio',
      'image_fit',
      'image_shape',
      'show_store_name',
      'store_name',
      'text_color',
      'show_loader',
      'loader_color',
    }, required: true);
    if (value.isEmpty) throw _invalid();
    for (final key in ['enabled', 'show_store_name', 'show_loader']) {
      if (value.containsKey(key) && value[key] is! bool) throw _invalid();
    }
    for (final key in [
      'background_color',
      'background_color_end',
      'text_color',
      'loader_color',
    ]) {
      if (value.containsKey(key) &&
          (value[key] is! String ||
              !RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(value[key] as String))) {
        throw _invalid();
      }
    }
    for (final key in ['duration_ms', 'image_width', 'image_height']) {
      if (value.containsKey(key) &&
          (value[key] is! num || !(value[key] as num).isFinite)) {
        throw _invalid();
      }
    }
    if ((value['duration_ms'] as num) < 500 ||
        (value['duration_ms'] as num) > 10000 ||
        (value['image_width'] as num) < 40 ||
        (value['image_width'] as num) > 320 ||
        (value['image_height'] as num) < 40 ||
        (value['image_height'] as num) > 320 ||
        !{'contain', 'cover', 'fill'}.contains(value['image_fit']) ||
        !{'none', 'circle', 'rounded'}.contains(value['image_shape']) ||
        value['image_url'] is! String ||
        value['store_name'] is! String) {
      throw _invalid();
    }
  }

  static void _validateHome(
    Map<String, dynamic> value,
    CommercePlatform platform,
  ) {
    _keys(value, const {
      'version',
      'page',
      'locale',
      'updated_at',
      'blocks',
    }, required: true);
    if (value['version'] is! int ||
        (value['version'] as int) < 1 ||
        value['page'] != 'home' ||
        value['blocks'] is! List) {
      throw _invalid();
    }
    _text(value['locale'], 30);
    _text(value['updated_at'], 80);
    if (DateTime.tryParse(value['updated_at'] as String) == null ||
        (value['blocks'] as List).length > 100) {
      throw _invalid();
    }
    final ids = <String>{};
    for (final raw in value['blocks'] as List) {
      final block = _map(raw);
      _keys(block, const {'id', 'type', 'enabled', 'data', 'catalog_query'});
      _text(block['id'], 120);
      if (!ids.add(block['id'] as String) || block['enabled'] is! bool) {
        throw _invalid();
      }
      final type = block['type'];
      // Brands and bundles need a real platform-specific contract, not saved
      // merchandise records or a silent conversion into "all products".
      if (type == 'brand_carousel' || type == 'bundle_collection') {
        throw _invalid();
      }
      final data = _map(block['data']);
      final catalog = {
        'product_grid',
        'product_carousel',
        'category_grid',
      }.contains(type);
      if (catalog) {
        if (data.containsKey('source') ||
            data.containsKey('product_ids') ||
            data.containsKey('category_ids')) {
          throw _invalid();
        }
        if (data['items'] is! List || (data['items'] as List).isNotEmpty) {
          throw _invalid();
        }
        validateCatalogQuery58(
          _map(block['catalog_query']),
          categories: type == 'category_grid',
        );
        final query = _map(block['catalog_query']);
        if (platform != CommercePlatform.wooCommerce &&
            {
              'featured',
              'on_sale',
              'best_selling',
              'top_rated',
            }.contains(query['mode'])) {
          throw _invalid();
        }
        if (platform == CommercePlatform.shopify &&
            type == 'category_grid' &&
            (query['hide_empty'] == true ||
                (query['mode'] == 'parent' && query['parent_id'] != 0))) {
          // Shopify collections are flat and expose no verified empty counts.
          throw _invalid();
        }
        if (platform == CommercePlatform.shopify &&
            type != 'category_grid' &&
            query['mode'] != 'ids' &&
            (query['limit'] as int) > 20) {
          throw _invalid();
        }
      } else if (block.containsKey('catalog_query')) {
        throw _invalid();
      }
      // Unlike HomeLayoutModel's forward-compatible skip behavior, packaged
      // saved design must validate each block so none silently disappears.
      HomeBlockModel.fromJson(block);
    }
    HomeLayoutModel.fromJson(value);
  }

  static void _validatePages(
    Map<String, dynamic> value,
    CommercePlatform platform,
  ) {
    _keys(value, pages, required: true);
    for (final page in pages) {
      final layout = _map(value[page]);
      _keys(layout, const {
        'page',
        'enabled',
        'settings',
        'header',
        'elements',
        'footer',
      }, required: true);
      if (layout['page'] != page ||
          layout['enabled'] is! bool ||
          layout['elements'] is! List ||
          (layout['elements'] as List).length > 100) {
        throw _invalid();
      }
      final settings = _map(layout['settings']);
      if (page == 'category' && settings.containsKey('category_overrides')) {
        validateSavedCategoryOverrides83(
          _map(settings['category_overrides']),
          allowUnresolvedImages: platform == CommercePlatform.wooCommerce,
        );
      }
      final ids = <String>{};
      for (final raw in [
        layout['header'],
        ...(layout['elements'] as List),
        layout['footer'],
      ]) {
        final component = _map(raw);
        _keys(component, const {
          'id',
          'type',
          'enabled',
          'settings',
        }, required: true);
        _text(component['id'], 120);
        _text(component['type'], 120);
        if (!ids.add(component['id'] as String) ||
            component['enabled'] is! bool) {
          throw _invalid();
        }
        _map(component['settings']);
      }
    }
  }
}

/// Package caller-supplied saved normalized public layouts. Catalog records
/// are removed, and selectors must be supplied explicitly for every catalog
/// block. This function neither discovers nor contacts a Builder/server API.
String encodeSavedAppDesign58({
  required CommercePlatform platform,
  required Uri storeOrigin,
  required Map<String, dynamic> identity,
  required Map<String, dynamic> splash,
  required Map<String, dynamic> home,
  required Map<String, dynamic> pages,
  Map<String, Map<String, dynamic>> catalogQueries = const {},
}) {
  try {
    final savedHome = _copy(home);
    final used = <String>{};
    for (final raw in savedHome['blocks'] as List) {
      final block = raw as Map<String, dynamic>;
      if ({
        'product_grid',
        'product_carousel',
        'category_grid',
      }.contains(block['type'])) {
        final id = block['id'] as String;
        final query = catalogQueries[id] ?? block['catalog_query'];
        if (query == null) throw _invalid();
        (block['data'] as Map<String, dynamic>)['items'] = <dynamic>[];
        block['catalog_query'] = _copy(_map(query));
        used.add(id);
      }
    }
    if (catalogQueries.keys.any((key) => !used.contains(key))) throw _invalid();
    final savedPages = _packageSavedPages58(pages);
    final origin = CommerceConnection(
      platform: platform,
      storeOrigin: storeOrigin,
    ).storeOrigin;
    final encoded = base64Encode(
      utf8.encode(
        jsonEncode({
          'schema_version': 1,
          'platform': _platformName(platform),
          'store_origin': origin.toString(),
          'identity': identity,
          'splash': splash,
          'home': savedHome,
          'pages': savedPages,
        }),
      ),
    );
    AppDesignBundle58.fromEncoded(
      encoded,
      platform: platform,
      storeOrigin: origin,
    );
    return encoded;
  } catch (_) {
    throw _invalid();
  }
}

// Saved page-store/endpoint envelopes include revision, locale and editor-only
// component metadata. Project only those *known* metadata fields away; inspect
// the original first so credentials/commerce records are never silently hidden.
Map<String, dynamic> _packageSavedPages58(Map<String, dynamic> pages) {
  _scanPublic(pages);
  _keys(pages, AppDesignBundle58.pages, required: true);
  const layoutKeys = {
    'page',
    'enabled',
    'settings',
    'header',
    'elements',
    'footer',
  };
  const componentKeys = {'id', 'type', 'enabled', 'settings'};
  Map<String, dynamic> component(Object? raw) {
    final value = _map(raw);
    _keys(value, {...componentKeys, 'label', 'icon', 'locked'});
    for (final key in ['label', 'icon']) {
      if (value.containsKey(key) && value[key] is! String) throw _invalid();
    }
    if (value.containsKey('locked') && value['locked'] is! bool) {
      throw _invalid();
    }
    return {
      for (final key in componentKeys)
        if (value.containsKey(key)) key: value[key],
    };
  }

  return {
    for (final page in AppDesignBundle58.pages)
      page: (() {
        final value = _map(pages[page]);
        _keys(value, {...layoutKeys, 'version', 'updated_at', 'locale'});
        if ((value.containsKey('version') && value['version'] is! int) ||
            (value.containsKey('updated_at') &&
                value['updated_at'] is! String) ||
            (value.containsKey('locale') && value['locale'] is! String) ||
            value['elements'] is! List) {
          throw _invalid();
        }
        return {
          for (final key in layoutKeys)
            if (value.containsKey(key)) key: value[key],
          'header': component(value['header']),
          'elements': [
            for (final raw in value['elements'] as List) component(raw),
          ],
          'footer': component(value['footer']),
        };
      })(),
  };
}

String _platformName(CommercePlatform value) => switch (value) {
  CommercePlatform.wooCommerce => 'woocommerce',
  CommercePlatform.shopify => 'shopify',
  CommercePlatform.odoo => 'odoo',
};

FormatException _invalid() => const FormatException(
  'Invalid APP_DESIGN_BUNDLE: use a public saved design bound to this platform and HTTPS store origin, with explicit supported catalog selectors.',
);

Map<String, dynamic> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw _invalid();
  }
  return Map<String, dynamic>.from(value);
}

void _keys(
  Map<String, dynamic> map,
  Set<String> allowed, {
  bool required = false,
}) {
  if (map.keys.any((key) => !allowed.contains(key)) ||
      (required && allowed.any((key) => !map.containsKey(key)))) {
    throw _invalid();
  }
}

void _text(Object? value, int maximum) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > maximum ||
      value.contains(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'))) {
    throw _invalid();
  }
}

Map<String, dynamic> _copy(Map<String, dynamic> map) =>
    _map(jsonDecode(jsonEncode(map)));

dynamic _freezeValue(dynamic value) => switch (value) {
  Map map => Map<String, dynamic>.unmodifiable({
    for (final entry in map.entries)
      entry.key as String: _freezeValue(entry.value),
  }),
  List list => List<dynamic>.unmodifiable(list.map(_freezeValue)),
  _ => value,
};
Map<String, dynamic> _freeze(Map<String, dynamic> value) =>
    _freezeValue(value) as Map<String, dynamic>;

final _secretKey = RegExp(
  r'password|secret|credential|token|csrf|session|authorization|api_?key|consumer_?key',
  caseSensitive: false,
);
const _recordKeys = {
  'customer',
  'customer_id',
  'customers',
  'customer_data',
  'customer_email',
  'email',
  'account_data',
  'auth',
  'orders',
  'order',
  'order_id',
  'addresses',
  'address',
  'price',
  'prices',
  'price_minor',
  'total_minor',
  'regular_price',
  'sale_price',
  'stock',
  'stock_quantity',
  'in_stock',
  'stock_status',
  'inventory',
  'demo_catalog',
  'products',
  'product_records',
  'categories',
  'payment',
  'payments',
};

void _scanPublic(Object? value, [int depth = 0]) {
  if (depth > 32) throw _invalid();
  if (value is Map) {
    if (value.length > 500) throw _invalid();
    for (final entry in value.entries) {
      if (entry.key is! String) throw _invalid();
      final key = (entry.key as String).toLowerCase();
      if (_secretKey.hasMatch(key) || _recordKeys.contains(key)) {
        throw _invalid();
      }
      if ((key.endsWith('_url') || key.endsWith('_uri')) &&
          entry.value is String &&
          (entry.value as String).isNotEmpty) {
        _assetUrl(entry.value as String);
      }
      if (key.endsWith('_json') && entry.value is String) {
        _scanPublic(jsonDecode(entry.value as String), depth + 1);
      }
      _scanPublic(entry.value, depth + 1);
    }
  } else if (value is List) {
    if (value.length > 500) throw _invalid();
    for (final item in value) {
      _scanPublic(item, depth + 1);
    }
  } else if (value is String) {
    if (value.length > 100000 ||
        value.contains(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]')) ||
        value.contains(
          RegExp(
            r'^(Bearer\s|shpat_|shpca_|shpss_|shpua_|-----BEGIN .*PRIVATE KEY)',
            caseSensitive: false,
          ),
        )) {
      throw _invalid();
    }
    if (RegExp(
      r'^[a-zA-Z][a-zA-Z0-9+.-]*://|^(?:javascript|data|file|vbscript):',
      caseSensitive: false,
    ).hasMatch(value)) {
      _assetUrl(value);
    }
  } else if (value is num) {
    if (!value.isFinite) throw _invalid();
  } else if (value != null && value is! bool) {
    throw _invalid();
  }
}

void _assetUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.queryParameters.keys.any(
        (key) =>
            _secretKey.hasMatch(key) || _recordKeys.contains(key.toLowerCase()),
      )) {
    throw _invalid();
  }
}
