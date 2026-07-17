import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/home/data/models/home_block_model.dart';
import 'package:kidia_store_app/features/home/data/models/home_layout_model.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';

void main() {
  group('HomeLayoutModel', () {
    test('parses a valid CMS block', () {
      final layout = HomeLayoutModel.fromJson(<String, dynamic>{
        'version': 4,
        'page': 'home',
        'locale': 'en',
        'updated_at': '2026-07-15T20:00:00Z',
        'blocks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'spacer-1',
            'type': 'spacer',
            'enabled': true,
            'data': <String, dynamic>{'height': 24},
          },
        ],
      });

      expect(layout.blocks, hasLength(1));
      expect(layout.blocks.single, isA<SpacerBlock>());
      expect((layout.blocks.single as SpacerBlock).height, 24);
    });

    test('parses the app header and shared responsive presentation', () {
      final AppHeaderBlock header =
          HomeBlockModel.fromJson(<String, dynamic>{
                'id': 'header-1',
                'type': 'app_header',
                'enabled': true,
                'data': <String, dynamic>{
                  'logo_url': 'https://example.com/logo.png',
                  'title': 'Kidia',
                  'subtitle': 'Kids fashion',
                  'layout': 'center',
                  'height': 72,
                  'logo_height': 42,
                  'show_search': true,
                  'show_cart': true,
                  'show_account': true,
                  'title_color': '#123456',
                  'icon_color': '#654321',
                  'presentation': <String, dynamic>{
                    'margin_top': 8,
                    'margin_bottom': 12,
                    'margin_horizontal': 10,
                    'padding_vertical': 6,
                    'padding_horizontal': 14,
                    'background_color': '#FAFAFA',
                    'block_radius': 18,
                    'content_scale': 110,
                  },
                },
              })
              as AppHeaderBlock;

      expect(header.title, 'Kidia');
      expect(header.logoHeight, 42);
      expect(header.showAccount, isTrue);
      expect(header.presentation.marginHorizontal, 10);
      expect(header.presentation.paddingHorizontal, 14);
      expect(header.presentation.backgroundColor, '#fafafa');
      expect(header.presentation.borderRadius, 18);
      expect(header.presentation.contentScale, 1.1);
    });

    test('skips an unsupported block without breaking valid blocks', () {
      final layout = HomeLayoutModel.fromJson(<String, dynamic>{
        'version': 4,
        'page': 'home',
        'locale': 'en',
        'updated_at': '2026-07-15T20:00:00Z',
        'blocks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'future-1',
            'type': 'future_block',
            'enabled': true,
            'data': <String, dynamic>{},
          },
          <String, dynamic>{
            'id': 'spacer-1',
            'type': 'spacer',
            'enabled': true,
            'data': <String, dynamic>{'height': 16},
          },
        ],
      });

      expect(layout.blocks, hasLength(1));
      expect(layout.blocks.single.id, 'spacer-1');
    });

    test('rejects an invalid layout envelope', () {
      expect(
        () => HomeLayoutModel.fromJson(<String, dynamic>{
          'version': 0,
          'page': 'home',
          'locale': 'en',
          'updated_at': 'not-a-date',
          'blocks': <dynamic>[],
        }),
        throwsFormatException,
      );
    });

    test('isolates malformed known blocks without losing the page', () {
      final layout = HomeLayoutModel.fromJson(<String, dynamic>{
        'version': 4,
        'page': 'home',
        'locale': 'en',
        'updated_at': '2026-07-15T20:00:00Z',
        'blocks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'hero-1',
            'type': 'hero_slider',
            'enabled': true,
            'data': <String, dynamic>{'items': <dynamic>[]},
          },
          <String, dynamic>{
            'id': 'spacer-1',
            'type': 'spacer',
            'enabled': true,
            'data': <String, dynamic>{'height': 20},
          },
        ],
      });

      expect(layout.blocks, hasLength(1));
      expect(layout.blocks.single, isA<SpacerBlock>());
    });

    test('parses every extended CMS block with typed data', () {
      final layout = HomeLayoutModel.fromJson(<String, dynamic>{
        'version': 4,
        'page': 'home',
        'locale': 'ar',
        'updated_at': '2026-07-15T20:00:00Z',
        'blocks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'promo-1',
            'type': 'promo_strip',
            'enabled': true,
            'data': <String, dynamic>{
              'text': 'شحن مجاني',
              'background_color': '#123456',
              'text_color': '#fff',
              'action': <String, dynamic>{
                'type': 'collection',
                'value': 'summer',
              },
            },
          },
          <String, dynamic>{
            'id': 'coupon-1',
            'type': 'coupon_banner',
            'enabled': true,
            'data': <String, dynamic>{
              'title': 'خصم 20%',
              'description': 'لمدة محدودة',
              'coupon_code': 'KIDIA20',
              'image_url': 'https://example.com/coupon.jpg',
            },
          },
          <String, dynamic>{
            'id': 'countdown-1',
            'type': 'countdown',
            'enabled': true,
            'data': <String, dynamic>{
              'title': 'العرض ينتهي خلال',
              'ends_at': '2026-07-20T18:00:00+02:00',
              'expired_text': 'انتهى العرض',
            },
          },
          <String, dynamic>{
            'id': 'video-1',
            'type': 'video_banner',
            'enabled': true,
            'data': <String, dynamic>{
              'video_url': 'https://example.com/lookbook.mp4',
              'poster_url': 'https://example.com/lookbook.jpg',
              'aspect_ratio': 1.9,
              'auto_play': false,
              'muted': true,
              'loop': true,
              'action': null,
            },
          },
          <String, dynamic>{
            'id': 'text-1',
            'type': 'text_block',
            'enabled': true,
            'data': <String, dynamic>{
              'title': 'إطلالتك تبدأ هنا',
              'content': 'تسوقي أحدث الصيحات.',
              'alignment': 'right',
              'background': '#fafafa',
              'text_color': '#111111',
            },
          },
          <String, dynamic>{
            'id': 'divider-1',
            'type': 'divider',
            'enabled': true,
            'data': <String, dynamic>{
              'color': '#e5e7eb',
              'thickness': 2,
              'margin': 20,
            },
          },
        ],
      });

      expect(layout.blocks, hasLength(6));

      final PromoStripBlock promo = layout.blocks[0] as PromoStripBlock;
      expect(promo.backgroundColor, '#123456');
      expect(promo.textColor, '#fff');
      expect(promo.action?.value, 'summer');

      final CouponBannerBlock coupon = layout.blocks[1] as CouponBannerBlock;
      expect(coupon.couponCode, 'KIDIA20');

      final CountdownBlock countdown = layout.blocks[2] as CountdownBlock;
      expect(countdown.endsAt, DateTime.parse('2026-07-20T16:00:00Z'));

      final VideoBannerBlock video = layout.blocks[3] as VideoBannerBlock;
      expect(video.aspectRatio, 1.9);
      expect(video.loop, isTrue);

      final TextBlock text = layout.blocks[4] as TextBlock;
      expect(text.alignment, HomeTextAlignment.right);
      expect(text.backgroundColor, '#fafafa');

      final DividerBlock divider = layout.blocks[5] as DividerBlock;
      expect(divider.thickness, 2);
      expect(divider.margin, 20);
    });

    test('accepts an unset countdown date as an expired state', () {
      final CountdownBlock block =
          HomeBlockModel.fromJson(<String, dynamic>{
                'id': 'countdown-1',
                'type': 'countdown',
                'enabled': true,
                'data': <String, dynamic>{
                  'title': '',
                  'ends_at': '',
                  'expired_text': '',
                },
              })
              as CountdownBlock;

      expect(block.endsAt, isNull);
      expect(block.expiredText, 'Offer ended');
    });

    test('parses resolved WooCommerce category, product and brand items', () {
      final layout = HomeLayoutModel.fromJson(<String, dynamic>{
        'version': 4,
        'page': 'home',
        'locale': 'en',
        'updated_at': '2026-07-15T20:00:00Z',
        'blocks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'categories-1',
            'type': 'category_grid',
            'enabled': true,
            'data': <String, dynamic>{
              'title': 'Shop categories',
              'subtitle': 'Find your edit',
              'columns': 4,
              'show_names': true,
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 10,
                  'name': 'Dresses',
                  'image_url': 'https://example.com/dresses.jpg',
                  'action': <String, dynamic>{
                    'type': 'category',
                    'value': '10',
                  },
                },
              ],
            },
          },
          <String, dynamic>{
            'id': 'products-1',
            'type': 'product_grid',
            'enabled': true,
            'data': <String, dynamic>{
              'title': 'New in',
              'subtitle': 'Just landed',
              'columns': 2,
              'show_view_all': true,
              'view_all_label': 'View all',
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 22,
                  'name': 'Linen dress',
                  'image_url': 'https://example.com/product.jpg',
                  'price': '1250.00',
                  'regular_price': '1500.00',
                  'currency_code': 'EGP',
                  'currency_symbol': 'EGP',
                  'in_stock': true,
                  'action': <String, dynamic>{'type': 'product', 'value': '22'},
                },
              ],
            },
          },
          <String, dynamic>{
            'id': 'brands-1',
            'type': 'brand_carousel',
            'enabled': true,
            'data': <String, dynamic>{
              'title': 'Brands',
              'item_width': 92,
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 8,
                  'name': 'Example',
                  'logo_url': 'https://example.com/logo.png',
                  'action': <String, dynamic>{'type': 'brand', 'value': '8'},
                },
              ],
            },
          },
        ],
      });

      expect(layout.blocks, hasLength(3));
      final categories = layout.blocks[0] as CategoryGridBlock;
      final products = layout.blocks[1] as ProductGridBlock;
      final brands = layout.blocks[2] as BrandCarouselBlock;
      expect(categories.items.single.action?.value, '10');
      expect(products.items.single.price, '1250.00');
      expect(products.viewAllLabel, 'View all');
      expect(brands.items.single.action?.type, 'brand');
    });

    test('rejects invalid CMS colors before rendering', () {
      expect(
        () => HomeBlockModel.fromJson(<String, dynamic>{
          'id': 'promo-1',
          'type': 'promo_strip',
          'enabled': true,
          'data': <String, dynamic>{
            'text': 'Sale',
            'background_color': 'red',
            'text_color': '#fff',
          },
        }),
        throwsFormatException,
      );
    });
  });
}
