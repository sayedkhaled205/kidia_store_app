import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/app/main_shell.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_layout.dart';
import 'package:mobishop_store_app/features/home/presentation/pages/home_page.dart';
import 'package:mobishop_store_app/features/home/presentation/providers/home_providers.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

void main() {
  testWidgets(
    'repeated Home taps scroll to top and switching tabs preserves position',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => MainShell(navigationShell: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(path: '/home', builder: (_, _) => const HomePage()),
                ],
              ),
              for (final path in ['/categories', '/wishlist', '/account'])
                StatefulShellBranch(
                  routes: [
                    GoRoute(path: path, builder: (_, _) => const SizedBox()),
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
            applicationIdentity58Provider.overrideWithValue(null),
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
                  const SpacerBlock(
                    id: 'long-home',
                    enabled: true,
                    height: 2400,
                  ),
                ],
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      final homeState = tester.state(find.byType(HomePage));
      final home = find.byKey(const Key('cms-bottom-nav-home'));
      for (var i = 0; i < 2; i++) {
        scroll.jumpTo(600);
        await tester.pump();
        expect(scroll.offset, 600);
        await tester.tap(home);
        await tester.pumpAndSettle();
        expect(scroll.offset, 0);
        expect(tester.state(find.byType(HomePage)), same(homeState));
      }
      scroll.jumpTo(400);
      await tester.pump();
      await tester.tap(find.byKey(const Key('cms-bottom-nav-categories')));
      await tester.pumpAndSettle();
      await tester.tap(home);
      await tester.pumpAndSettle();
      expect(scroll.offset, 400);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
