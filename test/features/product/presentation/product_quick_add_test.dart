import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/product/presentation/widgets/product_quick_add.dart';

void main() {
  testWidgets('quick add is visible by default on a product card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-add-product-42')), findsOneWidget);
  });

  testWidgets('owning product element can disable quick add', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(enabled: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-add-product-42')), findsNothing);
  });
}

Widget _app({bool enabled = true}) {
  return MaterialApp(
    home: Scaffold(
      body: ProductQuickAddButton(productId: 42, enabled: enabled),
    ),
  );
}
