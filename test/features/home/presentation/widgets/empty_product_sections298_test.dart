import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/home/data/models/home_block_model.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_renderer.dart';

HomeBlock _products({
  String type = 'product_carousel',
  String? title,
  bool populated = false,
}) => HomeBlockModel.fromJson({
  'id': 'optional-products',
  'type': type,
  'enabled': true,
  'data': {
    'title': title,
    'item_width': 164,
    'image_ratio': 0.75,
    'show_name': true,
    'show_view_all': true,
    'view_all_label': 'MORE',
    'presentation': {'space_up': 18, 'space_down': 20},
    'items': [
      if (populated)
        {
          'id': 123,
          'name': 'Available featured item',
          'image_url': 'https://store.example/item.jpg',
          'price': '25.00',
          'currency_code': 'EGP',
          'currency_symbol': 'EGP',
          'action': {'type': 'product', 'value': '123'},
        },
    ],
  },
});

PromoStripBlock _banner(String id) => PromoStripBlock(
  id: id,
  enabled: true,
  text: id,
  backgroundColor: '#FFFFFF',
  textColor: '#111111',
  action: null,
);

Future<void> _pumpHome(
  WidgetTester tester,
  List<HomeBlock> blocks, {
  ValueChanged<HomeAction>? onAction,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            HomeBlockRenderer(blocks: blocks, onAction: onAction ?? (_) {}),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  for (final type in ['product_carousel', 'product_grid']) {
    testWidgets(
      '$type with no matches leaves no blank row, heading, or section spacing',
      (tester) async {
        await _pumpHome(tester, [
          _banner('before'),
          _products(type: type, title: 'Empty collection'),
          _banner('after'),
        ]);

        final before = find.byKey(const Key('home-block-frame-before'));
        final after = find.byKey(const Key('home-block-frame-after'));
        expect(
          tester.getTopLeft(after).dy,
          closeTo(tester.getBottomLeft(before).dy, 0.01),
        );
        expect(find.text('Empty collection'), findsNothing);
        expect(find.text('MORE'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a collection appears after a refresh finds products', (
    tester,
  ) async {
    await _pumpHome(tester, [_banner('before'), _products(), _banner('after')]);
    expect(
      find.byKey(const Key('home-block-frame-optional-products')),
      findsNothing,
    );

    HomeAction? selected;
    await _pumpHome(tester, [
      _banner('before'),
      _products(populated: true),
      _banner('after'),
    ], onAction: (action) => selected = action);
    expect(find.text('Available featured item'), findsOneWidget);
    await tester.tap(find.text('Available featured item'));
    expect(selected?.type, 'product');
    expect(selected?.value, '123');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed collection stays visible with retry instead of hiding', (
    tester,
  ) async {
    HomeAction? selected;
    await _pumpHome(tester, [
      _banner('before'),
      CatalogUnavailableBlock(_products()),
      _banner('after'),
    ], onAction: (action) => selected = action);
    expect(find.text('Reload this section'), findsOneWidget);
    await tester.tap(find.text('Reload this section'));
    expect(selected?.type, 'retry_home');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a home containing only empty collections has an empty state', (
    tester,
  ) async {
    await _pumpHome(tester, [_products(), _products(type: 'product_grid')]);
    expect(find.text('لا توجد أقسام متاحة حاليًا'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
