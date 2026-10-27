import 'package:flutter/material.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:mobishop_store_app/app/main_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'package:mobishop_store_app/features/catalog/presentation/pages/catalog_product_list_screen.dart';
import 'package:mobishop_store_app/features/categories/presentation/categories_screen.dart';
import 'package:mobishop_store_app/features/search/presentation/search_screen.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

void main() {
  testWidgets('system back unwinds category levels before returning Home', (tester) async {
    await tester.pumpWidget(_app(_ScreenCatalogRepository(
      categoryLayout: 'visual_grid', gridColumns: 2,
      navigationMode: 'separate_page', deepTree: true,
    ), const CategoriesScreen(), shell: true));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(CategoriesScreen)));
    await tester.tap(find.text('Women').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dresses').last);
    await tester.pumpAndSettle();
    expect(find.text('Summer dresses'), findsOneWidget);
    expect(await router.routerDelegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Dresses'), findsOneWidget);
    expect(find.text('Summer dresses'), findsNothing);
    expect(await router.routerDelegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Women'), findsOneWidget);
    expect(find.text('Men'), findsOneWidget);
    expect(await router.routerDelegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Home screen'), findsOneWidget);
    expect(await router.routerDelegate.popRoute(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back from root navigator respects category depth and dialogs', (tester) async {
    await tester.pumpWidget(_app(_ScreenCatalogRepository(
      categoryLayout: 'visual_grid', gridColumns: 2,
      navigationMode: 'separate_page', deepTree: true,
    ), const CategoriesScreen(), shell: true));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(CategoriesScreen));
    final router = GoRouter.of(context);
    final root = router.routerDelegate.navigatorKey.currentState!;
    await tester.tap(find.text('Women').last);
    await tester.pumpAndSettle();
    showDialog<void>(context: context, builder: (_) => const AlertDialog(title: Text('Category dialog')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Category dialog'), findsNothing);
    expect(find.byKey(const Key('category-level-title')), findsOneWidget);
    expect(await root.maybePop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Women'), findsOneWidget);
    expect(find.text('Men'), findsOneWidget);
    expect(find.text('Home screen'), findsNothing);
    // A retained category branch must not consume back from Wishlist.
    await tester.tap(find.text('Women'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cms-bottom-nav-wishlist')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home screen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visual cards apply saved height and image spacing at every level', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(_ScreenCatalogRepository(
      categoryLayout: 'visual_grid', gridColumns: 2,
      navigationMode: 'separate_page', deepTree: true,
      cardHeight: 192, imageScale: .95, nameHighlightEnabled: true,
    ), const CategoriesScreen()));
    await tester.pumpAndSettle();
    for (final id in [1, 2]) {
      final card = find.byKey(Key('category-visual-card-$id'));
      // The material surface sits inside the card's one-pixel outline.
      expect(tester.getSize(card).height, closeTo(190, 0.1));
      final image = tester.widget<Transform>(find.byKey(Key('category-visual-image-$id')));
      expect(image.transform.entry(0, 0), .95);
      expect(image.transform.entry(1, 1), .95);
      expect(image.alignment, Alignment.center);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(id == 1 ? 'Women' : 'Dresses').last);
      await tester.pumpAndSettle();
    }
  });
  testWidgets('Categories footer always returns from a child to root after Home', (tester) async {
    await tester.pumpWidget(_app(_ScreenCatalogRepository(
      categoryLayout:'visual_grid', gridColumns:2, navigationMode:'separate_page', deepTree:true,
    ), const CategoriesScreen(), shell:true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Women').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dresses').last);
    await tester.pumpAndSettle();
    expect(find.text('Summer dresses'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cms-bottom-nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('Home screen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cms-bottom-nav-categories')));
    await tester.pumpAndSettle();
    expect(find.text('Women'), findsOneWidget);
    expect(find.text('Men'), findsOneWidget);
    expect(find.byKey(const Key('category-back-to-roots')), findsNothing);
    // A second tap after opening another child must also reset the local path.
    await tester.tap(find.text('Women'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cms-bottom-nav-categories')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-back-to-roots')), findsNothing);
  });
  for (final direction in TextDirection.values) {
    for (final width in [320.0,360.0,390.0]) {
      testWidgets('single-line category title and centered header $direction $width', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_app(_ScreenCatalogRepository(
          categoryLayout:'visual_grid', gridColumns:2, rootName:'مستلزمات الأطفال', navigationMode:'separate_page',
        ), const CategoriesScreen(),direction:direction,scale:1.5));
        await tester.pumpAndSettle();
        final title = find.text('مستلزمات الأطفال');
        expect(tester.widget<Text>(title).maxLines, 1);
        expect(tester.widget<Text>(title).softWrap, false);
        expect(find.ancestor(of:title,matching:find.byType(FittedBox)), findsOneWidget);
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(tester.getCenter(find.byKey(const Key('category-level-title'))).dx, closeTo(width/2, 1));
        expect(find.byKey(const Key('category-view-all')), findsOneWidget);
        expect(tester.widget(find.byKey(const Key('category-view-all'))), isA<OutlinedButton>());
        await tester.tap(find.byKey(const Key('category-back-to-roots')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('category-level-title')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('cursor load more works without an exact page count', (tester) async {
    final repository = _ScreenCatalogRepository(cursor: true);
      await tester.pumpWidget(_app(repository, const CatalogProductListScreen(
        request: CatalogProductListRequest(),
      )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cursor item 1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Load more'), 300);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(repository.productQueries.map((query) => query.page), [1, 2]);
    expect(find.text('Cursor item 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('square card name band is optional, full width and inherited', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(
      _ScreenCatalogRepository(categoryLayout: 'visual_grid', gridColumns: 2, nameHighlightEnabled: false),
      const CategoriesScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-name-highlight-1')), findsNothing);
    final cardSize = tester.getSize(find.byKey(const Key('category-visual-card-1')));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(
      _ScreenCatalogRepository(categoryLayout: 'visual_grid', gridColumns: 2,
        nameHighlightEnabled: true, navigationMode: 'separate_page'),
      const CategoriesScreen(),
    ));
    await tester.pumpAndSettle();
    final band = find.byKey(const Key('category-name-highlight-1'));
    final card = find.byKey(const Key('category-visual-card-1'));
    expect(tester.widget<ColoredBox>(band).color, const Color(0xffe0f2ed));
    expect(tester.getSize(band).width, closeTo(tester.getSize(card).width, 1));
    expect(tester.getBottomLeft(band).dy, closeTo(tester.getBottomLeft(card).dy, 1));
    expect(tester.getSize(card), cardSize);
    await tester.tap(find.text('Women').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-name-highlight-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final layout in ['default', 'circular_grid', 'compact_grid', 'sidebar',
    'image_banner', 'top_tabs', 'split_rows', 'grouped_shelves', 'text_directory']) {
    testWidgets('name highlight remains usable in $layout on a phone', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(
        _ScreenCatalogRepository(categoryLayout: layout, gridColumns: 2,
          nameHighlightEnabled: true), const CategoriesScreen(),
      ));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((widget) => widget is ColoredBox &&
        widget.key.toString().contains('category-name-highlight-')), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('square cards fill two equal columns on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        _ScreenCatalogRepository(categoryLayout: 'visual_grid', gridColumns: 2),
        const CategoriesScreen(),
      ),
    );
    await tester.pumpAndSettle();
    final first = find.byKey(const Key('category-visual-card-1'));
    final second = find.byKey(const Key('category-visual-card-3'));
    final size = tester.getSize(first);
    expect(size.width, closeTo(size.height, 1));
    expect(size.width, greaterThan(150));
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
    expect(tester.getTopLeft(first).dx, isNot(tester.getTopLeft(second).dx));
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['separate_page', 'expand_inline']) {
    testWidgets('three category levels work with $mode', (tester) async {
      await tester.pumpWidget(
        _app(
          _ScreenCatalogRepository(navigationMode: mode, deepTree: true),
          const CategoriesScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Women').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dresses').last);
      await tester.pumpAndSettle();
      expect(find.text('Summer dresses'), findsOneWidget);
      if (mode == 'separate_page') {
        await tester.tap(find.byKey(const Key('category-back-to-roots')));
        await tester.pumpAndSettle();
        expect(find.text('Dresses'), findsOneWidget);
        await tester.tap(find.byKey(const Key('category-back-to-roots')));
        await tester.pumpAndSettle();
      } else {
        await tester.tap(find.text('Women').first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Men'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty search waits for a customer query', (
    WidgetTester tester,
  ) async {
    final _ScreenCatalogRepository repository = _ScreenCatalogRepository();
    await tester.pumpWidget(_app(repository, const SearchScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a product name to start searching'),
      findsOneWidget,
    );
    expect(repository.productQueries, isEmpty);

    await tester.enterText(find.byType(TextField), 'shirt');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.productQueries.single.search, 'shirt');
    expect(find.text('Shirt'), findsOneWidget);
  });

  testWidgets('categories preserve their parent-child hierarchy', (
    WidgetTester tester,
  ) async {
    final _ScreenCatalogRepository repository = _ScreenCatalogRepository();
    await tester.pumpWidget(_app(repository, const CategoriesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Women'), findsOneWidget);
    expect(find.text('Men'), findsOneWidget);
    expect(find.text('Dresses'), findsNothing);
    final Text categoryTitle = tester.widget<Text>(
      find.byKey(const Key('category-title-1')),
    );
    final double screenWidth = MediaQuery.sizeOf(
      tester.element(find.byType(CategoriesScreen)),
    ).width;
    final double responsiveScale = (screenWidth / 390).clamp(0.82, 1.22);
    expect(categoryTitle.style?.fontSize, closeTo(20 * responsiveScale, 0.001));
    expect(categoryTitle.style?.color, const Color(0xFF123456));
    expect(
      tester.getSize(find.byKey(const Key('category-image-text-gap-1'))).width,
      closeTo(24 * responsiveScale, 0.001),
    );
    final Finder artworkFinder = find.byKey(const Key('category-artwork-1'));
    expect(tester.getSize(artworkFinder), Size.square(80 * responsiveScale));
    final Container artwork = tester.widget<Container>(artworkFinder);
    final BoxDecoration decoration = artwork.decoration! as BoxDecoration;
    final BorderRadius borderRadius = decoration.borderRadius! as BorderRadius;
    expect(borderRadius.topLeft.x, closeTo(40 * responsiveScale, 0.001));
    expect(find.byKey(const Key('categories-search-action')), findsOneWidget);

    final Container squareArtwork = tester.widget<Container>(
      find.byKey(const Key('category-artwork-3')),
    );
    final BoxDecoration squareDecoration =
        squareArtwork.decoration! as BoxDecoration;
    final BorderRadius squareRadius =
        squareDecoration.borderRadius! as BorderRadius;
    expect(squareRadius.topLeft.x, 0);

    await tester.tap(find.byKey(const Key('category-title-1')));
    await tester.pumpAndSettle();

    expect(find.text('Dresses'), findsOneWidget);
    expect(find.text('Men'), findsNothing);
    final Finder roundedArtworkFinder = find.byKey(
      const Key('category-artwork-2'),
    );
    final Container roundedArtwork = tester.widget<Container>(
      roundedArtworkFinder,
    );
    final BoxDecoration roundedDecoration =
        roundedArtwork.decoration! as BoxDecoration;
    final BorderRadius roundedRadius =
        roundedDecoration.borderRadius! as BorderRadius;
    expect(
      roundedRadius.topLeft.x,
      closeTo(68 * responsiveScale * 0.18, 0.001),
    );
    expect(find.text('8 products'), findsNothing);
    expect(find.text('5 products'), findsNothing);
    expect(find.byType(SafeArea), findsWidgets);
  });

  testWidgets('category page renders the list and grid CMS layouts', (
    WidgetTester tester,
  ) async {
    const Map<String, Key> layouts = <String, Key>{
      'default': Key('category-layout-default'),
      'visual_grid': Key('category-layout-visual_grid'),
      'circular_grid': Key('category-layout-circular_grid'),
      'compact_grid': Key('category-layout-compact_grid'),
      'sidebar': Key('category-layout-sidebar'),
      'image_banner': Key('category-layout-image_banner'),
      'split_rows': Key('category-layout-split_rows'),
      'text_directory': Key('category-layout-text_directory'),
    };
    for (final MapEntry<String, Key> entry in layouts.entries) {
      await tester.pumpWidget(
        _app(
          _ScreenCatalogRepository(categoryLayout: entry.key),
          const CategoriesScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(entry.value), findsOneWidget, reason: entry.key);
      expect(find.text('Women'), findsWidgets, reason: entry.key);
      expect(find.text('Dresses'), findsNothing, reason: '${entry.key} roots');
      final Padding sectionSpacing = tester.widget<Padding>(
        find.byKey(const Key('category-section-layout-spacing')),
      );
      expect(sectionSpacing.padding, const EdgeInsets.only(top: 9, bottom: 10));
      final Transform sectionMerge = tester.widget<Transform>(
        find.byKey(const Key('category-section-layout-merge')),
      );
      expect(sectionMerge.transform.getTranslation().y, 1);
      await tester.tap(find.text('Women').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Dresses'),
        findsWidgets,
        reason: '${entry.key} children',
      );
      expect(
        find.text('Men'),
        findsNothing,
        reason: '${entry.key} children only',
      );
      expect(find.byKey(const Key('category-back-to-roots')), findsOneWidget);
      await tester.tap(find.byKey(const Key('category-back-to-roots')));
      await tester.pumpAndSettle();
      expect(
        find.text('Men'),
        findsOneWidget,
        reason: '${entry.key} back to roots',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  for (final layout in ['top_tabs', 'grouped_shelves']) {
    for (final mode in ['separate_page', 'expand_inline']) {
      testWidgets('$layout preserves nested navigation with $mode', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(
            _ScreenCatalogRepository(
              categoryLayout: layout,
              navigationMode: mode,
              gridColumns: 2,
              deepTree: true,
            ),
            const CategoriesScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(Key('category-layout-$layout')), findsOneWidget);
        expect(find.text('Dresses'), findsOneWidget);
        await tester.tap(find.text('Dresses'));
        await tester.pumpAndSettle();
        expect(find.text('Summer dresses'), findsOneWidget);
        if (mode == 'separate_page') {
          await tester.tap(find.byKey(const Key('category-back-to-roots')));
          await tester.pumpAndSettle();
          expect(find.text('Dresses'), findsWidgets);
        }
        if (layout == 'top_tabs') {
          await tester.tap(find.byKey(const Key('category-tab-3')));
          await tester.pumpAndSettle();
          expect(find.text('Dresses'), findsNothing);
          expect(find.byKey(const Key('category-back-to-roots')), findsNothing);
          await tester.tap(find.byKey(const Key('category-tab-1')));
          await tester.pumpAndSettle();
          expect(find.text('Dresses'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('curated layouts fit a narrow phone and larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final layout in [
      'top_tabs',
      'grouped_shelves',
      'split_rows',
      'text_directory',
    ]) {
      await tester.pumpWidget(
        _app(
          _ScreenCatalogRepository(categoryLayout: layout, gridColumns: 2),
          const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: CategoriesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(Key('category-layout-$layout')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: layout);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('category layouts are distinct and expand children in place', (
    WidgetTester tester,
  ) async {
    const Map<String, Key> layoutSurfaces = <String, Key>{
      'visual_grid': Key('category-visual-card-1'),
      'circular_grid': Key('category-circular-card-1'),
      'compact_grid': Key('category-compact-card-1'),
      'image_banner': Key('category-banner-card-1'),
    };
    for (final MapEntry<String, Key> entry in layoutSurfaces.entries) {
      await tester.pumpWidget(
        _app(
          _ScreenCatalogRepository(
            categoryLayout: entry.key,
            navigationMode: 'expand_inline',
          ),
          const CategoriesScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(entry.value), findsOneWidget, reason: entry.key);
      expect(find.text('Dresses'), findsNothing, reason: entry.key);
      await tester.tap(find.byKey(const Key('category-expand-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('category-inline-panel-1')),
        findsOneWidget,
        reason: entry.key,
      );
      expect(find.text('Dresses'), findsOneWidget, reason: entry.key);
      expect(find.text('Men'), findsOneWidget, reason: entry.key);
      await tester.pumpWidget(const SizedBox.shrink());
    }

    await tester.pumpWidget(
      _app(
        _ScreenCatalogRepository(
          categoryLayout: 'default',
          navigationMode: 'expand_inline',
        ),
        const CategoriesScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-expand-1')));
    await tester.pumpAndSettle();
    expect(find.text('Dresses'), findsOneWidget);
    expect(find.text('Men'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        _ScreenCatalogRepository(
          categoryLayout: 'sidebar',
          navigationMode: 'expand_inline',
        ),
        const CategoriesScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-sidebar-rail')), findsOneWidget);
    expect(find.byKey(const Key('category-sidebar-detail')), findsOneWidget);
    expect(find.text('Dresses'), findsOneWidget);
    await tester.tap(find.byKey(const Key('category-sidebar-root-3')));
    await tester.pumpAndSettle();
    expect(find.text('Dresses'), findsNothing);
    expect(find.text('Products in 3'), findsOneWidget);
  });

  testWidgets('product list uses three controls without a duplicate search', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _ScreenCatalogRepository repository = _ScreenCatalogRepository();
    await tester.pumpWidget(
      _app(
        repository,
        const CatalogProductListScreen(
          request: CatalogProductListRequest(title: 'Shoes'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('1 product'), findsNothing);
    expect(find.byType(CmsPageAppBar), findsOneWidget);
    expect(find.byKey(const Key('commerce-app-bar-title')), findsOneWidget);
    expect(find.text('Shoes'), findsOneWidget);
    expect(find.byKey(const Key('catalog-filter-button')), findsOneWidget);
    expect(find.byKey(const Key('catalog-size-button')), findsOneWidget);
    expect(find.byKey(const Key('catalog-sort-button')), findsOneWidget);
    final SliverPadding gridPadding = tester.widget<SliverPadding>(
      find.byKey(const Key('catalog-product-grid-padding')),
    );
    expect(gridPadding.padding.resolve(TextDirection.ltr).top, 0);
    final SliverPersistentHeader toolbar = tester
        .widget<SliverPersistentHeader>(find.byType(SliverPersistentHeader));
    expect(toolbar.pinned, isTrue);

    await tester.tap(find.byKey(const Key('catalog-size-button')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a size'), findsOneWidget);
    expect(find.text('Small'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search action opens a focused overlay on the current screen', (
    WidgetTester tester,
  ) async {
    final _ScreenCatalogRepository repository = _ScreenCatalogRepository();
    await tester.pumpWidget(
      _app(
        repository,
        const CatalogProductListScreen(
          request: CatalogProductListRequest(title: 'Shoes'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(CatalogProductListScreen), findsOneWidget);
    expect(
      find.byKey(const Key('catalog-search-overlay-field')),
      findsOneWidget,
    );
    final TextField field = tester.widget<TextField>(
      find.byKey(const Key('catalog-search-overlay-field')),
    );
    expect(field.autofocus, isTrue);
    expect(
      tester
          .getSize(find.byKey(const Key('catalog-search-field-frame')))
          .height,
      48,
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('catalog-search-top-overlay'))).dy,
      lessThan(160),
    );
  });
}

Widget _app(CatalogRepository repository, Widget home, {bool shell = false, TextDirection? direction, double scale = 1}) {
  return ProviderScope(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(repository),
      cartBadgeCountProvider.overrideWithValue(0),
      // These renderer fixtures carry presentation settings on their category
      // records. Do not require a compiled merchant design or a live CMS read.
      // Saved-design validation and platform binding have their own contracts.
      portableAppDesign58Provider.overrideWithValue(null),
      cmsPageLayoutProvider.overrideWith((ref, page) async {
        final base = CmsPageLayout.fallback(page);
        if (repository is! _ScreenCatalogRepository || repository.nameHighlightEnabled == null) return base;
        // Exercise the saved general settings path, shared by all platforms,
        // rather than assigning presentation only to a fixture's parent node.
        return CmsPageLayout(page: page, header: base.header, footer: base.footer,
          elements: base.elements, settings: {
            'category_general': {
              'category_layout': repository.categoryLayout,
              'navigation_mode': repository.navigationMode,
              'grid_columns': repository.gridColumns,
              'card_gap': 12,
              'card_height': repository.cardHeight,
              'image_scale': repository.imageScale * 100,
              'name_highlight_enabled': repository.nameHighlightEnabled! ? '1' : '0',
              'name_highlight_color': '#E0F2ED',
            },
          });
      }),
    ],
    child: MaterialApp.router(
      locale: const Locale('en'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: direction ?? TextDirection.ltr, child: child!),
      ),
      routerConfig: GoRouter(
        initialLocation: shell ? '/categories' : '/',
        routes: [
          if (shell) StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(routes:[GoRoute(path:'/home',builder:(_,_)=>const Scaffold(body:Text('Home screen')))]),
              StatefulShellBranch(routes:[GoRoute(path:'/categories',builder:(_,_)=>home)]),
              StatefulShellBranch(routes:[GoRoute(path:'/wishlist',builder:(_,_)=>const Scaffold())]),
              StatefulShellBranch(routes:[GoRoute(path:'/account',builder:(_,_)=>const Scaffold())]),
            ],
          ) else GoRoute(path: '/', builder: (context, state) => home),
          GoRoute(
            path: '/categories/:id',
            builder: (context, state) => Scaffold(
              body: Text('Products in ${state.pathParameters['id']}'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScreenCatalogRepository implements CatalogRepository {
  _ScreenCatalogRepository({
    this.categoryLayout = 'default',
    this.rootName = 'Women',
    this.navigationMode = 'drilldown',
    this.gridColumns = 4,
    this.deepTree = false,
    this.nameHighlightEnabled,
    this.cursor = false,
    this.cardHeight = 0,
    this.imageScale = 1,
  });

  final String categoryLayout;
  final String rootName;
  final String navigationMode;
  final int gridColumns;
  final bool deepTree;
  final bool? nameHighlightEnabled;
  final bool cursor;
  final double cardHeight;
  final double imageScale;
  final List<CatalogProductQuery> productQueries = <CatalogProductQuery>[];

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(
    CatalogProductQuery query,
  ) async {
    productQueries.add(query);
    if (cursor) {
      return CatalogPage<CatalogProduct>(
        items: [CatalogProduct(id: query.page, name: 'Cursor item ${query.page}',
          slug: 'cursor-${query.page}', type: 'simple', isInStock: true,
          prices: const CatalogMoney(currencyCode: 'USD', currencySymbol: r'$',
            currencyMinorUnit: 2, priceMinor: '1999'))],
        page: query.page, perPage: query.perPage, totalItems: null,
        totalPages: null, cursorPagination: true, cursorHasNextPage: query.page == 1,
      );
    }
    final List<CatalogProduct> products = <CatalogProduct>[
      const CatalogProduct(
        id: 10,
        name: 'Shirt',
        slug: 'shirt',
        type: 'simple',
        isInStock: true,
        prices: CatalogMoney(
          currencyCode: 'USD',
          currencySymbol: r'$',
          currencyMinorUnit: 2,
          priceMinor: '1999',
        ),
        attributes: <CatalogProductAttribute>[
          CatalogProductAttribute(
            id: 1,
            name: 'Size',
            taxonomy: 'pa_size',
            hasVariations: true,
            terms: <CatalogAttributeTerm>[
              CatalogAttributeTerm(id: 1, name: 'Small', slug: 's'),
            ],
          ),
        ],
      ),
    ];
    return CatalogPage<CatalogProduct>(
      items: products,
      page: query.page,
      perPage: query.perPage,
      totalItems: products.length,
      totalPages: products.isEmpty ? 0 : 1,
    );
  }

  @override
  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  ) async {
    return CatalogPage<CatalogCategory>(
      items: <CatalogCategory>[
        CatalogCategory(
          id: 1,
          name: rootName,
          slug: 'women',
          count: 8,
          imageSize: 80,
          imageShape: 'circle',
          imageTextGap: 24,
          fontSize: 20,
          fontColor: '#123456',
          nameHighlightEnabled: nameHighlightEnabled ?? false,
          nameHighlightColor: '#E0F2ED',
          fontWeight: 600,
          textAlign: 'center',
          lineHeight: 1.4,
          categoryLayout: categoryLayout,
          navigationMode: navigationMode,
          gridColumns: gridColumns,
          cardRadius: 20,
          cardHeight: cardHeight,
          imageScale: imageScale,
          cardGap: 12,
          marginTop: 7,
          marginBottom: 8,
          spaceUp: 9,
          spaceDown: 10,
        ),
        CatalogCategory(
          id: 2,
          name: 'Dresses',
          slug: 'dresses',
          parentId: 1,
          count: 5,
        ),
        CatalogCategory(
          id: 3,
          name: 'Men',
          slug: 'men',
          count: 3,
          imageSize: 64,
          imageShape: 'square',
        ),
        if (deepTree)
          const CatalogCategory(
            id: 4,
            name: 'Summer dresses',
            slug: 'summer',
            parentId: 2,
          ),
      ],
      page: query.page,
      perPage: query.perPage,
      totalItems: deepTree ? 4 : 3,
      totalPages: 1,
    );
  }

  @override
  Future<CatalogFilterData> getFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  }) async {
    return const CatalogFilterData();
  }

  @override
  Future<CatalogProduct> getProduct(int productId) {
    throw UnimplementedError();
  }

  @override
  Future<List<CatalogVariation>> getVariations(int productId) async {
    return const <CatalogVariation>[];
  }
}
