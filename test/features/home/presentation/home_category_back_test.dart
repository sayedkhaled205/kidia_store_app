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
  testWidgets('Home category shortcut returns to its scrolled Home origin', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => shell,
          branches: [
            StatefulShellBranch(
              routes: [GoRoute(path: '/', builder: (_, _) => const HomePage(), routes: [GoRoute(path: 'products', builder: (context, _) => Scaffold(appBar: AppBar(leading: BackButton(onPressed: () => context.pop())), body: const Text('Selected category')))])],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/categories',
                  builder: (_, _) =>
                      const Scaffold(body: Text('Categories root')),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (context, _) => Scaffold(
                        appBar: AppBar(
                          leading: BackButton(onPressed: () => context.pop()),
                        ),
                        body: const Text('Selected category'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
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
              blocks: [
                const SpacerBlock(id: 'space', enabled: true, height: 700),
                const QuickLinksBlock(
                  id: 'category-links',
                  enabled: true,
                  title: null,
                  subtitle: null,
                  layout: 'grid',
                  columns: 3,
                  imageShape: 'circle',
                  itemSize: 76,
                  gap: 12,
                  showLabels: true,
                  labelColor: '#111111',
                  labelSize: 13,
                  items: [
                    QuickLinkItem(
                      id: 'shoes',
                      imageUrl: '',
                      label: 'Shop shoes',
                      subtitle: null,
                      action: HomeAction(type: 'category', value: '17'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Shop shoes'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Shop shoes'));
    await tester.pumpAndSettle();
    final homeState = tester.state(find.byType(HomePage));
    final scroll = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    final offset = scroll.controller!.offset;
    expect(offset, greaterThan(0));

    await tester.tap(find.text('Shop shoes'));
    await tester.pumpAndSettle();
    expect(find.text('Selected category'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Categories root'), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.state(find.byType(HomePage)), same(homeState));
    expect(scroll.controller!.offset, offset);
  });
}
