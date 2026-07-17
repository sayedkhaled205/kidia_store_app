import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/account/presentation/account_screen.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:kidia_store_app/features/auth/domain/entities/social_auth.dart';
import 'package:kidia_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:kidia_store_app/features/auth/presentation/auth_screen.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('every signed-out account action opens the same auth screen', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/account',
      routes: <RouteBase>[
        GoRoute(
          path: '/account',
          builder: (BuildContext context, GoRouterState state) =>
              const AccountScreen(),
        ),
        GoRoute(
          path: '/auth',
          builder: (BuildContext context, GoRouterState state) =>
              const AuthScreen(),
        ),
        GoRoute(
          path: '/cart',
          builder: (BuildContext context, GoRouterState state) =>
              const SizedBox.shrink(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedOutRepository()),
        ],
        child: MaterialApp.router(
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final List<Key> entryPoints = <Key>[
      const Key('account-sign-in'),
      const Key('account-action-orders'),
      const Key('account-action-addresses'),
      const Key('account-action-profile'),
      const Key('account-action-support'),
    ];
    for (final Key key in entryPoints) {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('auth-close')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);
    }
  });

  testWidgets('signed-in orders action opens the real orders destination', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/account',
      routes: <RouteBase>[
        GoRoute(
          path: '/account',
          builder: (BuildContext context, GoRouterState state) =>
              const AccountScreen(),
        ),
        GoRoute(
          path: '/orders',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: SizedBox(key: Key('orders-destination'))),
        ),
        GoRoute(
          path: '/cart',
          builder: (BuildContext context, GoRouterState state) =>
              const SizedBox.shrink(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedInRepository()),
        ],
        child: MaterialApp.router(
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account-action-orders')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orders-destination')), findsOneWidget);
    expect(find.textContaining('الخطوة التالية'), findsNothing);
  });
}

class _SignedOutRepository implements AuthRepository {
  @override
  Future<Uri> beginSocialSignIn({
    required SocialAuthProvider provider,
    required String returnPath,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SocialAuthCompletion> completeSocialSignIn({
    required String code,
    required String state,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthIdentity> identify(String email) async {
    return AuthIdentity(email: email, isRegistered: false);
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> signOut(AuthSession session) async {}
}

class _SignedInRepository extends _SignedOutRepository {
  @override
  Future<AuthSession?> restoreSession() async {
    return AuthSession(
      token: 'session-token',
      expiresAt: DateTime.utc(2099),
      user: const AuthUser(
        id: 7,
        email: 'customer@example.com',
        displayName: 'Customer',
      ),
    );
  }
}
