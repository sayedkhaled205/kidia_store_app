import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';

void main() {
  test('parses fixed chrome, ordered page elements and typed settings', () {
    final CmsPageLayout layout = CmsPageLayout.fromJson(
      <String, dynamic>{
        'page': 'catalog',
        'header': <String, dynamic>{
          'id': 'header',
          'type': 'app_header',
          'enabled': true,
          'settings': <String, dynamic>{'height': 70, 'show_cart': '1'},
        },
        'elements': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'product_grid',
            'enabled': true,
            'settings': <String, dynamic>{'columns': '3'},
          },
          <String, dynamic>{'id': 'filter_bar', 'enabled': false},
        ],
        'footer': <String, dynamic>{
          'id': 'footer',
          'type': 'app_footer',
          'enabled': false,
        },
      },
    );

    expect(layout.page, 'catalog');
    expect(layout.header.number('height', 64), 70);
    expect(layout.header.boolean('show_cart', false), isTrue);
    expect(layout.elements.map((CmsPageComponent item) => item.id), <String>[
      'product_grid',
      'filter_bar',
    ]);
    expect(layout.element('product_grid').number('columns', 2), 3);
    expect(layout.element('filter_bar').enabled, isFalse);
    expect(layout.footer.enabled, isFalse);
  });

  test('provides safe page-specific fallbacks when the CMS is unavailable', () {
    expect(
      CmsPageLayout.fallback('product').elements.map(
        (CmsPageComponent item) => item.id,
      ),
      containsAll(<String>['image_gallery', 'purchase_bar', 'reviews']),
    );
    expect(CmsPageLayout.fallback('wishlist').header.enabled, isTrue);
    expect(CmsPageLayout.fallback('account').footer.enabled, isTrue);
	final CmsPageLayout home = CmsPageLayout.fallback('home');
	final dynamic homeRows = home.header.json('layout_json')['rows'];
	expect(homeRows, isA<List<dynamic>>());
	expect((homeRows as List<dynamic>).length, 2);
	expect(home.header.number('search_width_percent', 0), 100);
	expect(home.header.boolean('collapse_on_scroll', false), isTrue);
	expect(home.header.string('collapse_preset', ''), 'sticky_search_cart');
	expect(home.header.string('collapse_transition', ''), 'fade_slide');
	expect(home.header.string('collapse_speed', ''), 'medium');
	final dynamic homeFooterRows = home.footer.json('layout_json')['rows'];
	expect(homeFooterRows, isA<List<dynamic>>());
	expect((homeFooterRows as List<dynamic>).first['columns'], hasLength(4));
	final CmsPageLayout product = CmsPageLayout.fallback('product');
	expect(product.footer.string('style', ''), 'product_action');
	final dynamic productFooterRows = product.footer.json('layout_json')['rows'];
	expect((productFooterRows as List<dynamic>).first['columns'], hasLength(3));
  });
}
