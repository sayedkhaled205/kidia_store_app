import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:kidia_store_app/features/cart/presentation/widgets/cart_icon_button.dart';

void main() {
  testWidgets('shows the authoritative cart quantity on the bag icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cartBadgeCountProvider.overrideWithValue(4)],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: <Widget>[CartIconButton(onPressed: () {})]),
          ),
        ),
      ),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
    final Icon icon = tester.widget<Icon>(
      find.byIcon(Icons.shopping_bag_outlined),
    );
    expect(icon.size, 26.4);
    final Padding edgePadding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(CartIconButton),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(
      edgePadding.padding,
      const EdgeInsetsDirectional.only(end: CartIconButton.edgeInset),
    );
  });
}
