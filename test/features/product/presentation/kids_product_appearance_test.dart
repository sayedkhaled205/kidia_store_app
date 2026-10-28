import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/app/main_shell.dart';
import 'package:mobishop_store_app/features/catalog/presentation/widgets/catalog_product_card.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';
import 'package:mobishop_store_app/features/product/presentation/product_detail_screen.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_access_provider.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_repository_provider.dart';
import 'package:mobishop_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';

import '../support/product_test_data.dart';

final _kids =
    jsonDecode(
          File(
            'tool/builder-assets/kids-appearance-20261027.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
CmsPageLayout _layout(String page) =>
    CmsPageLayout.fromJson({..._kids['pages'][page], 'page': page});

class _Wishlist implements WishlistRepository {
  List<int> ids = [];
  @override
  Future<List<int>> loadProductIds() async => ids;
  @override
  Future<void> saveProductIds(List<int> value) async {
    ids = value;
  }
}

void main() {
  for (final locale in ['en', 'ar']) {
    testWidgets(
      'Kids product matches catalog cards and category footer in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final wishlist = _Wishlist();
        final adding = Completer<void>();
        final repository = ProductFakeCatalogRepository()
          ..relatedProducts = [variableProduct];
        final router = GoRouter(
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (_, _, shell) => MainShell(navigationShell: shell),
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/',
                      builder: (_, _) => const Scaffold(body: Text('Home')),
                    ),
                    GoRoute(
                      path: '/categories',
                      builder: (_, _) =>
                          const Scaffold(body: Text('Categories')),
                    ),
                    GoRoute(
                      path: '/product/:id',
                      builder: (_, _) => ProductDetailScreen(
                        productId: simpleProduct.id,
                        repository: repository,
                        onAddToCart: (_) => adding.future,
                        onWishlistToggle: (_) async => true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          initialLocation: '/categories',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cmsPageLayoutProvider.overrideWith(
                (ref, page) async => _layout(page),
              ),
              wishlistRepositoryProvider.overrideWithValue(wishlist),
              wishlistAccessProvider.overrideWithValue(
                const WishlistAccess(requiresSignIn: false),
              ),
            ],
            child: MaterialApp.router(
              locale: Locale(locale),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final navHeight = tester
            .getSize(find.byKey(const Key('cms-bottom-navigation-size')))
            .height;
        final navIconSize = tester.getSize(
          find.byKey(const Key('cms-bottom-nav-icon-box-home')),
        );
        final navGap = tester
            .getSize(
              find.byKey(const Key('cms-bottom-nav-icon-label-gap-home')),
            )
            .height;
        final navTop = tester
            .getTopLeft(find.byKey(const Key('cms-bottom-navigation-size')))
            .dy;
        router.go('/product/${simpleProduct.id}');
        await tester.pumpAndSettle();
        expect(find.text(locale == 'ar' ? 'مشاركة' : 'Share'), findsOneWidget);
        expect(
          find.text(locale == 'ar' ? 'المفضلة' : 'Wishlist'),
          findsOneWidget,
        );
        expect(
          find.text(locale == 'ar' ? 'أضف إلى السلة' : 'Add to cart'),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byKey(const Key('product-footer-size'))).height,
          closeTo(navHeight, .01),
        );
        expect(
          tester.getTopLeft(find.byKey(const Key('product-footer-size'))).dy,
          // The purchase row moves down 3px inside the same total footer height.
          closeTo(navTop + 3, .01),
        );
        expect(
          tester.getSize(
            find.byKey(const Key('product-footer-icon-box-share')),
          ),
          navIconSize,
        );
        expect(
          tester
              .getSize(
                find.byKey(const Key('product-footer-icon-label-gap-share')),
              )
              .height,
          navGap,
        );
        expect(
          tester
              .getSize(find.byKey(const Key('product-add-to-cart-size')))
              .height,
          closeTo(47 * .97, .01),
        );
        final scrollable = find
            .descendant(
              of: find.byKey(const Key('product-detail-scroll')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byType(CatalogProductCard),
          250,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        final card = find.byType(CatalogProductCard);
        final material = tester.widget<Material>(
          find.descendant(of: card, matching: find.byType(Material)).first,
        );
        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.side.color, const Color(0xffD3EAE6));
        expect(shape.side.width, .5);
        final catalog = _layout('catalog').element('product_grid');
        expect(
          shape.borderRadius,
          BorderRadius.circular(catalog.number('card_radius', 0)),
        );
        final heart = find.byKey(
          Key('product-card-wishlist-${variableProduct.id}'),
        );
        await tester.ensureVisible(heart);
        await tester.tap(heart);
        await tester.pumpAndSettle();
        expect(wishlist.ids, [variableProduct.id]);
        expect(
          find.descendant(
            of: heart,
            matching: find.byIcon(Icons.favorite_rounded),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('add-to-cart-button')));
        await tester.pump();
        expect(
          find.text(locale == 'ar' ? 'جارٍ الإضافة…' : 'Adding…'),
          findsOneWidget,
        );
        adding.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      },
    );
  }

  testWidgets(
    'Kids collapsed search matches category alignment without moving the cart',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scroll = ScrollController();
      Widget page(String name) => ProviderScope(
        child: MaterialApp(
          home: CmsPageScaffold(
            layout: _layout(name),
            defaultTitle: '',
            actions: [
              CmsPageHeaderAction(
                type: 'cart',
                icon: Icons.shopping_bag_outlined,
                tooltip: 'Test cart',
                onPressed: () {},
              ),
            ],
            body: ListView(
              controller: scroll,
              children: const [SizedBox(height: 2200)],
            ),
          ),
        ),
      );
      await tester.pumpWidget(page('category'));
      await tester.pumpAndSettle();
      double alignment() =>
          tester.getCenter(find.text('Search products')).dy -
          tester.getCenter(find.byTooltip('Test cart')).dy;
      final categoryAlignment = alignment();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(page('home'));
      await tester.pumpAndSettle();
      final expandedCart = tester.getRect(find.byTooltip('Test cart'));
      scroll.jumpTo(200);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byTooltip('Test cart')), expandedCart);
      expect(alignment(), closeTo(categoryAlignment, .5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
    },
  );
}
