import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/app_ui_controls.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'package:mobishop_store_app/features/catalog/presentation/widgets/catalog_product_filter_sheet.dart';

const size = CatalogSizeOption(taxonomy: 'pa_المقاس', term: '4y', label: '4Y');
const color = CatalogSizeOption(
  taxonomy: 'pa_color',
  term: 'blue',
  label: 'Blue',
);
const tag = CatalogTagOption(id: 124, label: 'Trousers');
const options = CatalogFilterOptions(
  sizes: [size],
  colors: [color],
  tags: [tag],
);

Future<void> open(
  WidgetTester tester, {
  String language = 'en',
  double scale = 1,
  bool showSizes = true,
  CatalogProductFilters initial = const CatalogProductFilters(),
  Future<CatalogFilterOptions> Function()? load,
  ValueChanged<CatalogProductFilters?>? result,
  ValueNotifier<Map<String, dynamic>>? controls,
}) async {
  tester.view.physicalSize = const Size(320, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: controls == null
            ? child!
            : ValueListenableBuilder<Map<String, dynamic>>(
                valueListenable: controls,
                builder: (context, values, _) => AppUiControlsScope(
                  controls: AppUiControls.fromJson(values),
                  child: child!,
                ),
              ),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            child: const Text('Open'),
            onPressed: () async {
              final value = await CatalogProductFilterSheet.show(
                context,
                initialFilters: initial,
                currencyMinorUnit: 2,
                minimumAvailableMinor: '100',
                maximumAvailableMinor: '100000',
                brands: const [],
                sidePanel: true,
                showSizes: showSizes,
                loadOptions: load ?? () async => options,
              );
              result?.call(value);
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'published filter appearance and rollback retain entered prices and choices',
    (tester) async {
      final controls = ValueNotifier<Map<String, dynamic>>({});
      addTearDown(controls.dispose);
      await open(tester, controls: controls);
      await tap(tester, find.text('Size'));
      await tap(tester, find.widgetWithText(FilterChip, '4Y'));
      await tester.ensureVisible(
        find.byKey(const Key('catalog-minimum-price')),
      );
      await tester.enterText(
        find.byKey(const Key('catalog-minimum-price')),
        '15',
      );
      controls.value = {
        'filters_width_fraction': .85,
        'filters_side_padding': 24,
        'filters_chip_radius': 0,
        'filters_button_height': 60,
      };
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(CatalogProductFilterSheet)).width,
        closeTo(272, .1),
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('catalog-minimum-price')),
            )
            .controller!
            .text,
        '15',
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '4Y'))
            .selected,
        true,
      );
      controls.value = {};
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(CatalogProductFilterSheet)).width,
        closeTo(240, .1),
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('catalog-minimum-price')),
            )
            .controller!
            .text,
        '15',
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final language in ['en', 'ar']) {
    testWidgets(
      'narrow $language filters show full price labels at large text',
      (tester) async {
        await open(tester, language: language, scale: 1.8);
        await tester.ensureVisible(
          find.byKey(const Key('catalog-maximum-price')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final minimum = tester.widget<TextFormField>(
          find.byKey(const Key('catalog-minimum-price')),
        );
        expect(minimum.controller, isNotNull);
      },
    );
  }
  testWidgets(
    'applies server tag ids, size and color with exact price minors',
    (tester) async {
      CatalogProductFilters? result;
      await open(tester, result: (v) => result = v);
      await tap(tester, find.text('Size'));
      await tap(tester, find.text('4Y'));
      await tap(tester, find.text('Color'));
      await tap(tester, find.text('Blue'));
      await tap(tester, find.text('Product types'));
      await tap(tester, find.text('Trousers'));
      await tester.ensureVisible(
        find.byKey(const Key('catalog-minimum-price')),
      );
      await tester.enterText(
        find.byKey(const Key('catalog-minimum-price')),
        '12.34',
      );
      await tap(tester, find.text('Apply'));
      expect(result?.tags, const [tag]);
      expect(result?.sizes, const [size]);
      expect(result?.colors, const [color]);
      expect(result?.minimumPriceMinor, '1234');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed optional metadata retries without losing edits', (
    tester,
  ) async {
    var calls = 0;
    await open(
      tester,
      load: () async {
        calls++;
        if (calls == 1) throw StateError('offline');
        return options;
      },
    );
    expect(find.text('Try again'), findsOneWidget);
    await tap(tester, find.text('Try again'));
    expect(calls, 2);
    expect(find.text('Product types'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });
  testWidgets(
    'disabled size control stays hidden even when source supplies terms',
    (tester) async {
      await open(tester, showSizes: false);
      expect(find.text('Size'), findsNothing);
      expect(find.text('Color'), findsOneWidget);
    },
  );
  testWidgets('reset clears all controls including tag and attributes', (
    tester,
  ) async {
    CatalogProductFilters? result;
    await open(
      tester,
      initial: const CatalogProductFilters(
        onSaleOnly: true,
        tags: [tag],
        sizes: [size],
        colors: [color],
      ),
      result: (v) => result = v,
    );
    await tap(tester, find.text('Reset'));
    expect(result?.isEmpty, true);
  });
  testWidgets('closing leaves the original filters unchanged', (tester) async {
    CatalogProductFilters? result = const CatalogProductFilters(
      onSaleOnly: true,
    );
    await open(tester, result: (v) => result = v);
    await tap(tester, find.text('Product types'));
    await tap(tester, find.text('Trousers'));
    await tap(tester, find.byIcon(Icons.close));
    expect(result, isNull);
  });
}
