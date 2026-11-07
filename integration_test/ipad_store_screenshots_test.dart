// Capture the real application and live public catalog. No provider overrides.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobishop_store_app/main.dart' as app;
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_frame.dart';
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_widgets.dart';
import 'package:mobishop_store_app/features/categories/presentation/categories_screen.dart';
import 'package:mobishop_store_app/features/catalog/presentation/pages/catalog_product_list_screen.dart';
import 'package:mobishop_store_app/features/product/presentation/product_detail_screen.dart';
import 'package:mobishop_store_app/features/product/presentation/product_image_gallery.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';
import 'package:mobishop_store_app/shared/widgets/product/store_product_card.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.defaultTestTimeout = const Timeout(Duration(minutes: 9));
  testWidgets('real iPad storefront screenshots', (tester) async {
    Future<void> ready(Finder finder) async {
      final end = DateTime.now().add(const Duration(seconds: 90));
      while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (finder.evaluate().isEmpty) {
        await binding.takeScreenshot('diagnostic-timeout');
      }
      expect(finder, findsWidgets);
    }

    Future<void> heroReady() async {
      final viewport =
          Offset.zero &
          (tester.view.physicalSize / tester.view.devicePixelRatio);
      var stable = 0;
      String? previousUrl;
      final end = DateTime.now().add(const Duration(seconds: 90));
      while (stable < 3 && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
        String? loadedUrl;
        final heroes = find.byType(HeroSliderBlockWidget).evaluate();
        for (final heroElement in heroes) {
          final hero = heroElement.widget as HeroSliderBlockWidget;
          final scope = find.byWidget(hero);
          final pages = find.descendant(
            of: scope,
            matching: find.byType(PageView),
          );
          if (pages.evaluate().length != 1) continue;
          final controller = tester.widget<PageView>(pages).controller;
          if (controller == null || !controller.hasClients) continue;
          final page = controller.page;
          if (page == null || (page - page.round()).abs() > 0.001) continue;
          final index = page.round();
          if (index < 0 || index >= hero.block.items.length) continue;
          final expectedUrl = hero.block.items[index].imageUrl;
          if (expectedUrl.trim().isEmpty) continue;
          final imageFinder = find.descendant(
            of: scope,
            matching: find.byWidgetPredicate(
              (w) => w is AppNetworkImage && w.imageUrl == expectedUrl,
            ),
          );
          for (final imageElement in imageFinder.evaluate()) {
            final imageScope = find.byWidget(imageElement.widget);
            final bad = find.descendant(
              of: imageScope,
              matching: find.byWidgetPredicate(
                (w) => w is AppNetworkImageLoading || w is AppNetworkImageError,
              ),
            );
            if (bad.evaluate().isNotEmpty) continue;
            final decoded = find
                .descendant(of: imageScope, matching: find.byType(RawImage))
                .evaluate()
                .any((element) {
                  final render = element.findRenderObject();
                  if (render is! RenderImage ||
                      !render.attached ||
                      !render.hasSize ||
                      render.image == null ||
                      render.size.isEmpty) {
                    return false;
                  }
                  final rect = render.localToGlobal(Offset.zero) & render.size;
                  // Exclude neighbouring PageView slides and barely visible edges.
                  return viewport.contains(rect.center) &&
                      rect.intersect(viewport).width >= rect.width * 0.95 &&
                      rect.intersect(viewport).height >= rect.height * 0.95;
                });
            if (decoded) loadedUrl = expectedUrl;
          }
        }
        stable = loadedUrl != null && loadedUrl == previousUrl ? stable + 1 : 0;
        previousUrl = loadedUrl;
      }
      if (stable < 3) await binding.takeScreenshot('diagnostic-timeout');
      expect(
        stable,
        greaterThanOrEqualTo(3),
        reason: 'Active onscreen hero URL must have its own decoded image, without placeholder',
      );
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['home_hero_loaded'] = true;
      binding.reportData!['home_hero_url'] = previousUrl;
    }

    Future<void> capture(
      String name, {
      int images = 3,
      int texts = 4,
      Finder? imageScope,
    }) async {
      // Let the real image requests and transitions finish; visual QA follows.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 6)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final viewport =
          Offset.zero &
          (tester.view.physicalSize / tester.view.devicePixelRatio);
      bool visible(RenderBox box) =>
          box.attached &&
          box.hasSize &&
          !box.size.isEmpty &&
          (box.localToGlobal(Offset.zero) & box.size).overlaps(viewport);
      var stable = 0;
      var previousImages = -1;
      var previousTexts = -1;
      final end = DateTime.now().add(const Duration(seconds: 60));
      while (stable < 3 && DateTime.now().isBefore(end)) {
        final imageFinder = imageScope == null
            ? find.byType(RawImage)
            : find.descendant(of: imageScope, matching: find.byType(RawImage));
        final imageCount = imageFinder.evaluate().where((element) {
          final render = element.findRenderObject();
          return render is RenderImage &&
              render.image != null &&
              visible(render);
        }).length;
        final textCount = find.byType(RichText).evaluate().where((element) {
          final render = element.findRenderObject();
          return render is RenderParagraph &&
              visible(render) &&
              render.text.toPlainText().trim().isNotEmpty;
        }).length;
        stable =
            imageCount >= images &&
                textCount >= texts &&
                imageCount == previousImages &&
                textCount == previousTexts
            ? stable + 1
            : 0;
        previousImages = imageCount;
        previousTexts = textCount;
        await tester.pump(const Duration(milliseconds: 500));
      }
      if (stable < 3) {
        await binding.takeScreenshot('diagnostic-timeout');
      }
      expect(
        stable,
        greaterThanOrEqualTo(3),
        reason: 'Visible decoded images and text must be loaded and stable',
      );
      expect(tester.takeException(), isNull);
      binding.reportData ??= <String, dynamic>{};
      binding.reportData![name] = {
        'visible_decoded_images': previousImages,
        'visible_text_blocks': previousTexts,
        'stable_frames': stable,
      };
      if (name == '01-home') await heroReady();
      await binding.takeScreenshot(name);
    }

    app.main();
    await ready(find.byKey(const Key('cms-bottom-navigation')));
    final cards = find.byWidgetPredicate(
      (widget) => widget is StoreProductCard && widget.onTap != null,
    );
    // Home can use its own ProductCard renderer; StoreProductCard is catalog-only
    // for some saved designs. Wait for real home content instead of that style.
    await ready(find.byType(HomeBlockFrame));
    // Global image/text counts proved insufficient: five images could pass
    // while the hero slide itself still showed a placeholder. Gate on the
    // onscreen hero slide's own decoded image before capturing Home.
    await capture('01-home');
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('cms-bottom-navigation'))),
    );
    router.go('/categories');
    await ready(find.byType(CategoriesScreen));
    // A category must arrive from the live API before capturing this route.
    await ready(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            RegExp(
              r'^category-(grid|visual|circular|compact|split|directory|banner).*card-',
            ).hasMatch((widget.key! as ValueKey<String>).value),
      ),
    );
    await capture('02-categories');
    router.go('/products');
    await ready(find.byType(CatalogProductListScreen));
    final catalogCards = find.descendant(
      of: find.byType(CatalogProductListScreen),
      matching: cards,
    );
    await ready(catalogCards);
    await capture('03-products');
    await tester.ensureVisible(catalogCards.first);
    await tester.tap(catalogCards.first);
    await ready(find.byType(ProductDetailScreen));
    await ready(find.byKey(const Key('open-product-image-0')));
    await capture(
      '04-product-details',
      images: 1,
      imageScope: find.byKey(const Key('open-product-image-0')),
    );
    await tester.ensureVisible(find.byKey(const Key('open-product-image-0')));
    await tester.tap(find.byKey(const Key('open-product-image-0')));
    await ready(find.byType(ProductImageGallery));
    await capture(
      '05-product-gallery',
      images: 1,
      texts: 0,
      imageScope: find.byType(ProductImageGallery),
    );
    binding.reportData ??= <String, dynamic>{};
    binding.reportData!.addAll({
      'source': '69f353ad1baddb77d5630c47443cf34c23441448',
      'data': 'live public endpoints',
      'account_submissions': 0,
      'orders': 0,
      'payments': 0,
    });
  });
}
