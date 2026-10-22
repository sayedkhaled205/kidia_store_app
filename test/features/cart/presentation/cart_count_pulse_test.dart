import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/cart/presentation/widgets/cart_count_pulse.dart';

void main() {
  testWidgets('pulses once on quantity increase, never initial load or decrease', (tester) async {
    Future<void> show(int count) => tester.pumpWidget(MaterialApp(home: CartCountPulse(count: count, child: Text('$count'))));
    double scale() => tester.widget<ScaleTransition>(find.byKey(const Key('cart-count-pulse'))).scale.value;
    await show(0);
    expect(scale(), 1);
    await show(1);
    await tester.pump(const Duration(milliseconds: 180));
    expect(scale(), greaterThan(1.2));
    await tester.pumpAndSettle();
    expect(scale(), 1);
    await show(1);
    await tester.pump(const Duration(milliseconds: 180));
    expect(scale(), 1);
    await show(0);
    await tester.pump(const Duration(milliseconds: 180));
    expect(scale(), 1);
  });
}
