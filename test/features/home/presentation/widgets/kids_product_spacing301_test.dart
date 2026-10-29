import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/features/home/data/models/home_block_model.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_widgets.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_card.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_image_swiper.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_price.dart';

HomeBlock _collection({
  required bool grid,
  bool showName = false,
  bool showPrice = true,
  bool discount = false,
}) => HomeBlockModel.fromJson({
  'id': grid ? 'all-products' : 'promo-products',
  'type': grid ? 'product_grid' : 'product_carousel',
  'enabled': true,
  'data': {
    'item_width': 164,
    'columns': 2,
    'image_ratio': 0.75,
    'card_radius': 0,
    'card_style': 'no_shadow',
    'show_name': showName,
    'show_price': showPrice,
    'show_regular_price': discount,
    'show_rating': false,
    'show_badge': false,
    'show_wishlist': false,
    'quick_add_enabled': false,
    'content_bottom_padding': 8,
    'items': List.generate(
      4,
      (index) => {
        'id': index + 1,
        'name': 'Kids outfit ${index + 1}',
        'image_url': 'https://store.example/product.jpg',
        'price': '${375 + index * 10}',
        'regular_price': discount ? '475' : null,
        'currency_code': 'EGP',
        'currency_symbol': 'EGP',
        'action': {'type': 'product', 'value': '${index + 1}'},
      },
    ),
  },
});

Future<void> _pump(
  WidgetTester tester,
  HomeBlock block, {
  double width = 390,
  double textScale = 1,
  ValueChanged<HomeAction>? onAction,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp(
      theme: ThemeData(
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4EA999)),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: const Key('spacing-proof'),
                child: ColoredBox(
                  color: Colors.white,
                  child: Column(
                    children: [
                      if (block is ProductGridBlock)
                        ProductGridBlockWidget(
                          block: block,
                          onAction: onAction ?? (_) {},
                        )
                      else
                        ProductCarouselBlockWidget(
                          block: block as ProductCarouselBlock,
                          onAction: onAction ?? (_) {},
                        ),
                      const SizedBox(
                        key: Key('next-section'),
                        width: double.infinity,
                        height: 40,
                        child: Text('EXPLORE'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    )),
  );
  await tester.pump();
}

Future<void> _capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('KIDS_SPACING_CAPTURE_DIR');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('spacing-proof')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await fonts.load();
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets(
        'price-only grid has compact rows at $width and text scale $scale',
        (tester) async {
          await _pump(
            tester,
            _collection(grid: true),
            width: width,
            textScale: scale,
          );
          final cards = find.byType(ProductCard);
          final firstPrice = tester.getRect(
            find.descendant(
              of: cards.at(0),
              matching: find.byType(ProductPrice),
            ),
          );
          final nextImage = tester.getRect(
            find.descendant(
              of: cards.at(2),
              matching: find.byType(ProductImageSwiper),
            ),
          );
          // Only the chosen card bottom padding and the actual grid gutter
          // remain between the visible price and the next product image.
          expect(nextImage.top - firstPrice.bottom, closeTo(20, 0.01));
          expect(tester.takeException(), isNull);
          if (width == 390 && scale == 1) {
            await _capture(tester, 'grid-spacing301');
          }
        },
      );
      testWidgets(
        'price-only carousel ends after prices at $width and text scale $scale',
        (tester) async {
          await _pump(
            tester,
            _collection(grid: false, discount: true),
            width: width,
            textScale: scale,
          );
          final firstCard = find.byType(ProductCard).first;
          final price = tester.getRect(
            find.descendant(of: firstCard, matching: find.byType(ProductPrice)),
          );
          final nextSection = tester.getRect(
            find.byKey(const Key('next-section')),
          );
          expect(nextSection.top - price.bottom, closeTo(16, 0.01));
          expect(tester.takeException(), isNull);
          if (width == 390 && scale == 1) {
            await _capture(tester, 'carousel-spacing301');
          }
        },
      );
    }
  }

  testWidgets(
    'carousel still scrolls horizontally and opens the selected product',
    (tester) async {
      HomeAction? selected;
      await _pump(
        tester,
        _collection(grid: false),
        onAction: (action) => selected = action,
      );
      await tester.drag(find.byType(ListView), const Offset(500, 0));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('405 EGP'));
      expect(selected?.value, '4');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('metadata-rich cards retain their established layout', (
    tester,
  ) async {
    await _pump(tester, _collection(grid: true, showName: true));
    final firstCard = find.byType(ProductCard).first;
    final image = tester.getSize(
      find.descendant(of: firstCard, matching: find.byType(ProductImageSwiper)),
    );
    expect(tester.getSize(firstCard).height - image.height, closeTo(126, 0.01));
    expect(find.text('Kids outfit 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('image-only carousel does not reserve a metadata row', (
    tester,
  ) async {
    await _pump(tester, _collection(grid: false, showPrice: false));
    final firstCard = find.byType(ProductCard).first;
    final image = tester.getSize(
      find.descendant(of: firstCard, matching: find.byType(ProductImageSwiper)),
    );
    expect(tester.getSize(firstCard).height, closeTo(image.height, 0.01));
    expect(find.byType(ProductPrice), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
