import 'package:mobishop_store_app/features/catalog/presentation/widgets/catalog_product_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'package:mobishop_store_app/features/catalog/presentation/widgets/catalog_size_sheet.dart';
import 'package:mobishop_store_app/features/catalog/presentation/widgets/catalog_sort_sheet.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';

void main() {
  for (final sidePanel in [false, true]) {
    for (final size in [const Size(390, 844), const Size(768, 1024)]) {
      testWidgets('full filter rotation and keyboard $sidePanel $size', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Open filters'),
                  onPressed: () => CatalogProductFilterSheet.show(
                    context,
                    initialFilters: const CatalogProductFilters(),
                    currencyMinorUnit: 2,
                    minimumAvailableMinor: '0',
                    maximumAvailableMinor: '10000',
                    brands: [],
                    sidePanel: sidePanel,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open filters'));
        await tester.pumpAndSettle();
        tester.view.physicalSize = Size(size.height, size.width);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const Key('catalog-minimum-price')),
        );
        await tester.enterText(
          find.byKey(const Key('catalog-minimum-price')),
          '10',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(CatalogProductFilterSheet), findsNothing);
        expect(find.text('Open filters').hitTestable(), findsOneWidget);
      });
    }
  }

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1024, 768),
  ]) {
    for (final kind in ['size', 'color', 'sort']) {
      testWidgets('$kind panel remains reachable after rotation from $size', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Builder(
                  builder: (context) => TextButton(
                    child: const Text('Open'),
                    onPressed: () {
                      if (kind == 'sort') {
                        CatalogSortSheet.show(
                          context,
                          selected: CatalogSort.relevance,
                          belowToolbar: true,
                        );
                      } else {
                        CatalogSizeSheet.show(
                          context,
                          belowToolbar: true,
                          colors: kind == 'color',
                          selectedFilters: const CatalogProductFilters(),
                          options: [
                            for (var i = 0; i < 40; i++)
                              CatalogSizeOption(
                                taxonomy: 'pa_size',
                                term: '$i',
                                label: '$i-${i + 6}m',
                              ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final viewport in [Size(size.height, size.width), size]) {
          tester.view.physicalSize = viewport;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('catalog-panel-close')).hitTestable(),
            findsOneWidget,
          );
          if (kind != 'sort') {
            final prefix = kind == 'color' ? 'catalog-color' : 'catalog-size';
            expect(
              find.byKey(Key('$prefix-apply')).hitTestable(),
              findsOneWidget,
            );
            expect(
              find.byKey(Key('$prefix-reset')).hitTestable(),
              findsOneWidget,
            );
          }
        }
        await tester.tap(find.byKey(const Key('catalog-panel-close')));
        await tester.pumpAndSettle();
        expect(find.text('Open').hitTestable(), findsOneWidget);
      });
    }
  }
}

