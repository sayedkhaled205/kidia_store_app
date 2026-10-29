import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/cms_preview_navigation.dart';

void main() {
  for (final sheet in [false, true]) {
    testWidgets(
      'editor navigation dismisses ${sheet ? 'sheet' : 'dialog'} before changing page',
      (tester) async {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () {
                      if (sheet) {
                        showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => const Text('Temporary preview'),
                        );
                      } else {
                        showDialog<void>(
                          context: context,
                          builder: (_) => const AlertDialog(
                            content: Text('Temporary preview'),
                          ),
                        );
                      }
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/product',
              builder: (_, _) => const Scaffold(body: Text('Product page')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Temporary preview'), findsOneWidget);
        navigateCmsPreview(router, '/product');
        await tester.pumpAndSettle();
        expect(find.text('Temporary preview'), findsNothing);
        expect(find.text('Product page'), findsOneWidget);
        navigateCmsPreview(router, '/product');
        await tester.pumpAndSettle();
        expect(find.text('Product page'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
