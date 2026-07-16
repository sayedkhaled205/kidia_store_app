import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/app/app.dart';
import 'package:kidia_store_app/app/app_router.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:kidia_store_app/features/auth/presentation/auth_screen.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('checkout shows the same auth screen for a signed-out customer', (
    WidgetTester tester,
  ) async {
    final GoRouter router = createAppRouter(initialLocation: '/checkout');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedOutRepository()),
        ],
        child: KidiaApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.byKey(const Key('auth-continue')), findsOneWidget);
  });
}

class _SignedOutRepository implements AuthRepository {
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
