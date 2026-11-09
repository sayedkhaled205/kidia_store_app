import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';

import 'catalog_filter_sheet_test.dart' as harness;

void main() {
  for (final entry in {
    '15': '1500',
    '١٥': '1500',
    '۱۵': '1500',
    '١٥٫٥': '1550',
    '۱۵,۵۰': '1550',
    ' ٠٫٠٥ ': '5',
  }.entries) {
    testWidgets('Arabic filter accepts localized price ${entry.key}', (
      tester,
    ) async {
      CatalogProductFilters? result;
      await harness.open(tester, language: 'ar', result: (v) => result = v);
      final field = find.byKey(const Key('catalog-minimum-price'));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.key);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await harness.tap(tester, find.text('تطبيق'));
      expect(result?.minimumPriceMinor, entry.value);
      expect(tester.takeException(), isNull);
    });
  }
  for (final invalid in ['-١٥', '١٫٢٫٣', '١٥٫٠٠١', '١٬٥', '١,٥,٠']) {
    testWidgets('Localized price keeps validation for $invalid', (
      tester,
    ) async {
      CatalogProductFilters? result;
      await harness.open(tester, language: 'ar', result: (v) => result = v);
      final field = find.byKey(const Key('catalog-maximum-price'));
      await tester.ensureVisible(field);
      await tester.enterText(field, invalid);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await harness.tap(tester, find.text('تطبيق'));
      expect(result, isNull);
      await tester.enterText(field, '١٥');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await harness.tap(tester, find.text('تطبيق'));
      expect(result?.maximumPriceMinor, '1500');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Localized reversed range remains rejected', (tester) async {
    CatalogProductFilters? result;
    await harness.open(tester, language: 'ar', result: (v) => result = v);
    for (final entry in {
      'catalog-minimum-price': '٢٠',
      'catalog-maximum-price': '١٠',
    }.entries) {
      final field = find.byKey(Key(entry.key));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }
    await harness.tap(tester, find.text('تطبيق'));
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}
