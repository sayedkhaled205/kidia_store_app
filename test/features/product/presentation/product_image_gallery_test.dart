import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:mobishop_store_app/features/product/presentation/product_image_gallery.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';

void main() {
  final images = List.generate(
    3,
    (i) => CatalogImage(
      source: Uri.parse('https://example.test/original-$i.jpg'),
      cardVariant: Uri.parse('https://example.test/card-$i.jpg'),
    ),
  );

  for (final rtl in [false, true]) {
    testWidgets(
      'opens selected original, pages, and returns to product (RTL $rtl)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Directionality(
                        textDirection: rtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        child: ProductImageGallery(
                          images: images,
                          productName: 'Product',
                          initialIndex: 1,
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Product page'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Product page'));
        await _advance(tester);
        expect(find.text('2 / 3'), findsOneWidget);
        final image = tester.widget<AppNetworkImage>(
          find.byKey(const Key('fullscreen-product-image-1')),
        );
        expect(image.imageUrl, images[1].source.toString());
        expect(image.decodeAtDisplaySize, false);
        await tester.drag(
          find.byKey(const Key('fullscreen-gallery-pages')),
          Offset(rtl ? 600 : -600, 0),
        );
        await _advance(tester);
        expect(find.text('3 / 3'), findsOneWidget);
        await tester.tap(find.byKey(const Key('product-gallery-back')));
        await _advance(tester);
        expect(find.text('Product page'), findsOneWidget);
        expect(find.byType(ProductImageGallery), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pinch zoom keeps drag on image, zooming out restores page swipe',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProductImageGallery(images: images, productName: 'Product'),
        ),
      );
      await _advance(tester);
      final center = tester.getCenter(
        find.byKey(const Key('fullscreen-image-zoom')),
      );
      final first = await tester.startGesture(
        center - const Offset(40, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        center + const Offset(40, 0),
        pointer: 2,
      );
      await first.moveTo(center - const Offset(140, 0));
      await second.moveTo(center + const Offset(140, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await _advance(tester);
      final viewer = tester.widget<InteractiveViewer>(
        find.byKey(const Key('fullscreen-image-zoom')),
      );
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1.1),
      );
      expect(
        tester
            .widget<PageView>(find.byKey(const Key('fullscreen-gallery-pages')))
            .physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      await tester.drag(
        find.byKey(const Key('fullscreen-image-zoom')),
        const Offset(-300, 0),
      );
      await _advance(tester);
      expect(find.text('1 / 3'), findsOneWidget);
      viewer.transformationController!.value = Matrix4.identity();
      await _advance(tester);
      expect(
        tester
            .widget<PageView>(find.byKey(const Key('fullscreen-gallery-pages')))
            .physics,
        isA<PageScrollPhysics>(),
      );
      await tester.drag(
        find.byKey(const Key('fullscreen-gallery-pages')),
        const Offset(-600, 0),
      );
      await _advance(tester);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('single missing image remains finite and system back returns', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProductImageGallery(
                  images: [CatalogImage(source: Uri())],
                  productName: 'Missing',
                  initialIndex: 10,
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await _advance(tester);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byType(AppNetworkImageError), findsOneWidget);
    await tester.pageBack();
    await _advance(tester);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
