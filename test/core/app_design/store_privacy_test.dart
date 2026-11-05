import 'package:mobishop_store_app/features/account/presentation/store_privacy_body_loader.dart';
import 'package:mobishop_store_app/features/account/data/privacy_page_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/store_privacy_provider.dart';
import 'package:mobishop_store_app/features/account/presentation/store_privacy_link.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';

void main() {
  test('policy is a safe HTTPS merchant URL, not a guessed route', () {
    for (final bad in [
      '',
      'javascript:alert(1)',
      'http://store.test/policy',
      'https://user:secret@store.test/privacy',
      '//store.test/privacy',
    ]) {
      expect(safeStorePrivacyUri(bad), isNull);
    }
    expect(safeStorePrivacyUri('https://store.test/privacy')?.path, '/privacy');
    expect(
      NativeAuthConfig.fromJson({
        'privacy_policy_url': 'https://store.test/privacy',
      }).privacyPolicyUrl,
      'https://store.test/privacy',
    );
  });
  testWidgets(
    'privacy is actionable and reader retries then returns to prior route',
    (tester) async {
      final policy = Uri.parse('https://store.test/privacy');
      final opened = <Uri>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storePrivacyProvider.overrideWithValue(policy),
            storePrivacyBodyLoaderProvider.overrideWithValue((uri) async {
              opened.add(uri);
              if (opened.length == 1) throw const FormatException('offline');
              return parsePrivacyPage(
                '<nav>Site menu</nav><article><h2>Our policy</h2><p>Merchant contact</p></article>',
              );
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: StorePrivacyLink())),
        ),
      );
      await tester.tap(find.byKey(const Key('store-privacy-policy')));
      await tester.pumpAndSettle();
      expect(opened, [policy]);
      expect(
        find.text('Unable to load the privacy policy. Please retry.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('store-privacy-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Merchant contact', findRichText: true), findsOneWidget);
      expect(find.text('Site menu', findRichText: true), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store-privacy-policy')), findsOneWidget);
    },
  );
}
