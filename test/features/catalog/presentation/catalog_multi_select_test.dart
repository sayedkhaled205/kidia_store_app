import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'package:mobishop_store_app/features/catalog/presentation/widgets/catalog_size_sheet.dart';

void main() {
  for (final colors in [false, true]) {
    testWidgets(
      '${colors ? 'color panel' : 'size sheet'} toggles multiple choices and applies a draft',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final taxonomy = colors ? 'pa_color' : 'pa_size';
        final options = [
          for (final label
              in colors
                  ? ['Red', 'Blue', 'Green']
                  : ['Small', 'Medium', 'Large'])
            CatalogSizeOption(
              taxonomy: taxonomy,
              term: label.toLowerCase(),
              label: label,
            ),
        ];
        var filters = const CatalogProductFilters(onSaleOnly: true);
        var applied = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1,
                  child: TextButton(
                    child: const Text('Open'),
                    onPressed: () async {
                      final selection = await CatalogSizeSheet.show(
                        context,
                        options: options,
                        selectedFilters: filters,
                        colors: colors,
                        belowToolbar: colors,
                      );
                      if (selection != null) {
                        applied++;
                        filters = colors
                            ? filters.withOptions(colors: selection.options)
                            : filters.withOptions(sizes: selection.options);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        final prefix = colors ? 'catalog-color' : 'catalog-size';
        Finder chip(int index) =>
            find.byKey(Key('$prefix-$taxonomy-${options[index].term}'));
        bool selected(int index) =>
            tester.widget<FilterChip>(chip(index)).selected;
        Future<void> open() async {
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
        }

        await open();
        await tester.tap(chip(0));
        await tester.pump();
        await tester.tap(chip(1));
        await tester.pump();
        expect(selected(0), true);
        expect(selected(1), true);
        expect(applied, 0);
        await tester.tap(chip(0));
        await tester.pump();
        expect(selected(0), false);
        expect(selected(1), true);
        await tester.tap(chip(2));
        await tester.pump();
        expect(
          tester.getRect(find.byKey(Key('$prefix-apply'))).bottom -
              tester.getRect(chip(0)).top,
          lessThan(200),
        );
        await tester.tap(find.byKey(Key('$prefix-apply')));
        await tester.pumpAndSettle();
        expect(applied, 1);
        expect((colors ? filters.colors : filters.sizes).length, 2);
        expect(filters.onSaleOnly, true);
        await open();
        expect(selected(1), true);
        expect(selected(2), true);
        await tester.tap(find.byKey(Key('$prefix-reset')));
        await tester.pump();
        expect(selected(1), false);
        expect((colors ? filters.colors : filters.sizes).length, 2);
        // Closing the panel discards edits, including a reset that was not applied.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(applied, 1);
        await open();
        expect(selected(1), true);
        await tester.tap(find.byKey(Key('$prefix-reset')));
        await tester.tap(find.byKey(Key('$prefix-apply')));
        await tester.pumpAndSettle();
        expect((colors ? filters.colors : filters.sizes), isEmpty);
        expect(filters.onSaleOnly, true);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
