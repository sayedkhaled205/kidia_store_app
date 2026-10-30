import '../../../support/viewport_rotation.dart';
import 'package:flutter/material.dart';
import 'package:mobishop_store_app/features/catalog/presentation/widgets/catalog_product_card.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/wishlist/presentation/wishlist_screen.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';

import '../support/wishlist_test_data.dart';

void main() {
  viewportRotationTests('Wishlist', (tester,size) => tester.pumpWidget(_testApp(WishlistScreen(repository:FakeWishlistRepository(),catalogRepository:FakeWishlistCatalogRepository()))));
  test('recommendations preserve every supported disabled quick-add value', () {
    final base = CmsPageLayout.fallback('wishlist');
    for (final disabled in <Object>[false, 0, '0', 'false']) {
      final layout = CmsPageLayout(
        page: base.page,
        header: base.header,
        footer: base.footer,
        elements: [CmsPageComponent(id: 'grid', type: 'wishlist_grid', enabled: true,
          settings: {'quick_add_enabled': disabled})],
      );
      final result = wishlistRecommendationAppearance(
        const CmsPageComponent(id: 'recommendations', type: 'empty_recommendations',
          enabled: true, settings: {}), layout);
      expect(result.boolean('quick_add_enabled', true), isFalse);
    }
  });
  testWidgets(
    'wishlist recommendations use the saved card appearance and light outline',
    (tester) async {
      final base = CmsPageLayout.fallback('wishlist');
      final layout = CmsPageLayout(
        page: base.page,
        header: base.header,
        footer: base.footer,
        elements: base.elements
            .map(
              (e) => CmsPageComponent(
                id: e.id,
                type: e.type,
                enabled: e.enabled,
                settings: {
                  ...e.settings,
                  if (e.type == 'wishlist_grid') ...{
                    'card_style': 'outlined',
                    'card_outline_color': '#D3EAE6',
                    'card_outline_width': .5,
                    'card_background_color': '#FAF1E1',
                    'quick_add_icon_color': '#4EA999',
                    'quick_add_icon_style': 'filled',
                  },
                },
              ),
            )
            .toList(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cmsPageLayoutProvider('wishlist').overrideWith((_) async => layout),
          ],
          child: MaterialApp(
            home: WishlistScreen(
              repository: FakeWishlistRepository(),
              catalogRepository: FakeWishlistCatalogRepository(
                onGetProducts: (_) async => catalogPage([wishlistProductOne]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.widget<CatalogProductCard>(
        find.byType(CatalogProductCard).first,
      );
      expect(card.settings!.string('quick_add_icon_style', ''), 'filled');
      expect(card.settings!.string('quick_add_icon_color', ''), '#4EA999');
      final materials = tester.widgetList<Material>(
        find.descendant(
          of: find.byType(CatalogProductCard).first,
          matching: find.byType(Material),
        ),
      );
      final shape = materials
          .map((m) => m.shape)
          .whereType<RoundedRectangleBorder>()
          .first;
      expect(materials.first.color, const Color(0xFFFAF1E1));
      expect(shape.side.width, .5);
      expect(shape.side.color, const Color(0xFFD3EAE6));
      expect(tester.takeException(), isNull);
    },
  );

  test('recommendations retain explicit actions and disabled quick add', () {
    final base = CmsPageLayout.fallback('wishlist');
    final result = wishlistRecommendationAppearance(
      const CmsPageComponent(
        id: 'empty_recommendations',
        type: 'empty_recommendations',
        enabled: true,
        settings: {
          'show_quick_add': false,
          'action_type': 'url',
          'action_value': 'https://example.com',
          'card_outline_color': '#112233',
        },
      ),
      base,
    );
    expect(result.boolean('quick_add_enabled', true), isFalse);
    expect(result.string('action_value', ''), 'https://example.com');
    expect(result.string('card_outline_color', ''), '#112233');
  });

  testWidgets('Arabic wishlist preserves merchant custom text', (tester) async {
    final base = CmsPageLayout.fallback('wishlist');
    final layout = CmsPageLayout(
      page: base.page,
      header: base.header,
      footer: base.footer,
      elements: base.elements
          .map(
            (e) => CmsPageComponent(
              id: e.id,
              type: e.type,
              enabled: e.enabled,
              settings: {
                ...e.settings,
                if (e.type == 'empty_state') ...{
                  'title': 'My special collection',
                  'description': 'Custom instructions',
                  'button_label': 'Browse my shop',
                },
              },
            ),
          )
          .toList(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cmsPageLayoutProvider('wishlist').overrideWith((_) async => layout),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: WishlistScreen(
            repository: FakeWishlistRepository(),
            catalogRepository: FakeWishlistCatalogRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My special collection'), findsOneWidget);
    expect(find.text('Custom instructions'), findsOneWidget);
    expect(find.text('Browse my shop'), findsOneWidget);
  });
  testWidgets(
    'Arabic wishlist translates saved default empty and sign-in copy',
    (tester) async {
      for (final signIn in [false, true]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: WishlistScreen(
                key: ValueKey(signIn),
                repository: FakeWishlistRepository(),
                catalogRepository: FakeWishlistCatalogRepository(),
                requiresSignIn: signIn,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(signIn ? 'سجّل الدخول لعرض المفضلة' : 'المفضلة فارغة'),
          findsOneWidget,
        );
        expect(
          find.text(signIn ? 'تسجيل الدخول' : 'متابعة التسوق'),
          findsOneWidget,
        );
        expect(find.text('قد يعجبك أيضًا'), findsOneWidget);
        expect(find.text('Your wishlist is empty'), findsNothing);
        expect(find.text('You may also like'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets('shows an empty wishlist without the local-only banner', (
    WidgetTester tester,
  ) async {
    bool continued = false;
    await tester.pumpWidget(
      _testApp(
        WishlistScreen(
          repository: FakeWishlistRepository(),
          catalogRepository: FakeWishlistCatalogRepository(),
          onContinueShopping: () => continued = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wishlist-local-only-notice')), findsNothing);
    expect(
      find.text('Saved on this device for this store only.'),
      findsNothing,
    );
    expect(find.byKey(const Key('wishlist-empty')), findsOneWidget);
    expect(find.byKey(const Key('wishlist-grid')), findsNothing);
    expect(find.text('Your wishlist is empty'), findsOneWidget);

    await tester.tap(find.byKey(const Key('wishlist-continue-shopping')));
    expect(continued, isTrue);
  });

  testWidgets('hydrates products, opens one, and removes it locally', (
    WidgetTester tester,
  ) async {
    CatalogProduct? opened;
    final FakeWishlistRepository wishlist = FakeWishlistRepository(
      ids: <int>[1],
    );
    await tester.pumpWidget(
      _testApp(
        Directionality(
          textDirection: TextDirection.rtl,
          child: WishlistScreen(
            repository: wishlist,
            catalogRepository: FakeWishlistCatalogRepository(
              products: const <CatalogProduct>[wishlistProductOne],
            ),
            onProductTap: (CatalogProduct product) => opened = product,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wishlist-grid')), findsOneWidget);
    expect(find.byKey(const Key('wishlist-empty')), findsNothing);
    expect(find.text('Everyday Jacket'), findsNothing);
    expect(find.text(r'$85.00'), findsOneWidget);
    expect(find.byKey(const Key('wishlist-count')), findsNothing);
    expect(find.text('1 item'), findsNothing);
    expect(find.byType(CmsPageAppBar), findsOneWidget);
    final double logicalWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(
      tester.getCenter(find.byKey(const Key('commerce-app-bar-title'))).dx,
      closeTo(logicalWidth / 2, 0.5),
    );

    await tester.tap(find.byKey(const Key('wishlist-product-1')));
    expect(opened?.id, 1);
    await tester.tap(find.byKey(const Key('wishlist-remove-1')));
    await tester.pumpAndSettle();

    expect(wishlist.ids, isEmpty);
    expect(find.byKey(const Key('wishlist-empty')), findsOneWidget);
    expect(find.text('Removed from wishlist'), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 3),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Removed from wishlist'), findsNothing);
  });

  testWidgets('renders a responsive RTL grid', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: WishlistScreen(
            repository: FakeWishlistRepository(ids: <int>[1, 2, 3]),
            catalogRepository: FakeWishlistCatalogRepository(
              products: const <CatalogProduct>[
                wishlistProductOne,
                wishlistProductTwo,
                wishlistProductThree,
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext gridContext = tester.element(
      find.byKey(const Key('wishlist-grid')),
    );
    expect(Directionality.of(gridContext), TextDirection.rtl);
    final GridView grid = tester.widget<GridView>(
      find.byKey(const Key('wishlist-grid')),
    );
    final SliverGridDelegateWithFixedCrossAxisCount delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(grid.padding?.resolve(TextDirection.rtl).top, 24);
  });

  testWidgets('mobile wishlist keeps image proportions and compact rows', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _testApp(
        WishlistScreen(
          repository: FakeWishlistRepository(ids: <int>[1, 2, 3]),
          catalogRepository: FakeWishlistCatalogRepository(
            products: const [
              wishlistProductOne,
              wishlistProductTwo,
              wishlistProductThree,
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final image = find
        .descendant(
          of: find.byKey(
            const ValueKey('wishlist-image-inset-wishlist_grid-1'),
          ),
          matching: find.byType(ClipRRect),
        )
        .first;
    final size = tester.getSize(image);
    expect(size.width / size.height, closeTo(.75, .001));
    final card = tester.getRect(find.byKey(const Key('wishlist-product-1')));
    expect(card.height - size.height, lessThan(65));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retryable load error', (WidgetTester tester) async {
    final FakeWishlistRepository wishlist = FakeWishlistRepository(
      onLoad: () async => throw StateError('read failed'),
    );
    await tester.pumpWidget(
      _testApp(
        WishlistScreen(
          repository: wishlist,
          catalogRepository: FakeWishlistCatalogRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wishlist-load-error')), findsOneWidget);
    wishlist.onLoad = null;
    await tester.tap(find.byKey(const Key('wishlist-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wishlist-empty')), findsOneWidget);
  });

  testWidgets('keeps the item visible when local removal fails', (
    WidgetTester tester,
  ) async {
    final FakeWishlistRepository wishlist = FakeWishlistRepository(
      ids: <int>[1],
      onSave: (_) async => throw StateError('disk full'),
    );
    await tester.pumpWidget(
      _testApp(
        WishlistScreen(
          repository: wishlist,
          catalogRepository: FakeWishlistCatalogRepository(
            products: const <CatalogProduct>[wishlistProductOne],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wishlist-remove-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wishlist-product-1')), findsOneWidget);
    expect(find.byKey(const Key('wishlist-mutation-error')), findsOneWidget);
  });
}

Widget _testApp(Widget home) {
  return ProviderScope(
    child: MaterialApp(theme: ThemeData(useMaterial3: true), home: home),
  );
}

