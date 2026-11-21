import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/app/main_shell.dart';
import 'package:mobishop_store_app/core/analytics/mobile_analytics.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/app_design/app_design_bundle58.dart';
import 'package:mobishop_store_app/core/app_design/live_app_design.dart';
import 'package:mobishop_store_app/core/app_design/live_app_design_provider.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/localization/app_locale_provider.dart';
import 'package:mobishop_store_app/features/home/data/home_read_session.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/native_auth_providers.dart';
import 'package:mobishop_store_app/features/account/application/account_deletion_recovery.dart';
import 'package:mobishop_store_app/core/live_updates/native_live_updates_host.dart';
import 'package:mobishop_store_app/core/live_updates/store_change_transport.dart';
import 'package:mobishop_store_app/core/live_updates/store_live_updates.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_layout.dart';
import 'package:mobishop_store_app/features/home/presentation/providers/home_providers.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

class Revisions implements StoreChangeTransport {
  var calls = 0;
  @override
  Future<StoreRevisionSnapshot> readRevisions({String? sessionToken}) async {
    calls++;
    return StoreRevisionSnapshot.parse(
      {
        'version': 1,
        'type': 'mobishop_store_revisions',
        'store_origin': 'https://example.invalid',
        'revisions': {'catalog': 'one', 'stock': 'one'},
      },
      configuredOrigin: 'https://example.invalid',
      authenticatedRequest: false,
    );
  }
}

class NoAnalytics implements MobileAnalytics {
  @override
  void trackInBackground(
    String event, {
    int objectId = 0,
    String label = '',
    num value = 0,
    String currency = '',
    int orderId = 0,
    Map<String, Object?> properties = const {},
    String authToken = '',
  }) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DesignTransport implements LiveDesignTransport {
  int calls = 0;
  @override
  Future<String?> fetch(String? etag) async {
    calls++;
    return null;
  }
}

class EmptyDesignCache implements LiveDesignCache {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

class TestDesignNotifier extends LiveDesignNotifier {
  TestDesignNotifier(this.engine);
  final LiveAppDesign engine;
  @override
  AppDesignBundle58? build() {
    ref.onDispose(engine.dispose);
    return null;
  }

  @override
  void configure(bool active, bool safe) =>
      engine.configure(active: active, safeToApply: safe);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'permission focus loss keeps loading Home; real background still refreshes',
    (tester) async {
      var homeReads = 0;
      var deletionRecoveryReads = 0;
      var failHome = false;
      var staleHome = false;
      var failChrome = false;
      var chromeReads = 0;
      Completer<HomeLayout>? pendingHome;
      final readSession = HomeReadSession();
      HomeLayout layout(String locale) => HomeLayout(
        version: 1,
        page: 'home',
        locale: locale,
        updatedAt: DateTime(2026),
        blocks: [
          if (staleHome)
            CatalogUnavailableBlock(
              const SpacerBlock(id: 'section', enabled: true, height: 1),
            ),
        ],
      );
      final transport = Revisions();
      final designTransport = DesignTransport();
      final design = LiveAppDesign(
        transport: designTransport,
        cache: EmptyDesignCache(),
        platform: CommercePlatform.wooCommerce,
        origin: Uri.parse('https://example.invalid'),
        interval: const Duration(hours: 1),
      );
      final updates = StoreLiveUpdates(
        transport: transport,
        configuredOrigin: 'https://example.invalid',
        currentSessionToken: () => null,
        interval: const Duration(hours: 1),
        maxBackoff: const Duration(hours: 1),
      );
      addTearDown(updates.dispose);
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => MainShell(navigationShell: shell),
            branches: [
              for (final path in [
                '/home',
                '/categories',
                '/wishlist',
                '/account',
              ])
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: path,
                      builder: (_, _) => Consumer(
                        builder: (_, ref, _) {
                          ref.watch(homeLayoutProvider('en'));
                          return const SizedBox();
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLocaleProvider.overrideWithValue(const Locale('en')),
            homeReadSessionProvider.overrideWithValue(readSession),
            mobileAnalyticsProvider.overrideWithValue(NoAnalytics()),
            nativeAuthConfigProvider.overrideWith(
              (ref) async => throw StateError('Unused in lifecycle fixture'),
            ),
            accountDeletionRecoveryProvider.overrideWith((ref) async {
              deletionRecoveryReads++;
              return {};
            }),
            nativeStoreLiveUpdatesProvider.overrideWithValue(updates),
            liveAppDesignProvider.overrideWith(
              () => TestDesignNotifier(design),
            ),
            cmsPageLayoutProvider.overrideWith((ref, page) async {
              chromeReads++;
              if (failChrome) throw StateError('offline fixture');
              return CmsPageLayout.fallback(page);
            }),
            homeLayoutProvider.overrideWith((ref, locale) async {
              homeReads++;
              return ref.read(homeReadSessionProvider).load(locale, () async {
                if (failHome) throw StateError('offline fixture');
                return pendingHome == null
                    ? layout(locale)
                    : pendingHome.future;
              });
            }),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (_, child) => LiveAppDesignHost(
              router: router,
              child: NativeLiveUpdatesHost(child: child!),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final initialReads = homeReads;
      final initialRevisions = transport.calls;
      final initialRecoveryReads = deletionRecoveryReads;
      expect(initialReads, 1);
      expect(initialRecoveryReads, 1);
      expect(designTransport.calls, 1);
      expect(initialRevisions, AppConfig.hasConfiguredStore ? 1 : 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(homeReads, initialReads);
      expect(transport.calls, initialRevisions);
      expect(designTransport.calls, 1);
      expect(deletionRecoveryReads, initialRecoveryReads + 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(homeReads, initialReads + 1);
      expect(
        transport.calls,
        AppConfig.hasConfiguredStore ? initialRevisions + 1 : 0,
      );
      expect(deletionRecoveryReads, initialRecoveryReads + 2);
      expect(designTransport.calls, 2);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainShell)),
      );
      final home = homeLayoutProvider('en');
      Future<void> regainFocus() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();
      }

      for (final stale in [false, true]) {
        failHome = !stale;
        staleHome = stale;
        container.invalidate(home);
        await tester.pump();
        await tester.pump();
        expect(container.read(home).isLoading, false);
        expect(container.read(home).hasError, !stale);
        expect(readSession.isStale('en'), stale);
        final before = homeReads;
        failHome = false;
        staleHome = false;
        await regainFocus();
        expect(homeReads, before + 1);
        expect(container.read(home).hasError, false);
        expect(readSession.isStale('en'), false);
      }
      pendingHome = Completer<HomeLayout>();
      container.invalidate(home);
      await tester.pump();
      final pendingReads = homeReads;
      await regainFocus();
      expect(homeReads, pendingReads);
      expect(container.read(home).isLoading, true);
      pendingHome.complete(layout('en'));
      await tester.pump();
      expect(container.read(home).isLoading, false);
      failChrome = true;
      container.invalidate(cmsPageLayoutProvider('home'));
      await tester.pump();
      await tester.pump();
      expect(container.read(cmsPageLayoutProvider('home')).hasError, true);
      final beforeChrome = chromeReads;
      failChrome = false;
      expect(container.exists(cmsPageLayoutProvider('product')), false);
      await regainFocus();
      expect(chromeReads, beforeChrome + 1);
      expect(container.exists(homeLayoutProvider('ar')), false);
      expect(container.exists(cmsPageLayoutProvider('product')), false);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
