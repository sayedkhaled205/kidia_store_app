import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/app/app.dart';
import 'package:mobishop_store_app/app/main_shell.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final bottom in [0.0, 24.0, 34.0, 48.0]) {
    testWidgets(
      'real navigation footer reserves only the $bottom system inset',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.padding = FakeViewPadding(top: 44, bottom: bottom);
        tester.view.viewPadding = FakeViewPadding(top: 44, bottom: bottom);
        addTearDown(tester.view.reset);
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (_, __, shell) => MainShell(navigationShell: shell),
              branches: [
                for (final path in [
                  '/home',
                  '/categories',
                  '/wishlist',
                  '/account',
                ])
                  StatefulShellBranch(
                    routes: [
                      GoRoute(path: path, builder: (_, __) => const SizedBox()),
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
              applicationIdentity58Provider.overrideWithValue(null),
              cmsPageLayoutProvider.overrideWith((ref, page) async {
                final base = CmsPageLayout.fallback(page);
                return CmsPageLayout(
                  page: page,
                  header: base.header,
                  elements: base.elements,
                  footer: CmsPageComponent(
                    id: 'footer',
                    type: 'app_footer',
                    enabled: true,
                    settings: {
                      ...base.footer.settings,
                      'height': 50,
                      'margin_bottom': 0,
                      'space_down': 0,
                    },
                  ),
                );
              }),
            ],
            child: MobiShopApp(router: router),
          ),
        );
        await tester.pumpAndSettle();
        final footer = find.byKey(const Key('cms-bottom-navigation-size'));
        expect(tester.getRect(footer).bottom, 844 - bottom);
        final account = find.byKey(const Key('cms-bottom-nav-account'));
        await tester.tap(account);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/account');
        expect(tester.getRect(footer).bottom, 844 - bottom);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
