import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/app/app.dart';

void main() {
  testWidgets('requires a WordPress URL before starting', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: WooMobileCmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذر تشغيل التطبيق'), findsOneWidget);
    expect(find.textContaining('WORDPRESS_BASE_URL'), findsOneWidget);
  });
}
