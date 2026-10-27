import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';
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
