import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_access_provider.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_repository_provider.dart';
import 'package:mobishop_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_wishlist_button.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_wishlist_appearance.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';
import 'package:mobishop_store_app/features/auth/data/cms_preview_auth_actions.dart';
import 'package:mobishop_store_app/features/auth/presentation/auth_screen.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/native_auth_providers.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

const available = NativeAuthConfig(
  methods: {'email_password': true, 'phone_otp': true, 'google': true},
);

class ConfigActions implements NativeAuthActions {
  int calls = 0;
  Future<NativeAuthConfig> Function() load = () async => available;

  @override
  Future<NativeAuthConfig> config() {
    calls++;
    return load();
  }

  @override
  Future<void> cancel() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer fixture(ConfigActions actions) {
  final container = ProviderContainer(
    overrides: [nativeAuthActionsProvider.overrideWithValue(actions)],
  );
  return container;
}

void main() {
  testWidgets('product heart retries a failed prefetch when opening sign-in', (
    tester,
  ) async {
    final actions = ConfigActions()
      ..load = () async => throw StateError('offline');
    final repository = _UntouchedWishlist();
    final container = ProviderContainer(
      overrides: [
        nativeAuthActionsProvider.overrideWithValue(actions),
        authControllerProvider.overrideWith(_GuestAuthController.new),
        applicationIdentity58Provider.overrideWithValue({
          'app_name': 'Test store',
        }),
        cmsPageLayoutProvider(
          'account',
        ).overrideWith((_) async => CmsPageLayout.fallback('account')),
        wishlistAccessProvider.overrideWithValue(
          const WishlistAccess(requiresSignIn: true),
        ),
        wishlistRepositoryProvider.overrideWithValue(repository),
      ],
    );
    // A public policy subscriber can retain the failed startup prefetch.
    final retained = container.listen(nativeAuthConfigProvider, (_, _) {});
    await tester.pump();
    expect(container.read(nativeAuthConfigProvider).hasError, isTrue);
    expect(actions.calls, 1);
    actions.load = () async => available;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: ProductWishlistButton(
              productId: 1,
              appearance: ProductWishlistAppearance(enabled: true),
            ),
          ),
        ),
        GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('product-card-wishlist-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.byKey(const Key('auth-google')), findsOneWidget);
    expect(find.byKey(const Key('auth-config-retry')), findsNothing);
    expect(actions.calls, 2);
    expect(repository.writes, 0);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('product-card-wishlist-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(
      actions.calls,
      2,
      reason: 'Successful public capabilities stay cached',
    );
    expect(repository.writes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    retained.close();
    router.dispose();
    container.dispose();
  });
  testWidgets('failed entry retries only once during a persistent outage', (
    tester,
  ) async {
    final actions = ConfigActions()
      ..load = () async => throw StateError('offline');
    final container = ProviderContainer(
      overrides: [
        nativeAuthActionsProvider.overrideWithValue(actions),
        authControllerProvider.overrideWith(_GuestAuthController.new),
        applicationIdentity58Provider.overrideWithValue({
          'app_name': 'Test store',
        }),
        cmsPageLayoutProvider(
          'account',
        ).overrideWith((_) async => CmsPageLayout.fallback('account')),
      ],
    );
    final retained = container.listen(nativeAuthConfigProvider, (_, _) {});
    await tester.pump();
    expect(actions.calls, 1);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(actions.calls, 2);
    expect(find.byKey(const Key('auth-config-retry')), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(
      actions.calls,
      2,
      reason: 'No automatic retry loop or invented login methods',
    );
    expect(find.byKey(const Key('auth-email')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    retained.close();
    container.dispose();
  });

  testWidgets(
    'preview reuses public flags briefly then reads changed methods',
    (tester) async {
      var calls = 0;
      var google = true;
      final container = ProviderContainer(
        overrides: [
          nativeAuthActionsProvider.overrideWithValue(
            CmsPreviewAuthActions(() async {
              calls++;
              return {
                'version': 1,
                'enabled': true,
                'methods': {'google': google},
              };
            }, isArabic: false),
          ),
        ],
      );
      container.read(nativeAuthConfigProvider.future);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(
        container.read(nativeAuthConfigProvider).requireValue.allows('google'),
        true,
      );
      expect(calls, 1);
      google = false;
      await tester.pump(const Duration(seconds: 21));
      await container.pump();
      final refreshed = container.read(nativeAuthConfigProvider.future);
      await tester.pump();
      expect((await refreshed).allows('google'), false);
      expect(calls, 2);
      container.dispose();
    },
  );
  testWidgets(
    'prefetched Google and identifier render on the first login frame',
    (tester) async {
      final actions = ConfigActions();
      final container = ProviderContainer(
        overrides: [
          nativeAuthActionsProvider.overrideWithValue(actions),
          authControllerProvider.overrideWith(_GuestAuthController.new),
          applicationIdentity58Provider.overrideWithValue({
            'app_name': 'Test store',
          }),
          cmsPageLayoutProvider(
            'account',
          ).overrideWith((_) async => CmsPageLayout.fallback('account')),
        ],
      );
      final prefetch = container.read(nativeAuthConfigProvider.future);
      await tester.pump();
      await prefetch;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AuthScreen()),
        ),
      );
      expect(find.byKey(const Key('auth-config-loading')), findsNothing);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
      expect(find.byKey(const Key('auth-email')), findsOneWidget);
      expect(actions.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets('cold prefetch and login share one slow request', (tester) async {
    final pending = Completer<NativeAuthConfig>();
    final actions = ConfigActions()..load = () => pending.future;
    final container = fixture(actions);
    final prefetch = container.read(nativeAuthConfigProvider.future);
    await tester.pump(const Duration(seconds: 3));
    final login = container.read(nativeAuthConfigProvider.future);
    expect(actions.calls, 1);
    expect(container.read(nativeAuthConfigProvider).isLoading, isTrue);
    pending.complete(available);
    await tester.pump();
    expect(await prefetch, same(await login));
    expect(
      container.read(nativeAuthConfigProvider).requireValue.allows('google'),
      isTrue,
    );
    container.dispose();
  });

  testWidgets('opening and closing login retains successful public settings', (
    tester,
  ) async {
    final actions = ConfigActions();
    final container = fixture(actions);
    final prefetch = container.read(nativeAuthConfigProvider.future);
    await tester.pump();
    await prefetch;
    final screen = container.listen(nativeAuthConfigProvider, (_, _) {});
    expect(container.read(nativeAuthConfigProvider).isLoading, isFalse);
    screen.close();
    await tester.pump(const Duration(seconds: 20));
    expect(container.read(nativeAuthConfigProvider).requireValue, available);
    expect(actions.calls, 1);
    container.dispose();
  });

  testWidgets('unused capabilities expire and read the merchant again', (
    tester,
  ) async {
    final actions = ConfigActions();
    final container = fixture(actions);
    container.read(nativeAuthConfigProvider.future);
    await tester.pump();
    actions.load = () async =>
        const NativeAuthConfig(methods: {'email_password': true});
    await tester.pump(const Duration(minutes: 6));
    await container.pump();
    final refreshed = container.read(nativeAuthConfigProvider.future);
    await tester.pump();
    expect((await refreshed).allows('google'), isFalse);
    expect(actions.calls, 2);
    container.dispose();
  });

  testWidgets(
    'configuration failures do not leave login in automatic retry backoff',
    (tester) async {
      final actions = ConfigActions()
        ..load = () async => throw StateError('offline');
      final container = fixture(actions);
      final screen = container.listen(nativeAuthConfigProvider, (_, _) {});
      await tester.pump(const Duration(seconds: 30));
      expect(actions.calls, 1);
      expect(container.read(nativeAuthConfigProvider).hasError, isTrue);
      expect(container.read(nativeAuthConfigProvider).isLoading, isFalse);
      actions.load = () async => available;
      container.invalidate(nativeAuthConfigProvider);
      final retry = container.read(nativeAuthConfigProvider.future);
      await tester.pump();
      expect(await retry, available);
      expect(actions.calls, 2);
      screen.close();
      container.dispose();
    },
  );

  testWidgets('separate store containers never share login capabilities', (
    tester,
  ) async {
    final a = fixture(ConfigActions());
    final b = fixture(
      ConfigActions()
        ..load = () async => const NativeAuthConfig(enabled: false),
    );
    a.read(nativeAuthConfigProvider.future);
    b.read(nativeAuthConfigProvider.future);
    await tester.pump();
    expect(
      a.read(nativeAuthConfigProvider).requireValue.allows('phone_otp'),
      isTrue,
    );
    expect(b.read(nativeAuthConfigProvider).requireValue.enabled, isFalse);
    a.dispose();
    b.dispose();
  });
}

class _GuestAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

class _UntouchedWishlist implements WishlistRepository {
  int writes = 0;
  @override
  Future<List<int>> loadProductIds() async => [];
  @override
  Future<void> saveProductIds(List<int> values) async {
    writes++;
  }
}
