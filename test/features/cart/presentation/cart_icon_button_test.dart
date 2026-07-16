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
  });
}
