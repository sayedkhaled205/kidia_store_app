import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/app/app.dart';

void main() {
  testWidgets('Woo Mobile CMS app starts successfully', (tester) async {
    await tester.pumpWidget(const KidiaApp());

    expect(find.text('WooCommerce Store'), findsOneWidget);
  });
}