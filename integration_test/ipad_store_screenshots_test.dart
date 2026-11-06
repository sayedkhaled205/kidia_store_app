// Capture the real application and live public catalog. No provider overrides.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobishop_store_app/main.dart' as app;
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_frame.dart';
import 'package:mobishop_store_app/features/categories/presentation/categories_screen.dart';
import 'package:mobishop_store_app/features/catalog/presentation/pages/catalog_product_list_screen.dart';
import 'package:mobishop_store_app/features/product/presentation/product_detail_screen.dart';
import 'package:mobishop_store_app/features/product/presentation/product_image_gallery.dart';
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
      'source': 'c24d4eed1dc4148d5590c1572c1bc778f21e2476',
      'data': 'live public endpoints',
      'account_submissions': 0,
      'orders': 0,
      'payments': 0,
    });
  });
}
