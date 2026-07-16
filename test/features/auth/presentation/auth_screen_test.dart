import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:kidia_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:kidia_store_app/features/auth/presentation/auth_screen.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('existing email advances to the password sign-in step', (
    WidgetTester tester,
  ) async {
    final _FakeAuthRepository repository = _FakeAuthRepository(
      registered: true,
    );
    await _pumpAuth(tester, repository);

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'customer@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('auth-continue')));
    await tester.tap(find.byKey(const Key('auth-continue')));
    await tester.pumpAndSettle();

    expect(find.text('أدخل كلمة المرور'), findsOneWidget);
    expect(find.byKey(const Key('auth-password')), findsOneWidget);
    expect(find.byKey(const Key('auth-sign-in')), findsOneWidget);
    expect(find.byKey(const Key('auth-forgot-password')), findsOneWidget);
    expect(repository.identified, <String>['customer@example.com']);
  });

  testWidgets('new email advances to password creation and confirmation', (
    WidgetTester tester,
  ) async {
    await _pumpAuth(tester, _FakeAuthRepository(registered: false));

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'new@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('auth-continue')));
    await tester.tap(find.byKey(const Key('auth-continue')));
    await tester.pumpAndSettle();

    expect(find.text('أنشئ كلمة مرور'), findsOneWidget);
    expect(find.byKey(const Key('auth-create-password')), findsOneWidget);
    expect(find.byKey(const Key('auth-confirm-password')), findsOneWidget);
    expect(find.byKey(const Key('auth-register')), findsOneWidget);
  });
}

Future<void> _pumpAuth(
  WidgetTester tester,
  AuthRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: <Locale>[Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AuthScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.registered});

  final bool registered;
  final List<String> identified = <String>[];

  @override
  Future<AuthIdentity> identify(String email) async {
    identified.add(email);
    return AuthIdentity(email: email, isRegistered: registered);
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async => _session(email);

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async => _session(email);

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> signOut(AuthSession session) async {}
}

AuthSession _session(String email) {
  return AuthSession(
    token: 'kma1.7.${List<String>.filled(64, 'c').join()}',
    expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
    user: AuthUser(id: 7, email: email),
  );
}
