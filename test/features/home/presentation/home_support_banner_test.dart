import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_layout.dart';
import 'package:mobishop_store_app/features/home/presentation/pages/home_page.dart';
import 'package:mobishop_store_app/features/home/presentation/providers/home_providers.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

void main() {
  testWidgets('Support image banner opens an in-app route and returns Home', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(
          path: '/support',
          builder: (context, _) => Scaffold(
            appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
            body: const Text('Native customer support'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portableAppDesign58Provider.overrideWithValue(null),
          cartBadgeCountProvider.overrideWithValue(0),
          cmsPageLayoutProvider.overrideWith(
            (ref, page) async => CmsPageLayout.fallback(page),
          ),
          homeLayoutProvider.overrideWith(
            (ref, locale) async => HomeLayout(
              version: 1,
              page: 'home',
              locale: locale,
              updatedAt: DateTime(2026),
              blocks: const [
                ImageBannerBlock(
                  id: 'support',
                  enabled: true,
                  imageUrl: '',
                  aspectRatio: 2.4,
                  borderRadius: 12,
                  semanticLabel: 'Support banner',
                  title: 'Contact Kidia',
                  subtitle: null,
                  buttonLabel: null,
                  imageFit: 'cover',
                  overlayStrength: 0,
                  textColor: '#111111',
                  action: HomeAction(type: 'support', value: 'support'),
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contact Kidia'));
    await tester.pumpAndSettle();
    expect(find.text('Native customer support'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Contact Kidia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
