// Capture the real application and live public catalog. No provider overrides.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobishop_store_app/main.dart' as app;
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
      expect(finder, findsWidgets);
    }

    Future<void> capture(String name) async {
      // Let the real image requests and transitions finish; visual QA follows.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 6)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot(name);
    }

    app.main();
    await ready(find.byKey(const Key('cms-bottom-navigation')));
    final cards = find.byWidgetPredicate(
      (widget) => widget is StoreProductCard && widget.onTap != null,
    );
    await ready(cards);
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
    await capture('04-product-details');
    await tester.ensureVisible(find.byKey(const Key('open-product-image-0')));
    await tester.tap(find.byKey(const Key('open-product-image-0')));
    await ready(find.byType(ProductImageGallery));
    await capture('05-product-gallery');
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
