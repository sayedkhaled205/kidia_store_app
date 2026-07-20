import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:kidia_store_app/features/product/presentation/widgets/product_quick_add.dart';

void main() {
  testWidgets('quick add is visible by default on a product card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(CmsPageLayout.fallback('product')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-add-product-42')), findsOneWidget);
  });

  testWidgets('product general setting disables quick add everywhere', (
    WidgetTester tester,
  ) async {
    final CmsPageLayout fallback = CmsPageLayout.fallback('product');
    final List<CmsPageComponent> elements = fallback.elements
        .map(
          (CmsPageComponent element) => element.id == 'product_summary'
              ? CmsPageComponent(
                  id: element.id,
                  type: element.type,
                  enabled: element.enabled,
                  settings: <String, dynamic>{
                    ...element.settings,
                    'quick_add_enabled': false,
                  },
                )
              : element,
        )
        .toList(growable: false);
    final CmsPageLayout disabled = CmsPageLayout(
      page: fallback.page,
      header: fallback.header,
      elements: elements,
      footer: fallback.footer,
    );

    await tester.pumpWidget(_app(disabled));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-add-product-42')), findsNothing);
  });
}

Widget _app(CmsPageLayout layout) {
  return ProviderScope(
    overrides: [
      cmsPageLayoutProvider('product').overrideWith((Ref ref) async => layout),
    ],
    child: const MaterialApp(
      home: Scaffold(body: ProductQuickAddButton(productId: 42)),
    ),
  );
}
