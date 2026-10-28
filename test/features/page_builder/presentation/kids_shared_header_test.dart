import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';

void main() {
  testWidgets(
    'Kids headers share bag frames and Wishlist title centers on the screen',
    (tester) async {
      final preset = jsonDecode(
        File(
          'tool/builder-assets/kids-appearance-20261027.json',
        ).readAsStringSync(),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in [320.0, 390.0, 430.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        for (final language in ['en', 'ar']) {
          Rect? cartRect, contentRect, headerRect, badgeRect;
          for (final page in ['home', 'category', 'wishlist']) {
            final layout = CmsPageLayout.fromJson({
              ...Map<String, dynamic>.from(preset['pages'][page]),
              'page': page,
            });
            var taps = 0;
            await tester.pumpWidget(
              ProviderScope(
                overrides: [cartBadgeCountProvider.overrideWithValue(2)],
                child: MaterialApp(
                  locale: Locale(language),
                  supportedLocales: const [Locale('en'), Locale('ar')],
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 844),
                      padding: const EdgeInsets.only(top: 24, bottom: 24),
                      textScaler: const TextScaler.linear(1.3),
                    ),
                    child: Scaffold(
                      appBar: CmsPageAppBar(
                        layout: layout,
                        defaultTitle: language == 'ar' ? 'المفضلة' : 'Wishlist',
                        compact: page == 'home',
                        actions: [
                          CmsPageHeaderAction(
                            type: 'cart',
                            icon: Icons.shopping_bag_outlined,
                            tooltip: 'Bag',
                            onPressed: () => taps++,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final cart = tester.getRect(find.byTooltip('Bag'));
            final content = tester.getRect(
              find.byKey(const Key('cms-page-morphing-search')),
            );
            final header = tester.getRect(find.byType(CmsPageAppBar));
            final badge = tester.getRect(
              find.byKey(const Key('cms-cart-count-badge')),
            );
            if (cartRect != null) {
              expect(cart, cartRect, reason: '$page $language $width');
              if (page != 'wishlist') expect(content, contentRect);
              expect(header, headerRect);
              expect(badge, badgeRect);
            }
            cartRect = cart;
            contentRect = content;
            headerRect = header;
            badgeRect = badge;
            expect(cart.width, greaterThanOrEqualTo(48));
            await tester.tap(find.byTooltip('Bag'));
            expect(taps, 1);
            if (page == 'wishlist') {
              final title = tester.getRect(
                find.byKey(const Key('commerce-app-bar-title')),
              );
              expect(title.center.dx, closeTo(width / 2, .01));
              expect(content.center.dx, closeTo(width / 2, .01));
              expect(
                find.byKey(const Key('commerce-app-bar-title')),
                findsOneWidget,
              );
              expect(
                find.text(
                  language == 'ar' ? 'ابحث عن المنتجات' : 'Search products',
                ),
                findsNothing,
              );
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
    },
  );
}
