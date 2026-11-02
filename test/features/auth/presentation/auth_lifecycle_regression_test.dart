// Synthetic fixtures only. No server access, credentials or customer records.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/app/app.dart';
import 'package:mobishop_store_app/app/app_router.dart';
import 'package:mobishop_store_app/features/account/presentation/account_screen.dart';
import 'package:mobishop_store_app/features/account/presentation/providers/customer_account_providers.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/data/network/auth_api_transport.dart';
import 'package:mobishop_store_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/data/storage/social_auth_pending_store.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobishop_store_app/features/auth/presentation/auth_screen.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/native_auth_providers.dart';
import 'package:mobishop_store_app/features/orders/presentation/providers/customer_orders_providers.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

const fixtureUser = AuthUser(
  id: 73,
  email: 'audit@example.invalid',
  displayName: 'Audit fixture',
);
AuthSession fixtureSession({required bool expired}) => AuthSession(
  token: 'synthetic-test-session',
  expiresAt: DateTime.now().toUtc().add(Duration(hours: expired ? -1 : 1)),
  user: fixtureUser,
);

void main() {
  // A retained controller can cross expiresAt while the app remains open.
  // Override the state to model that point, NOT an initial repository restore:
  // production restoreSession correctly discards an already expired session.
  for (final route in [
    '/checkout',
    '/orders',
    '/orders/1',
    '/addresses',
    '/profile',
    '/support',
  ]) {
    testWidgets('retained expired session must open auth on $route', (
      tester,
    ) async {
      final session = fixtureSession(expired: true);
      final router = createAppRouter(initialLocation: route);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _RetainedSession(session),
            ),
            customerOrdersStoreUriProvider.overrideWithValue(
              Uri.parse('https://audit.example.invalid'),
            ),
            customerAccountStoreUriProvider.overrideWithValue(
              Uri.parse('https://audit.example.invalid'),
            ),
            nativeAuthActionsProvider.overrideWithValue(_IdleNativeActions()),
            nativeAuthConfigProvider.overrideWith(
              (_) async =>
                  const NativeAuthConfig(methods: {'email_password': true}),
            ),
          ],
          child: MobiShopApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(session.isExpired, isTrue);
      expect(
        find.byType(AuthScreen),
        findsOneWidget,
        reason:
            'Expired session must permit signing in again at this protected entry point.',
      );
    });
  }

  testWidgets(
    'offline account logout clears locally without uncaught UI exception',
    (tester) async {
      final store = MemoryAuthSessionStore()
        ..value = fixtureSession(expired: false);
      final repository = AuthRepositoryImpl(
        transport: _OfflineLogoutTransport(),
        sessionStore: store,
        socialPendingStore: MemorySocialAuthPendingStore(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
            cmsPageLayoutProvider('account').overrideWith(
              (_) async => CmsPageLayout.fromJson({
                'page': 'account',
                'header': {'enabled': false},
                'footer': {'enabled': false},
                'elements': [
                  {'id': 'account_summary', 'enabled': true},
                  {'id': 'account_menu', 'enabled': false},
                  {'id': 'logout_button', 'enabled': true},
                ],
              }),
            ),
          ],
          child: const MaterialApp(home: AccountScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AccountScreen));
      final container = ProviderScope.containerOf(context);
      final button = find.byKey(const Key('account-sign-out'));
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        store.value,
        isNull,
        reason: 'Offline logout must clear the local secure session.',
      );
      expect(container.read(authControllerProvider).value, isNull);
      expect(
        tester.takeException(),
        isNull,
        reason:
            'Account sign-out callback must handle transport failure after local logout.',
      );
    },
  );

  test(
    'late duplicate logout must not clear a newly committed native session',
    () async {
      final original = fixtureSession(expired: false);
      final store = MemoryAuthSessionStore()..value = original;
      final transport = _DelayedLogoutTransport();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            AuthRepositoryImpl(
              transport: transport,
              sessionStore: store,
              socialPendingStore: MemorySocialAuthPendingStore(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final controller = container.read(authControllerProvider.notifier);
      // AccountScreen does not disable the sign-out button during the request.
      final first = controller.signOut();
      final second = controller.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(transport.requests, hasLength(1));
      transport.requests.first.complete();
      await first;
      expect(container.read(authControllerProvider).value, isNull);
      // Model the documented native commit order: secure write, then publish.
      final replacement = AuthSession(
        token: 'new-synthetic-session',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        user: const AuthUser(id: 74, email: 'replacement@example.invalid'),
      );
      await store.write(replacement);
      controller.acceptNativeSession(replacement);
      expect(container.read(authControllerProvider).value, same(replacement));
      if (!transport.requests.last.isCompleted) {
        transport.requests.last.complete();
      }
      await second;
      expect(
        store.value,
        same(replacement),
        reason: 'Old logout must not delete the new committed session.',
      );
      expect(container.read(authControllerProvider).value, same(replacement));
    },
  );
}

class _RetainedSession extends AuthController {
  _RetainedSession(this.session);
  final AuthSession session;
  @override
  Future<AuthSession?> build() async => session;
}

class _IdleNativeActions implements NativeAuthActions {
  @override
  Future<void> cancel() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfflineLogoutTransport implements AuthApiTransport {
  @override
  Future<AuthUser> currentUser(String token) async => fixtureUser;
  @override
  Future<void> signOut(String token) async => throw const AuthApiException(
    kind: AuthFailureKind.connection,
    message: 'Synthetic offline sign-out failure',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedLogoutTransport implements AuthApiTransport {
  final requests = <Completer<void>>[];
  @override
  Future<AuthUser> currentUser(String token) async => fixtureUser;
  @override
  Future<void> signOut(String token) {
    final request = Completer<void>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
