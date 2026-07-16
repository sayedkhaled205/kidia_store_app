import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:kidia_store_app/features/auth/domain/entities/social_auth.dart';
import 'package:kidia_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kidia_store_app/features/auth/presentation/social_auth_callback_screen.dart';

void main() {
  testWidgets('exchanges the browser handoff and returns to its saved screen', (
    WidgetTester tester,
  ) async {
    final _SocialRepository repository = _SocialRepository();
    final GoRouter router = GoRouter(
      initialLocation: '/social-callback?code=${_secret('c')}&state=${_secret('s')}',
      routes: <RouteBase>[
        GoRoute(
          path: '/social-callback',
          builder: (BuildContext context, GoRouterState state) {
            return SocialAuthCallbackScreen(
              code: state.uri.queryParameters['code'] ?? '',
              state: state.uri.queryParameters['state'] ?? '',
            );
          },
        ),
        GoRoute(
          path: '/account',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('account-destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
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

    expect(find.text('account-destination'), findsOneWidget);
    expect(repository.completedCode, _secret('c'));
    expect(repository.completedState, _secret('s'));
  });
}

String _secret(String character) =>
    List<String>.filled(64, character).join();

class _SocialRepository implements AuthRepository {
  String? completedCode;
  String? completedState;

  @override
  Future<SocialAuthCompletion> completeSocialSignIn({
    required String code,
    required String state,
  }) async {
    completedCode = code;
    completedState = state;
    return SocialAuthCompletion(session: _session(), returnPath: '/account');
  }

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<Uri> beginSocialSignIn({
    required SocialAuthProvider provider,
    required String returnPath,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthIdentity> identify(String email) {
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
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut(AuthSession session) async {}
}

AuthSession _session() {
  return AuthSession(
    token: 'kma1.7.${List<String>.filled(64, 'a').join()}',
    expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
    user: const AuthUser(id: 7, email: 'customer@example.com'),
  );
}
