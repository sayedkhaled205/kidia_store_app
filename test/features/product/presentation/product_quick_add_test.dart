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
	final Finder shell = find.byKey(const Key('quick-add-shell-42'));
	expect(tester.getSize(shell), const Size.square(40));
	expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('owning product element can disable quick add', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(enabled: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-add-product-42')), findsNothing);
  });

  testWidgets('quick add background accepts a compact size below twenty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(backgroundSize: 12));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('quick-add-shell-42'))),
      const Size.square(12),
    );
  });
}

Widget _app({bool enabled = true, double backgroundSize = 40}) {
  return MaterialApp(
    home: Scaffold(
      body: ProductQuickAddButton(
        productId: 42,
        enabled: enabled,
        backgroundSize: backgroundSize,
      ),
    ),
  );
}
