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
            cmsPageLayoutProvider.overrideWith(
              (ref, page) async => CmsPageLayout.fallback(page),
            ),
            homeLayoutProvider.overrideWith((ref, locale) async {
              homeReads++;
              return HomeLayout(
                version: 1,
                page: 'home',
                locale: locale,
                updatedAt: DateTime(2026),
                blocks: [],
              );
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
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
