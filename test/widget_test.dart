import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/app/app.dart';

void main() {
  testWidgets('Kidia app starts successfully', (tester) async {
    await tester.pumpWidget(const KidiaApp());

    expect(find.text('Kidia Store'), findsOneWidget);
  });
}