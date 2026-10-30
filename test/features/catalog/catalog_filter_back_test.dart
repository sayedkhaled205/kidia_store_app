import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'package:mobishop_store_app/features/catalog/presentation/widgets/catalog_size_sheet.dart';

void main() {
  testWidgets('back closes the filter before navigating the category branch', (
    tester,
  ) async {
    var categoryBacks = 0;
    final router = GoRouter(
      initialLocation: '/categories',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/categories',
                  builder: (context, state) => PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, result) {
                      if (!didPop) categoryBacks++;
                    },
                    child: Center(
                      child: TextButton(
                        onPressed: () => CatalogSizeSheet.show(
                          context,
                          belowToolbar: true,
                          options: const [
                            CatalogSizeOption(
                              taxonomy: 'pa_size',
                              term: '3y',
                              label: '3Y',
                            ),
                          ],
                          selectedFilters: const CatalogProductFilters(),
                        ),
                        child: const Text('Sizes'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sizes'));
    await tester.pumpAndSettle();
    expect(find.text('3Y'), findsOneWidget);
    final chip = tester.widget<FilterChip>(find.byType(FilterChip));
    expect(chip.shape, isA<RoundedRectangleBorder>());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('3Y'), findsNothing);
    expect(categoryBacks, 0);
    expect(find.text('Sizes'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(categoryBacks, 1);
  });
}
